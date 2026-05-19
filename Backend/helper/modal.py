from datetime import datetime
from pydantic import BaseModel, Field, ValidationError
from typing import List, Optional

class QualityDetail(BaseModel):
    quality: Optional[str] = Field("HD", description="Quality of the video (e.g., 1080p, 720p)")
    id: Optional[str] = Field("", description="Unique hash for the video")
    name: Optional[str] = Field("", description="Original Filename of telegram file")
    size: Optional[str] = Field("", description="Size of the File")

class Episode(BaseModel):
    episode_number: int = Field(..., description="Episode number within the season")
    title: Optional[str] = Field("", description="Title of the episode")
    episode_backdrop: Optional[str] = Field("", description="Backdrop of Episode")
    telegram: Optional[List[QualityDetail]] = Field(None, description="List of available quality details")

class Season(BaseModel):
    season_number: int = Field(..., description="Season number within the TV show")
    episodes: List[Episode] = Field(..., description="List of episodes in the season")

class TVShowSchema(BaseModel):
    tmdb_id: int = Field(..., description="The TMDB ID of the TV show")
    title: str = Field(..., description="Title of the TV show")
    genres: Optional[List[str]] = Field(default=[], description="List of genres associated with the TV show")
    description: Optional[str] = Field("", description="Brief description of the TV show")
    rating: Optional[float] = Field(0.0, description="Average rating of the TV show")
    release_year: Optional[int] = Field(0, description="Release year of the TV show")
    poster: Optional[str] = Field("", description="URL to the poster image")
    backdrop: Optional[str] = Field("", description="URL to the backdrop image")
    total_seasons: Optional[int] = Field(1, description="Total Season of tv show")
    total_episodes: Optional[int] = Field(1, description="Total Episode of tv show")
    media_type: Optional[str] = Field("tv", description="Media Type of the file")
    status: Optional[str] = Field("Ended", description="Status update of tv show")
    updated_on: datetime = Field(default_factory=datetime.utcnow, description="Timestamp of the last update")
    languages: Optional[List[str]] = Field(default=["en"], description="List of languages associated with the Movie")
    rip: Optional[str] = Field("HD", description="Media rip of the file")
    seasons: List[Season] = Field(default=[], description="List of seasons in the TV show")



class MovieSchema(BaseModel):
    tmdb_id: int = Field(..., description="The TMDB ID of the Movie")
    title: str = Field(..., description="Title of the Movie")
    genres: Optional[List[str]] = Field(default=[], description="List of genres associated with the Movie")
    description: Optional[str] = Field("", description="Brief description of the Movie")
    rating: Optional[float] = Field(0.0, description="Average rating of the Movie")
    release_year: Optional[int] = Field(0, description="Release year of the Movie")
    poster: Optional[str] = Field("", description="URL to the poster image")
    backdrop: Optional[str] = Field("", description="URL to the backdrop image")
    media_type: Optional[str] = Field("movie", description="Media Type of the file")
    runtime: Optional[int] = Field(0, description="runtime of the movie")
    updated_on: datetime = Field(default_factory=datetime.utcnow, description="Timestamp of the last update")
    languages: Optional[List[str]] = Field(default=["en"], description="List of languages associated with the Movie")
    rip: Optional[str] = Field("HD", description="Media rip of the file")
    telegram: Optional[List[QualityDetail]] = Field(None, description="List of available quality details")

class ChannelSchema(BaseModel):
    name: str = Field(..., description="Name of the live TV channel")
    logo: Optional[str] = Field("", description="URL to the channel logo")
    category: Optional[str] = Field("Entertainment", description="Category (Sports, Entertainment, News, Music, Kids, etc.)")
    language: Optional[str] = Field("Hindi", description="Language of the broadcast")
    stream_url: str = Field(..., description="HLS m3u8 stream URL")
    epg_id: Optional[str] = Field(None, description="EPG ID for schedules")
    description: Optional[str] = Field(None, description="Description of the channel")
    quality: Optional[str] = Field("HD", description="Quality profile (HD, SD, 4K)")
    country: Optional[str] = Field("India", description="Country of origin")
    is_active: Optional[bool] = Field(True, description="Status of the stream")
    updated_on: datetime = Field(default_factory=datetime.utcnow, description="Timestamp of the last update")

class EditorialPostSchema(BaseModel):
    title: str = Field(..., description="Title of the editorial article")
    content: Optional[str] = Field("", description="HTML or rich text content of the article")
    banner: Optional[str] = Field("", description="URL to the banner image")
    category: Optional[str] = Field("General", description="Category (Cricket News, Match Updates, OTT Releases, Movie Reviews, Trending Topics)")
    tags: Optional[List[str]] = Field(default=[], description="List of tags")
    author: Optional[str] = Field("Admin", description="Author of the post")
    is_published: Optional[bool] = Field(True, description="Publish status")
    published_on: datetime = Field(default_factory=datetime.utcnow, description="Publish timestamp")

class SportsFixtureSchema(BaseModel):
    title: str = Field(..., description="Title of the match/event (e.g. India vs Pakistan)")
    team_a: Optional[str] = Field("", description="Team A Name")
    team_b: Optional[str] = Field("", description="Team B Name")
    team_a_logo: Optional[str] = Field("", description="URL to Team A logo")
    team_b_logo: Optional[str] = Field("", description="URL to Team B logo")
    sport_type: Optional[str] = Field("Cricket", description="Sport type (Cricket, Football, WWE, Kabaddi, Tennis)")
    status: Optional[str] = Field("Scheduled", description="Status (Live, Scheduled, Finished)")
    score: Optional[str] = Field(None, description="Current score/status widget content")
    start_time: datetime = Field(default_factory=datetime.utcnow, description="Date and time when match starts")
    stream_url: Optional[str] = Field(None, description="M3U8 Stream URL if live")
    highlights_url: Optional[str] = Field(None, description="YouTube or video URL of highlights")
    updated_on: datetime = Field(default_factory=datetime.utcnow, description="Timestamp of the last update")