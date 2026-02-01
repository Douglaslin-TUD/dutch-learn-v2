"""
API routers for the Dutch Language Learning Application.
"""

from app.routers.projects import router as projects_router
from app.routers.audio import router as audio_router
from app.routers.sync import router as sync_router

__all__ = ["projects_router", "audio_router", "sync_router"]
