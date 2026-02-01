"""
Configuration management for the Dutch Language Learning Application.

Loads settings from environment variables with sensible defaults.
"""

from pathlib import Path
from typing import Optional

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # OpenAI API Configuration
    openai_api_key: str = ""

    # Application Configuration
    app_host: str = "0.0.0.0"
    app_port: int = 8000
    debug: bool = True

    # Database Configuration
    database_url: str = "sqlite:///./data/dutch_learning.db"

    # File Storage Paths
    upload_dir: Path = Path("./data/uploads")
    audio_dir: Path = Path("./data/audio")

    # File Size Limits (in bytes)
    max_file_size: int = 524288000  # 500MB

    # Processing Configuration
    whisper_model: str = "whisper-1"
    gpt_model: str = "gpt-4o-mini"
    explanation_batch_size: int = 5
    max_retries: int = 3

    # Supported file extensions
    supported_video_extensions: set = {".mkv", ".mp4", ".avi", ".webm", ".mov"}
    supported_audio_extensions: set = {".mp3", ".wav", ".m4a", ".flac"}

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        extra = "ignore"

    @property
    def all_supported_extensions(self) -> set:
        """Return all supported file extensions."""
        return self.supported_video_extensions | self.supported_audio_extensions

    def ensure_directories(self) -> None:
        """Create necessary directories if they don't exist."""
        self.upload_dir.mkdir(parents=True, exist_ok=True)
        self.audio_dir.mkdir(parents=True, exist_ok=True)

    def validate_openai_key(self) -> bool:
        """Check if OpenAI API key is configured."""
        return bool(self.openai_api_key and self.openai_api_key != "your_openai_api_key_here")


# Global settings instance
settings = Settings()

# Ensure directories exist on import
settings.ensure_directories()
