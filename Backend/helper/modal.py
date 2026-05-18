from datetime import datetime
from pydantic import BaseModel, Field, ValidationError
from typing import List, Optional

class QualityDetail(BaseModel):
    quality: str = Field(..., description="Quality of the video (e.g., 1080p, 720p)")
    id: str = Field(..., description="Unique hash for the video")
    name: str = Field(..., description="Original Filename of telegram file")
    size: str = Field(..., description="Size of the File")

class Episode(BaseModel):
    episode_number: int = Field(..., description="Episode number within the season")
    title: str = Field(..., description="Title of the episode")
    episode_backdrop: str = Field(..., description="Backdrop of Episode")
    telegram: Optional[List[QualityDetail]] = Field(None, description="List of available quality details")

class Season(BaseModel):
    season_number: int = Field(..., description="Season number within the TV show")
    episodes: List[Episode] = Field(..., description="List of episodes in the season")

class TVShowSchema(BaseModel):
    tmdb_id: int = Field(..., description="The TMDB ID of the TV show")
    title: str = Field(..., description="Title of the TV show")
    genres: List[str] = Field(..., description="List of genres associated with the TV show")
    description: str = Field(..., description="Brief description of the TV show")
    rating: float = Field(..., description="Average rating of the TV show")
    release_year: int = Field(..., description="Release year of the TV show")
    poster: str = Field(..., description="URL to the poster image")
    backdrop: str = Field(..., description="URL to the backdrop image")
    total_seasons: int = Field(..., description="Total Season of tv show")
    total_episodes: int = Field(..., description="Total Episode of tv show")
    media_type: str = Field(..., description="Media Type of the file")
    status: str = Field(..., description="Status update of tv show")
    updated_on: datetime = Field(default_factory=datetime.utcnow, description="Timestamp of the last update")
    languages: List[str] = Field(..., description="List of languages associated with the Movie")
    rip: str = Field(..., description="Media rip of the file")
    seasons: List[Season] = Field(..., description="List of seasons in the TV show")



class MovieSchema(BaseModel):
    tmdb_id: int = Field(..., description="The TMDB ID of the Movie")
    title: str = Field(..., description="Title of the Movie")
    genres: List[str] = Field(..., description="List of genres associated with the Movie")
    description: str = Field(..., description="Brief description of the Movie")
    rating: float = Field(..., description="Average rating of the Movie")
    release_year: int = Field(..., description="Release year of the Movie")
    poster: str = Field(..., description="URL to the poster image")
    backdrop: str = Field(..., description="URL to the backdrop image")
    media_type: str = Field(..., description="Media Type of the file")
    runtime: int = Field(..., description="runtime of the movie")
    updated_on: datetime = Field(default_factory=datetime.utcnow, description="Timestamp of the last update")
    languages: List[str] = Field(..., description="List of languages associated with the Movie")
    rip: str = Field(..., description="Media rip of the file")
    telegram: Optional[List[QualityDetail]] = Field(None, description="List of available quality details")

class ChannelSchema(BaseModel):
    name: str = Field(..., description="Name of the live TV channel")
    logo: str = Field(..., description="URL to the channel logo")
    category: str = Field(..., description="Category (Sports, Entertainment, News, Music, Kids, etc.)")
    language: str = Field(..., description="Language of the broadcast")
    stream_url: str = Field(..., description="HLS m3u8 stream URL")
    epg_id: Optional[str] = Field(None, description="EPG ID for schedules")
    description: Optional[str] = Field(None, description="Description of the channel")
    quality: str = Field("HD", description="Quality profile (HD, SD, 4K)")
    country: str = Field("India", description="Country of origin")
    is_active: bool = Field(True, description="Status of the stream")
    updated_on: datetime = Field(default_factory=datetime.utcnow, description="Timestamp of the last update")

class EditorialPostSchema(BaseModel):
    title: str = Field(..., description="Title of the editorial article")
    content: str = Field(..., description="HTML or rich text content of the article")
    banner: str = Field(..., description="URL to the banner image")
    category: str = Field(..., description="Category (Cricket News, Match Updates, OTT Releases, Movie Reviews, Trending Topics)")
    tags: List[str] = Field(default=[], description="List of tags")
    author: str = Field("Admin", description="Author of the post")
    is_published: bool = Field(True, description="Publish status")
    published_on: datetime = Field(default_factory=datetime.utcnow, description="Publish timestamp")

class SportsFixtureSchema(BaseModel):
    title: str = Field(..., description="Title of the match/event (e.g. India vs Pakistan)")
    team_a: str = Field(..., description="Team A Name")
    team_b: str = Field(..., description="Team B Name")
    team_a_logo: str = Field(..., description="URL to Team A logo")
    team_b_logo: str = Field(..., description="URL to Team B logo")
    sport_type: str = Field("Cricket", description="Sport type (Cricket, Football, WWE, Kabaddi, Tennis)")
    status: str = Field("Scheduled", description="Status (Live, Scheduled, Finished)")
    score: Optional[str] = Field(None, description="Current score/status widget content")
    start_time: datetime = Field(..., description="Date and time when match starts")
    stream_url: Optional[str] = Field(None, description="M3U8 Stream URL if live")
    highlights_url: Optional[str] = Field(None, description="YouTube or video URL of highlights")
    updated_on: datetime = Field(default_factory=datetime.utcnow, description="Timestamp of the last update")