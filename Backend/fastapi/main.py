from time import time
from typing import Any, Dict, List, Optional, Union
from Backend.helper.encrypt import decode_string
from fastapi import FastAPI, Query, Request, HTTPException
from fastapi.responses import StreamingResponse, HTMLResponse
import urllib.parse

from fastapi.templating import Jinja2Templates

import mimetypes
import secrets
import math

from Backend.logger import LOGGER
from Backend.config import Telegram
from Backend.pyrofork import StreamBot, work_loads, multi_clients
from Backend.helper.exceptions import InvalidHash
from Backend.helper.custom_dl import ByteStreamer
from fastapi.middleware.cors import CORSMiddleware
from Backend.helper.pyro import get_readable_time
from Backend import StartTime, __version__, db
from Backend.helper.modal import ChannelSchema, EditorialPostSchema, SportsFixtureSchema, MovieSchema, TVShowSchema
from pyrogram.enums import ChatMemberStatus


app = FastAPI()
class_cache = {}

templates = Jinja2Templates(directory="Backend/fastapi/templates")


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)




@app.get("/", response_model=Dict[str, Any])
async def get_bot_workloads():
    """
    Home route to list each bot's workload and total number of bots.
    """
    response = {
            "server_status": "running",
            "uptime": get_readable_time(time() - StartTime),
            "telegram_bot": "@" + StreamBot.username,
            "connected_bots": len(multi_clients),
            "loads": dict(
                ("bot" + str(c + 1), l)
                for c, (_, l) in enumerate(
                    sorted(work_loads.items(), key=lambda x: x[1], reverse=True)
                )
            ),
            "version": __version__,
        }
    return response



@app.get("/is_member")
async def is_member(user_id: int, channel: int):
    try:
        member = await StreamBot.get_chat_member(channel, user_id)
        if member.status in (ChatMemberStatus.MEMBER, ChatMemberStatus.ADMINISTRATOR, ChatMemberStatus.OWNER):
            return {"is_member": True}
        else:
            return {"is_member": False}
    except Exception as e:
        return {"is_member": False}


@app.get("/watch/{tmdb_id}", response_class=HTMLResponse)
async def watch(
    request: Request, 
    tmdb_id: int, 
    season_number: Optional[int] = Query(None), 
    episode_number: Optional[int] = Query(None)
):
    """
    Serve the appropriate HTML template for watching a movie or a specific TV episode.

    :param request: The incoming HTTP request.
    :param tmdb_id: The TMDB ID of the movie or TV show.
    :param season_number: The season number (optional, only for TV shows).
    :param episode_number: The episode number (optional, only for TV shows).
    :return: The rendered HTML template.
    """

    return templates.TemplateResponse(
        "index.html", 
        {
            "request": request, 
            "id": tmdb_id, 
            "season": season_number, 
            "episode": episode_number
        }
    )



@app.get("/api/tvshows", response_model=dict)
async def get_sorted_tv_shows(
    sort_by: List[str] = Query(default=["rating:desc"], description="List of fields to sort by. Format: field:direction"),
    page: int = Query(default=1, ge=1, description="Page number to return"),
    page_size: int = Query(default=10, ge=1, description="Number of TV shows per page")
):
    try:
        sort_params = [tuple(param.split(":")) for param in sort_by]
        sorted_tv_shows = await db.sort_tv_shows(sort_params, page, page_size)
        return sorted_tv_shows
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/movies", response_model=dict)
async def get_sorted_movies(
    sort_by: List[str] = Query(default=["rating:desc"], description="List of fields to sort by. Format: field:direction"),
    page: int = Query(default=1, ge=1, description="Page number to return"),
    page_size: int = Query(default=10, ge=1, description="Number of movies per page")
):
    try:
        sort_params = [tuple(param.split(":")) for param in sort_by]
        sorted_movies = await db.sort_movies(sort_params, page, page_size)
        return sorted_movies
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

#Homepage:------
# hero = http://localhost:8000/api/tvshows?sort_by=rating:desc&sort_by=release_year:desc&page=1&page_size=10
# latest movies = http://localhost:8000/api/movies?sort_by=updated_on:desc&page=1&page_size=20
# latest tvshows = http://localhost:8000/api/tvshows?sort_by=updated_on:desc&page=1&page_size=20

#Movies:----------
# latest movies = http://localhost:8000/api/movies?sort_by=updated_on:desc&page=1&page_size=40

#Tvshow:----------
# latest tvshows = http://localhost:8000/api/tvshows?sort_by=updated_on:desc&page=1&page_size=40



@app.get("/api/id/{tmdb_id}", response_model=dict)
async def get_media_details(
    tmdb_id: int, 
    season_number: Optional[int] = Query(None), 
    episode_number: Optional[int] = Query(None)
) -> Union[dict, None]:
    """
    FastAPI endpoint to get details of a document, specific season, or episode
    by TMDB ID, season number, and episode number.
    """
    details = await db.get_media_details(
        tmdb_id=tmdb_id, 
        season_number=season_number, 
        episode_number=episode_number
    )

    if not details:
        raise HTTPException(status_code=404, detail="Requested details not found")
    
    return details



@app.get("/api/similar/")
async def get_similar_media(
    tmdb_id: int,
    media_type: str = Query(..., regex="^(movie|tvshow)$"),
    page: int = Query(default=1, ge=1, description="Page number to return"),
    page_size: int = Query(default=10, ge=1, description="Number of similar media per page")
):
    """
    FastAPI endpoint to get similar movies or TV shows based on the parent tmdb_id, sorted by the number of genre matches and rating.
    
    :param tmdb_id: The TMDB ID of the parent movie or TV show.
    :param media_type: The media type ('movie' or 'tvshow').
    :param page: The page number to return.
    :param page_size: The number of similar media per page.
    :return: A dictionary containing the total count and a list of similar movies or TV shows.
    """
    similar_media = await db.find_similar_media(tmdb_id=tmdb_id, media_type=media_type, page=page, page_size=page_size)
    return similar_media


# moviepage = http://127.0.0.1:8000/api/similar/?tmdb_id=695962&media_type=movie&limit=10
# similar movie tab = http://127.0.0.1:8000/api/similar/?tmdb_id=695962&media_type=movie&limit=40

# tvshowpage = http://127.0.0.1:8000/api/similar/?tmdb_id=695962&media_type=tvshow&limit=10
# similar tvshow tab = http://127.0.0.1:8000/api/similar/?tmdb_id=695962&media_type=tvshow&limit=40



@app.get("/api/search/", response_model=dict)
async def search_documents_endpoint(
    query: str = Query(..., description="Search query string"),
    page: int = Query(default=1, ge=1, description="Page number to return"),
    page_size: int = Query(default=10, ge=1, description="Number of documents per page")
):
    """
    FastAPI endpoint to search documents by title across TV and Movie collections,
    with pagination and total count.

    :param query: The search query string.
    :param page: The page number to return.
    :param page_size: The number of documents per page.
    :return: A dictionary containing the total count and a list of search results.
    """
    try:
        search_results = await db.search_documents(query=query, page=page, page_size=page_size)
        return search_results
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# search popup = http://127.0.0.1:8000/api/search/?query=the%20boys&page=1&page_size=10
# search tab = http://127.0.0.1:8000/api/search/?query=the%20boys&page=1&page_size=40


@app.get('/dl/{id}/{name}')
    
async def stream_handler(request: Request, id: str, name: str):
    decoded_data = await decode_string(id)
    if not decoded_data['msg_id'] or not decoded_data['hash']:
        raise HTTPException(status_code=400, detail="Missing id or hash")
    chat_id = f"-100{decoded_data['chat_id']}"
    return await media_streamer(request, int(chat_id), int(decoded_data['msg_id']), decoded_data['hash'])



    


async def media_streamer(request: Request, chat_id: int, id: int, secure_hash: str):
    range_header = request.headers.get("Range", 0)
    index = min(work_loads, key=work_loads.get)
    faster_client = multi_clients[index]
    if Telegram.MULTI_CLIENT:
        LOGGER.debug(f"Client {index} is now serving {request.client.host}")
    if faster_client in class_cache:
        tg_connect = class_cache[faster_client]
        LOGGER.debug(f"Using cached ByteStreamer object for client {index}")
    else:
        LOGGER.debug(f"Creating new ByteStreamer object for client {index}")
        tg_connect = ByteStreamer(faster_client)
        class_cache[faster_client] = tg_connect
    LOGGER.debug("before calling get_file_properties")
    file_id = await tg_connect.get_file_properties(chat_id=chat_id, message_id=id)
    LOGGER.debug("after calling get_file_properties")
    if file_id.unique_id[:6] != secure_hash:
        LOGGER.debug(f"Invalid hash for message with ID {id}")
        raise InvalidHash
    file_size = file_id.file_size
    if range_header:
        from_bytes, until_bytes = range_header.replace("bytes=", "").split("-")
        from_bytes = int(from_bytes)
        until_bytes = int(until_bytes) if until_bytes else file_size - 1
    else:
        from_bytes = 0
        until_bytes = file_size - 1
    if (until_bytes > file_size) or (from_bytes < 0) or (until_bytes < from_bytes):
        return StreamingResponse(
            content=(f"416: Range not satisfiable",),
            status_code=416,
            headers={"Content-Range": f"bytes */{file_size}"},
        )
    chunk_size = 1024 * 1024
    until_bytes = min(until_bytes, file_size - 1)

    offset = from_bytes - (from_bytes % chunk_size)
    first_part_cut = from_bytes - offset
    last_part_cut = until_bytes % chunk_size + 1

    req_length = until_bytes - from_bytes + 1
    part_count = math.ceil(until_bytes / chunk_size) - math.floor(offset / chunk_size)
    body = tg_connect.yield_file(
    file_id, index, offset, first_part_cut, last_part_cut, part_count, chunk_size
)
    mime_type = file_id.mime_type
    file_name = file_id.file_name
    disposition = "inline"

    if mime_type:
        if not file_name:
            try:
                file_name = f"{secrets.token_hex(2)}.{mime_type.split('/')[1]}"
            except (IndexError, AttributeError):
                file_name = f"{secrets.token_hex(2)}.unknown"
    else:
        if file_name:
            mime_type = mimetypes.guess_type(file_name)[0]
        else:
            mime_type = "application/octet-stream"
            file_name = f"{secrets.token_hex(2)}.unknown"

    # async def file_chunk_generator():
    #     async for chunk in tg_connect.yield_file(
    #         file_id, index, offset, first_part_cut, last_part_cut, part_count, chunk_size
    #     ):
    #         yield chunk
    LOGGER.info(f"{mime_type}, {file_name}, {disposition}")
    return StreamingResponse(
        
        status_code=206 if range_header else 200,
        content=body,
        headers={
            "Content-Type": f"{mime_type}",
            "Content-Range": f"bytes {from_bytes}-{until_bytes}/{file_size}",
            "Content-Length": str(req_length),
            "Content-Disposition": f'{disposition}; filename="{file_name}"',
            "Accept-Ranges": "bytes",
        },
    )

# === ADMIN DASHBOARD ===

@app.get("/admin", response_class=HTMLResponse)
async def serve_admin_panel(request: Request):
    return templates.TemplateResponse("admin.html", {"request": request})

# === LIVE TV API ===

@app.get("/api/channels")
async def get_channels(category: Optional[str] = Query(None), page: int = Query(1), page_size: int = Query(20)):
    channels = await db.get_channels(category=category)
    skip = (page - 1) * page_size
    paginated_channels = channels[skip:skip+page_size]
    return {"channels": paginated_channels, "total_count": len(channels)}

@app.get("/api/channels/categories")
async def get_channel_categories():
    return ["Entertainment", "News", "Sports", "Music", "Kids"]

@app.post("/api/admin/channels")
async def add_channel(channel: ChannelSchema):
    res = await db.add_channel(channel)
    if not res:
        raise HTTPException(status_code=400, detail="Failed to add/update channel")
    return {"status": "success", "id": str(res)}

@app.delete("/api/admin/channels/{name}")
async def delete_channel(name: str):
    success = await db.delete_channel(name)
    if not success:
        raise HTTPException(status_code=404, detail="Channel not found")
    return {"status": "success"}

# === EDITORIAL NEWS API ===

@app.get("/api/editorial")
async def get_editorial(category: Optional[str] = Query(None), page: int = Query(1), page_size: int = Query(20)):
    posts = await db.get_editorial(category=category)
    skip = (page - 1) * page_size
    paginated_posts = posts[skip:skip+page_size]
    return {"posts": paginated_posts, "total_count": len(posts)}

@app.get("/api/editorial/categories")
async def get_editorial_categories():
    return ["Cricket News", "Match Updates", "OTT Releases", "Movie Reviews", "Trending Topics"]

@app.post("/api/admin/editorial")
async def add_editorial(post: EditorialPostSchema):
    res = await db.add_editorial(post)
    if not res:
        raise HTTPException(status_code=400, detail="Failed to publish editorial post")
    return {"status": "success", "id": str(res)}

@app.delete("/api/admin/editorial/{title}")
async def delete_editorial(title: str):
    success = await db.delete_editorial(title)
    if not success:
        raise HTTPException(status_code=404, detail="Editorial post not found")
    return {"status": "success"}

# === SPORTS FIXTURES API ===

@app.get("/api/sports/fixtures")
async def get_fixtures(sport_type: Optional[str] = Query(None), status: Optional[str] = Query(None)):
    return await db.get_fixtures(sport_type=sport_type, status=status)

@app.post("/api/admin/sports/fixtures")
async def add_fixture(fixture: SportsFixtureSchema):
    res = await db.add_fixture(fixture)
    if not res:
        raise HTTPException(status_code=400, detail="Failed to add fixture")
    return {"status": "success", "id": str(res)}

@app.post("/api/admin/sports/fixtures/score")
async def update_score(title: str = Query(...), score: str = Query(...), status: str = Query(...)):
    success = await db.update_fixture_score(title, score, status)
    if not success:
        raise HTTPException(status_code=400, detail="Failed to update score")
    return {"status": "success"}

@app.delete("/api/admin/sports/fixtures/{title}")
async def delete_fixture(title: str):
    success = await db.delete_fixture(title)
    if not success:
        raise HTTPException(status_code=404, detail="Fixture not found")
    return {"status": "success"}

# === USER PORTAL & WATCH ENGAGEMENT API ===

@app.post("/api/user/watchlist")
async def add_to_watchlist(user_id: str = Query(...), media_id: int = Query(...), media_type: str = Query(...), title: str = Query(...), poster: str = Query(...)):
    success = await db.add_to_watchlist(user_id, media_id, media_type, title, poster)
    return {"status": "success" if success else "failed"}

@app.delete("/api/user/watchlist")
async def remove_from_watchlist(user_id: str = Query(...), media_id: int = Query(...)):
    success = await db.remove_from_watchlist(user_id, media_id)
    return {"status": "success" if success else "failed"}

@app.get("/api/user/watchlist")
async def get_watchlist(user_id: str = Query(...)):
    return await db.get_watchlist(user_id)

@app.post("/api/user/continue")
async def update_continue(user_id: str = Query(...), media_id: int = Query(...), media_type: str = Query(...), title: str = Query(...), poster: str = Query(...), progress: float = Query(...), duration: float = Query(...)):
    success = await db.update_continue_watching(user_id, media_id, media_type, title, poster, progress, duration)
    return {"status": "success" if success else "failed"}

@app.get("/api/user/continue")
async def get_continue(user_id: str = Query(...)):
    return await db.get_continue_watching(user_id)

@app.post("/api/analytics/track")
async def track_action(user_id: str = Query(...), action: str = Query(...), media_id: str = Query(...), media_title: str = Query(...)):
    await db.track_action(user_id, action, media_id, media_title)
    return {"status": "success"}

@app.get("/api/admin/analytics/summary")
async def get_analytics_summary():
    return await db.get_analytics_summary()

# === GLOBAL DISCOVERY SEARCH ENGINE ===

@app.get("/api/search/all")
async def search_all(query: str = Query(..., description="Search everything across hybrid services")):
    media_res = await db.search_documents(query=query, page=1, page_size=20)
    
    words = query.split()
    regex_query = {'$regex': '.*' + '.*'.join(words) + '.*', '$options': 'i'}
    
    channels = await db.channels_collection.find({"$or": [{"name": regex_query}, {"category": regex_query}]}).to_list(length=10)
    editorials = await db.editorial_collection.find({"$or": [{"title": regex_query}, {"content": regex_query}]}).to_list(length=10)
    fixtures = await db.fixtures_collection.find({"$or": [{"title": regex_query}, {"sport_type": regex_query}]}).to_list(length=10)
    
    return {
        "media": media_res.get("results", []),
        "channels": [db._convert_object_id(c) for c in channels],
        "editorials": [db._convert_object_id(e) for e in editorials],
        "sports": [db._convert_object_id(f) for f in fixtures]
    }
