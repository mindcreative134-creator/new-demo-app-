from datetime import datetime
from typing import Dict, List, Optional, Tuple, Union
from bson import ObjectId
from fastapi import HTTPException
import motor.motor_asyncio
from pydantic import ValidationError
from pymongo import ASCENDING, DESCENDING

from Backend.logger import LOGGER
from Backend.config import Telegram
from Backend.helper.encrypt import encode_string
from Backend.helper.modal import Episode, MovieSchema, QualityDetail, Season, TVShowSchema, ChannelSchema, EditorialPostSchema, SportsFixtureSchema


class Database:
    def __init__(self, connection_uri: str = Telegram.DATABASE, db_name: str = "projectS"):
        self._conn = None
        self.db = None
        self.tv_collection = None
        self.movie_collection = None
        self.deploy_config = None
        self.connection_uri = connection_uri
        self.db_name = db_name

    async def connect(self):
        """Establish a connection to all configured databases."""
        try:
            self._conns = []
            self.dbs = []
            
            uris = self.connection_uri
            if not isinstance(uris, list):
                uris = [uris]
            
            for uri in uris:
                if not uri:
                    continue
                conn = motor.motor_asyncio.AsyncIOMotorClient(uri)
                self._conns.append(conn)
                self.dbs.append(conn[self.db_name])
            
            if not self.dbs:
                LOGGER.error("No database connections could be initialized.")
                return
            
            self.db = self.dbs[0]
            self.tv_collection = self.db["tv"]
            self.movie_collection = self.db["movie"]
            self.deploy_config = self.db["deploy_config"]  
            self.channels_collection = self.db["channels"]
            self.editorial_collection = self.db["editorial"]
            self.fixtures_collection = self.db["fixtures"]
            self.analytics_collection = self.db["analytics"]
            self.watchlist_collection = self.db["watchlist"]
            self.continue_collection = self.db["continue_watching"]

            LOGGER.info(f"Database connection established for {len(self.dbs)} database(s)")
            
            # Run background synchronization
            import asyncio
            asyncio.create_task(self.sync_databases())
        except Exception as e:
            LOGGER.error(f"Error connecting to the database: {e}")
        
    async def disconnect(self):
        """Close all database connections."""
        if hasattr(self, "_conns"):
            for conn in self._conns:
                await conn.close()
            LOGGER.info("All database connections closed")
        self.db = None
        self.tv_collection = None
        self.movie_collection = None
        self.channels_collection = None
        self.editorial_collection = None
        self.fixtures_collection = None
        self.analytics_collection = None
        self.watchlist_collection = None
        self.continue_collection = None

    async def sync_databases(self):
        """Synchronize collections across all databases."""
        if len(self.dbs) < 2:
            return
        
        try:
            LOGGER.info("Starting database synchronization...")
            collections_to_sync = ["movie", "tv", "channels", "editorial", "fixtures"]
            
            for col_name in collections_to_sync:
                all_docs = {}
                for db in self.dbs:
                    cursor = db[col_name].find({})
                    async for doc in cursor:
                        doc_id = doc.get("tmdb_id") or doc.get("name") or doc.get("title")
                        if doc_id:
                            all_docs[doc_id] = doc
                
                for doc_id, doc in all_docs.items():
                    for db in self.dbs:
                        if col_name == "movie" or col_name == "tv":
                            existing = await db[col_name].find_one({"tmdb_id": doc["tmdb_id"]})
                            if not existing:
                                await db[col_name].insert_one(doc.copy())
                        elif col_name == "channels":
                            existing = await db[col_name].find_one({"name": doc["name"]})
                            if not existing:
                                await db[col_name].insert_one(doc.copy())
                        elif col_name == "editorial" or col_name == "fixtures":
                            existing = await db[col_name].find_one({"title": doc["title"]})
                            if not existing:
                                await db[col_name].insert_one(doc.copy())
                                
            LOGGER.info("Database synchronization completed successfully!")
        except Exception as e:
            LOGGER.error(f"Error during database sync: {e}")

    @staticmethod
    def _convert_object_id(document: dict) -> dict:
        """Convert MongoDB ObjectId to string."""
        if "_id" in document:
            document["_id"] = str(document["_id"])
        return document

    
    async def update_tv_show(self, tv_show_data: TVShowSchema) -> Optional[ObjectId]:
        try:
            tv_show_dict = tv_show_data.dict()
        except ValidationError as e:
            LOGGER.error(f"Validation error: {e}")
            return None

        primary_id = None
        for db in self.dbs:
            tv_collection = db["tv"]
            existing_media = await tv_collection.find_one({
                "$or": [
                    {"tmdb_id": tv_show_dict["tmdb_id"]},
                    {"title": tv_show_dict["title"], "release_year": tv_show_dict["release_year"]}
                ]
            })

            if not existing_media:
                result = await tv_collection.insert_one(tv_show_dict.copy())
                if db == self.db:
                    primary_id = result.inserted_id
            else:
                updated = False
                for season in tv_show_dict["seasons"]:
                    existing_season = next(
                        (s for s in existing_media["seasons"] 
                         if s["season_number"] == season["season_number"]), None)
                    
                    if existing_season:
                        for episode in season["episodes"]:
                            existing_episode = next(
                                (e for e in existing_season["episodes"] 
                                 if e["episode_number"] == episode["episode_number"]), None)
                            
                            if existing_episode:
                                for quality in episode["telegram"]:
                                    existing_quality = next(
                                        (q for q in existing_episode["telegram"] 
                                         if q["quality"] == quality["quality"]), None)
                                    
                                    if existing_quality:
                                        existing_quality.update(quality)
                                        updated = True
                                    else:
                                        existing_episode["telegram"].append(quality)
                                        updated = True
                            else:
                                existing_season["episodes"].append(episode)
                                updated = True
                    else:
                        existing_media["seasons"].append(season)
                        updated = True

                if updated:
                    existing_media["updated_on"] = datetime.utcnow()
                    existing_media["languages"] = tv_show_dict["languages"]
                    existing_media["rip"] = tv_show_dict["rip"]
                    await tv_collection.replace_one(
                        {"tmdb_id": tv_show_dict["tmdb_id"]}, existing_media)
                
                if db == self.db:
                    primary_id = existing_media["_id"]

        return primary_id

    async def update_movie(self, movie_data: MovieSchema) -> Optional[ObjectId]:
        if not self.dbs:
            LOGGER.error("Database collections are not initialized.")
            return None
        try:
            movie_dict = movie_data.dict()
        except ValidationError as e:
            LOGGER.error(f"Validation error: {e}")
            return None

        primary_id = None
        for db in self.dbs:
            movie_collection = db["movie"]
            existing_media = await movie_collection.find_one({
                "$or": [
                    {"tmdb_id": movie_dict["tmdb_id"]},
                    {"title": movie_dict["title"], "release_year": movie_dict["release_year"]}
                ]
            })

            if not existing_media:
                result = await movie_collection.insert_one(movie_dict.copy())
                if db == self.db:
                    primary_id = result.inserted_id
            else:
                updated = False
                for quality in movie_dict["telegram"]:
                    existing_quality = next(
                        (q for q in existing_media["telegram"] 
                         if q["quality"] == quality["quality"]), None)
                    
                    if existing_quality:
                        existing_quality.update(quality)
                        updated = True
                    else:
                        existing_media["telegram"].append(quality)
                        updated = True

                if updated:
                    existing_media["updated_on"] = datetime.utcnow()
                    existing_media["languages"] = movie_dict["languages"]
                    existing_media["rip"] = movie_dict["rip"]
                    await movie_collection.replace_one(
                        {"tmdb_id": movie_dict["tmdb_id"]}, existing_media)
                
                if db == self.db:
                    primary_id = existing_media["_id"]

        return primary_id

    async def insert_media(
        self,
        metadata_info: dict,
        hash: str,
        channel: int,
        msg_id: int,
        size: str,
        name: str
    ) -> Optional[ObjectId]:
        data = {"chat_id": channel, "msg_id": msg_id, "hash": hash}
        encoded_string = await encode_string(data)

        if metadata_info['media_type'] == "movie":
            media = MovieSchema(
                tmdb_id=metadata_info['tmdb_id'],
                title=metadata_info['title'],
                genres=metadata_info['genres'],
                description=metadata_info['description'],
                rating=metadata_info['rate'],
                release_year=metadata_info['year'],
                poster=metadata_info['poster'],
                backdrop=metadata_info['backdrop'],
                runtime=metadata_info['runtime'],
                media_type=metadata_info['media_type'],
                languages=metadata_info['languages'],
                rip=metadata_info['rip'],
                telegram=[
                    QualityDetail(
                        quality=metadata_info['quality'],
                        id=encoded_string,
                        name=name,
                        size=size
                    )]
            )
            return await self.update_movie(media)
        else:
            tv_show = TVShowSchema(
                tmdb_id=metadata_info['tmdb_id'],
                title=metadata_info['title'],
                genres=metadata_info['genres'],
                description=metadata_info['description'],
                rating=metadata_info['rate'],
                release_year=metadata_info['year'],
                poster=metadata_info['poster'],
                backdrop=metadata_info['backdrop'],
                media_type=metadata_info['media_type'],
                status=metadata_info['status'],
                total_seasons=metadata_info['total_seasons'],
                total_episodes=metadata_info['total_episodes'],
                languages=metadata_info['languages'],
                rip=metadata_info['rip'],
                seasons=[
                    Season(
                        season_number=metadata_info['season_number'],
                        episodes=[
                            Episode(
                                episode_number=metadata_info['episode_number'],
                                title=metadata_info['episode_title'],
                                episode_backdrop=metadata_info['episode_backdrop'],
                                telegram=[
                                    QualityDetail(
                                        quality=metadata_info['quality'],
                                        id=encoded_string,
                                        name=name,
                                        size=size
                                    )
                                ]
                            )
                        ]
                    )
                ]
            )
            return await self.update_tv_show(tv_show)

    async def sort_tv_shows(
        self, 
        sort_params: List[Tuple[str, str]], 
        page: int, 
        page_size: int
    ) -> dict:
        skip = (page - 1) * page_size
        sort_criteria = [(field, ASCENDING if direction == "asc" else DESCENDING) 
                        for field, direction in sort_params]
        
        pipeline = [
            {"$sort": dict(sort_criteria)},
            {"$facet": {
                "metadata": [{"$count": "total_count"}],
                "data": [{"$skip": skip}, {"$limit": page_size}]
            }}
        ]
        
        result = await self.tv_collection.aggregate(pipeline).to_list(1)
        total_count = result[0]["metadata"][0]["total_count"] if result[0]["metadata"] else 0
        sorted_shows = [TVShowSchema(**doc) for doc in result[0]["data"]]
        return {"total_count": total_count, "tv_shows": sorted_shows}

    async def sort_movies(
        self, 
        sort_params: List[Tuple[str, str]], 
        page: int, 
        page_size: int
    ) -> dict:
        skip = (page - 1) * page_size
        sort_criteria = [(field, ASCENDING if direction == "asc" else DESCENDING) 
                        for field, direction in sort_params]
        
        pipeline = [
            {"$sort": dict(sort_criteria)},
            {"$facet": {
                "metadata": [{"$count": "total_count"}],
                "data": [{"$skip": skip}, {"$limit": page_size}]
            }}
        ]
        
        result = await self.movie_collection.aggregate(pipeline).to_list(1)
        total_count = result[0]["metadata"][0]["total_count"] if result[0]["metadata"] else 0
        sorted_movies = [MovieSchema(**doc) for doc in result[0]["data"]]
        return {"total_count": total_count, "movies": sorted_movies}

    async def find_similar_media(
        self,
        tmdb_id: int,
        media_type: str,
        page: int = 1,
        page_size: int = 10
    ) -> dict:
        collection = self.movie_collection if media_type == "movie" else self.tv_collection
        parent_media = await collection.find_one({"tmdb_id": tmdb_id})
        
        if not parent_media:
            raise HTTPException(status_code=404, detail="Media not found")
        
        parent_genres = parent_media.get("genres", [])
        if not parent_genres:
            return {"total_count": 0, "similar_media": []}

        skip = (page - 1) * page_size
        pipeline = [
            {"$match": {
                "tmdb_id": {"$ne": tmdb_id},
                "genres": {"$in": parent_genres}
            }},
            {"$addFields": {
                "genreMatchCount": {"$size": {"$setIntersection": ["$genres", parent_genres]}}
            }},
            {"$sort": {"genreMatchCount": -1, "rating": -1}},
            {"$facet": {
                "metadata": [{"$count": "total_count"}],
                "data": [{"$skip": skip}, {"$limit": page_size}]
            }}
        ]
        
        result = await collection.aggregate(pipeline).to_list(1)
        total_count = result[0]["metadata"][0]["total_count"] if result[0]["metadata"] else 0
        similar_media = [self._convert_object_id(doc) for doc in result[0]["data"]]
        return {"total_count": total_count, "similar_media": similar_media}

    async def search_documents(
        self, 
        query: str, 
        page: int, 
        page_size: int
    ) -> dict:
        skip = (page - 1) * page_size
        words = query.split()
        regex_query = {'$regex': '.*' + '.*'.join(words) + '.*', '$options': 'i'}
        
        tv_pipeline = [
            {"$match": {"$or": [
                {"title": regex_query},
                {"seasons.episodes.telegram.name": regex_query}
            ]}},
            {"$project": {
                "_id": 1, "tmdb_id": 1, "title": 1, "genres": 1, "rating": 1,
                "release_year": 1, "poster": 1, "backdrop": 1, "description": 1,
                "total_seasons": 1, "total_episodes": 1, "media_type": 1
            }}
        ]
        
        movie_pipeline = [
            {"$match": {"$or": [
                {"title": regex_query},
                {"telegram.name": regex_query}
            ]}},
            {"$project": {
                "_id": 1, "tmdb_id": 1, "title": 1, "genres": 1, "rating": 1,
                "release_year": 1, "poster": 1, "backdrop": 1, "description": 1,
                "media_type": 1
            }}
        ]
        
        tv_results = await self.tv_collection.aggregate(tv_pipeline).to_list(None)
        movie_results = await self.movie_collection.aggregate(movie_pipeline).to_list(None)
        combined = tv_results + movie_results
        
        return {
            "total_count": len(combined),
            "results": [self._convert_object_id(doc) for doc in combined[skip:skip+page_size]]
        }

    async def get_media_details(
        self,
        tmdb_id: int,
        season_number: Optional[int] = None,
        episode_number: Optional[int] = None
    ) -> Optional[dict]:
        if episode_number is not None and season_number is not None:
            tv_show = await self.tv_collection.find_one({"tmdb_id": tmdb_id})
            if not tv_show:
                return None
            for season in tv_show.get("seasons", []):
                if season.get("season_number") == season_number:
                    for episode in season.get("episodes", []):
                        if episode.get("episode_number") == episode_number:
                            details = self._convert_object_id(episode)
                            details.update({
                                "tmdb_id": tmdb_id,
                                "type": "tv",
                                "season_number": season_number,
                                "episode_number": episode_number,
                                "backdrop": episode.get("episode_backdrop")
                            })
                            return details
            return None

        elif season_number is not None:
            tv_show = await self.tv_collection.find_one({"tmdb_id": tmdb_id})
            if not tv_show:
                return None
            for season in tv_show.get("seasons", []):
                if season.get("season_number") == season_number:
                    details = self._convert_object_id(season)
                    details.update({
                        "tmdb_id": tmdb_id,
                        "type": "tv",
                        "season_number": season_number
                    })
                    return details
            return None

        else:
            tv_doc = await self.tv_collection.find_one({"tmdb_id": tmdb_id})
            if tv_doc:
                tv_doc = self._convert_object_id(tv_doc)
                tv_doc["type"] = "tv"
                return tv_doc
            
            movie_doc = await self.movie_collection.find_one({"tmdb_id": tmdb_id})
            if movie_doc:
                movie_doc = self._convert_object_id(movie_doc)
                movie_doc["type"] = "movie"
                return movie_doc
            
            return None

    async def get_quality_details(
        self,
        tmdb_id: int,
        quality: str,
        season: Optional[int] = None,
        episode: Optional[int] = None
    ) -> List[Dict[str, int]]:
        if season is None:
            # Movie case
            doc = await self.movie_collection.find_one(
                {"tmdb_id": tmdb_id},
                {"telegram": 1}
            )
            if not doc:
                return []
            return [
                {"id": item["id"], "name": item["name"]}
                for item in doc.get("telegram", [])
                if item["quality"] == quality
            ]
        else:
            # TV show case
            doc = await self.tv_collection.find_one(
                {"tmdb_id": tmdb_id},
                {"seasons": 1}
            )
            if not doc:
                return []
            
            results = []
            for s in doc.get("seasons", []):
                if s["season_number"] == season:
                    episodes = s.get("episodes", [])
                    
                    # Filter by specific episode if provided
                    if episode is not None:
                        episodes = [ep for ep in episodes if ep["episode_number"] == episode]
                    
                    for ep in episodes:
                        results.extend([
                            {"id": t["id"], "name": t["name"]}
                            for t in ep.get("telegram", [])
                            if t["quality"] == quality
                        ])
            return results


    async def delete_document(
        self,
        media_type: str,
        tmdb_id: int
    ) -> bool:
        deleted = False
        for db in self.dbs:
            collection = db["movie"] if media_type == "mov" else db["tv"]
            result = await collection.delete_one({"tmdb_id": tmdb_id})
            if result.deleted_count > 0:
                deleted = True
                LOGGER.info(f"{media_type} with tmdb_id {tmdb_id} deleted successfully from a database.")
        
        if deleted:
            return True
        LOGGER.info(f"No document found with tmdb_id {tmdb_id} in any database.")
        return False

    # === LIVE TV CHANNELS OPERATIONS ===

    async def add_channel(self, channel_data: ChannelSchema) -> Optional[ObjectId]:
        try:
            channel_dict = channel_data.dict()
            primary_id = None
            for db in self.dbs:
                channels_collection = db["channels"]
                existing = await channels_collection.find_one({"name": channel_dict["name"]})
                if existing:
                    await channels_collection.replace_one({"name": channel_dict["name"]}, channel_dict)
                    if db == self.db:
                        primary_id = existing["_id"]
                else:
                    result = await channels_collection.insert_one(channel_dict.copy())
                    if db == self.db:
                        primary_id = result.inserted_id
            return primary_id
        except Exception as e:
            LOGGER.error(f"Error in add_channel: {e}")
            return None

    async def get_channels(self, category: Optional[str] = None, page: int = 1, page_size: int = 20) -> dict:
        try:
            query = {}
            if category:
                query["category"] = {"$regex": f"^{category}$", "$options": "i"}
            
            skip = (page - 1) * page_size
            cursor = self.channels_collection.find(query).skip(skip).limit(page_size)
            channels = await cursor.to_list(length=page_size)
            total = await self.channels_collection.count_documents(query)
            
            return {
                "total_count": total,
                "channels": [self._convert_object_id(c) for c in channels]
            }
        except Exception as e:
            LOGGER.error(f"Error in get_channels: {e}")
            return {"total_count": 0, "channels": []}

    async def delete_channel(self, name: str) -> bool:
        try:
            deleted = False
            for db in self.dbs:
                result = await db["channels"].delete_one({"name": name})
                if result.deleted_count > 0:
                    deleted = True
            return deleted
        except Exception as e:
            LOGGER.error(f"Error in delete_channel: {e}")
            return False

    # === EDITORIAL POSTS OPERATIONS ===

    async def add_editorial(self, post_data: EditorialPostSchema) -> Optional[ObjectId]:
        try:
            post_dict = post_data.dict()
            primary_id = None
            for db in self.dbs:
                editorial_collection = db["editorial"]
                existing = await editorial_collection.find_one({"title": post_dict["title"]})
                if existing:
                    await editorial_collection.replace_one({"title": post_dict["title"]}, post_dict)
                    if db == self.db:
                        primary_id = existing["_id"]
                else:
                    result = await editorial_collection.insert_one(post_dict.copy())
                    if db == self.db:
                        primary_id = result.inserted_id
            return primary_id
        except Exception as e:
            LOGGER.error(f"Error in add_editorial: {e}")
            return None

    async def get_editorials(self, category: Optional[str] = None, page: int = 1, page_size: int = 20) -> dict:
        try:
            query = {}
            if category:
                query["category"] = {"$regex": f"^{category}$", "$options": "i"}
            
            skip = (page - 1) * page_size
            cursor = self.editorial_collection.find(query).sort("published_on", -1).skip(skip).limit(page_size)
            posts = await cursor.to_list(length=page_size)
            total = await self.editorial_collection.count_documents(query)
            
            return {
                "total_count": total,
                "posts": [self._convert_object_id(p) for p in posts]
            }
        except Exception as e:
            LOGGER.error(f"Error in get_editorials: {e}")
            return {"total_count": 0, "posts": []}

    async def delete_editorial(self, title: str) -> bool:
        try:
            deleted = False
            for db in self.dbs:
                result = await db["editorial"].delete_one({"title": title})
                if result.deleted_count > 0:
                    deleted = True
            return deleted
        except Exception as e:
            LOGGER.error(f"Error in delete_editorial: {e}")
            return False

    # === SPORTS FIXTURES OPERATIONS ===

    async def add_fixture(self, fixture_data: SportsFixtureSchema) -> Optional[ObjectId]:
        try:
            fixture_dict = fixture_data.dict()
            primary_id = None
            for db in self.dbs:
                fixtures_collection = db["fixtures"]
                existing = await fixtures_collection.find_one({"title": fixture_dict["title"]})
                if existing:
                    await fixtures_collection.replace_one({"title": fixture_dict["title"]}, fixture_dict)
                    if db == self.db:
                        primary_id = existing["_id"]
                else:
                    result = await fixtures_collection.insert_one(fixture_dict.copy())
                    if db == self.db:
                        primary_id = result.inserted_id
            return primary_id
        except Exception as e:
            LOGGER.error(f"Error in add_fixture: {e}")
            return None

    async def get_fixtures(self, sport_type: Optional[str] = None, status: Optional[str] = None) -> List[dict]:
        try:
            query = {}
            if sport_type:
                query["sport_type"] = {"$regex": f"^{sport_type}$", "$options": "i"}
            if status:
                query["status"] = {"$regex": f"^{status}$", "$options": "i"}
            
            cursor = self.fixtures_collection.find(query).sort("start_time", 1)
            fixtures = await cursor.to_list(length=100)
            return [self._convert_object_id(f) for f in fixtures]
        except Exception as e:
            LOGGER.error(f"Error in get_fixtures: {e}")
            return []

    async def update_fixture_score(self, title: str, score: str, status: str) -> bool:
        try:
            updated = False
            for db in self.dbs:
                result = await db["fixtures"].update_one(
                    {"title": title},
                    {"$set": {"score": score, "status": status, "updated_on": datetime.utcnow()}}
                )
                if result.modified_count > 0:
                    updated = True
            return updated
        except Exception as e:
            LOGGER.error(f"Error in update_fixture_score: {e}")
            return False

    async def delete_fixture(self, title: str) -> bool:
        try:
            deleted = False
            for db in self.dbs:
                result = await db["fixtures"].delete_one({"title": title})
                if result.deleted_count > 0:
                    deleted = True
            return deleted
        except Exception as e:
            LOGGER.error(f"Error in delete_fixture: {e}")
            return False

    # === USER ENGAGEMENT & TRACKING ===

    async def track_action(self, user_id: str, action: str, media_id: str, media_title: str):
        try:
            doc = {
                "user_id": user_id,
                "action": action,
                "media_id": media_id,
                "media_title": media_title,
                "timestamp": datetime.utcnow()
            }
            for db in self.dbs:
                await db["analytics"].insert_one(doc.copy())
        except Exception as e:
            LOGGER.error(f"Error in track_action: {e}")

    async def get_analytics_summary(self) -> dict:
        try:
            total_movies = await self.movie_collection.count_documents({})
            total_shows = await self.tv_collection.count_documents({})
            total_channels = await self.channels_collection.count_documents({})
            total_editorial = await self.editorial_collection.count_documents({})
            
            # Active actions count in last 24h
            day_ago = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
            active_users = len(await self.analytics_collection.distinct("user_id", {"timestamp": {"$gte": day_ago}}))
            total_clicks = await self.analytics_collection.count_documents({})
            
            # Aggregate most watched media/channels
            pipeline = [
                {"$group": {"_id": "$media_title", "count": {"$sum": 1}}},
                {"$sort": {"count": -1}},
                {"$limit": 5}
            ]
            most_watched = await self.analytics_collection.aggregate(pipeline).to_list(length=5)
            
            return {
                "total_movies": total_movies,
                "total_shows": total_shows,
                "total_channels": total_channels,
                "total_articles": total_editorial,
                "active_users_24h": active_users,
                "total_events": total_clicks,
                "most_watched": [{"title": doc["_id"], "plays": doc["count"]} for doc in most_watched if doc["_id"]]
            }
        except Exception as e:
            LOGGER.error(f"Error in get_analytics_summary: {e}")
            return {}

    # === WATCHLIST OPERATIONS ===

    async def add_to_watchlist(self, user_id: str, media_id: int, media_type: str, title: str, poster: str) -> bool:
        try:
            doc = {
                "user_id": user_id,
                "media_id": media_id,
                "media_type": media_type,
                "title": title,
                "poster": poster,
                "added_at": datetime.utcnow()
            }
            for db in self.dbs:
                await db["watchlist"].update_one(
                    {"user_id": user_id, "media_id": media_id},
                    {"$set": doc.copy()},
                    upsert=True
                )
            return True
        except Exception as e:
            LOGGER.error(f"Error in add_to_watchlist: {e}")
            return False

    async def remove_from_watchlist(self, user_id: str, media_id: int) -> bool:
        try:
            result = await self.watchlist_collection.delete_one({"user_id": user_id, "media_id": media_id})
            return result.deleted_count > 0
        except Exception as e:
            LOGGER.error(f"Error in remove_from_watchlist: {e}")
            return False

    async def get_watchlist(self, user_id: str) -> List[dict]:
        try:
            cursor = self.watchlist_collection.find({"user_id": user_id}).sort("added_at", -1)
            docs = await cursor.to_list(length=100)
            return [self._convert_object_id(d) for d in docs]
        except Exception as e:
            LOGGER.error(f"Error in get_watchlist: {e}")
            return []

    # === CONTINUE WATCHING OPERATIONS ===

    async def update_continue_watching(self, user_id: str, media_id: int, media_type: str, title: str, poster: str, progress: float, duration: float) -> bool:
        try:
            doc = {
                "user_id": user_id,
                "media_id": media_id,
                "media_type": media_type,
                "title": title,
                "poster": poster,
                "progress": progress,
                "duration": duration,
                "updated_at": datetime.utcnow()
            }
            await self.continue_collection.update_one(
                {"user_id": user_id, "media_id": media_id},
                {"$set": doc},
                upsert=True
            )
            return True
        except Exception as e:
            LOGGER.error(f"Error in update_continue_watching: {e}")
            return False

    async def get_continue_watching(self, user_id: str) -> List[dict]:
        try:
            cursor = self.continue_collection.find({"user_id": user_id}).sort("updated_at", -1)
            docs = await cursor.to_list(length=50)
            return [self._convert_object_id(d) for d in docs]
        except Exception as e:
            LOGGER.error(f"Error in get_continue_watching: {e}")
            return []
