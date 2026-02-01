"""
Main FastAPI application for Dutch Language Learning Application.

This module creates and configures the FastAPI app with:
- CORS middleware for browser access
- Static file serving for frontend
- API routers for projects and audio
"""

from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

from app.config import settings
from app.database import init_db
from app.routers import projects_router, audio_router, sync_router


# Create FastAPI application
app = FastAPI(
    title="Dutch Language Learning API",
    description="API for processing Dutch audio/video content with transcription and explanations",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)


# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for local development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Include API routers
app.include_router(projects_router)
app.include_router(audio_router)
app.include_router(sync_router)


# Static files directory
STATIC_DIR = Path(__file__).parent.parent / "static"


# Mount static files if directory exists
if STATIC_DIR.exists():
    app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")


@app.on_event("startup")
async def startup_event():
    """
    Application startup event handler.

    Initializes the database and ensures required directories exist.
    """
    # Initialize database tables
    init_db()

    # Ensure data directories exist
    settings.ensure_directories()

    # Check OpenAI API key
    if not settings.validate_openai_key():
        print("WARNING: OpenAI API key not configured. Set OPENAI_API_KEY in .env file.")


@app.get("/")
async def root():
    """
    Root endpoint - serves the frontend or returns API info.

    Returns:
        FileResponse or dict: Frontend HTML or API info.
    """
    index_path = STATIC_DIR / "index.html"
    if index_path.exists():
        return FileResponse(index_path)

    return {
        "name": "Dutch Language Learning API",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/health",
    }


@app.get("/health")
async def health_check():
    """
    Health check endpoint.

    Returns:
        dict: Health status including API key configuration status.
    """
    return {
        "status": "healthy",
        "api_key_configured": settings.validate_openai_key(),
        "database": "connected",
    }


@app.get("/api")
async def api_info():
    """
    API information endpoint.

    Returns:
        dict: Available API endpoints and information.
    """
    return {
        "name": "Dutch Language Learning API",
        "version": "1.0.0",
        "endpoints": {
            "projects": {
                "list": "GET /api/projects",
                "create": "POST /api/projects",
                "get": "GET /api/projects/{id}",
                "delete": "DELETE /api/projects/{id}",
                "status": "GET /api/projects/{id}/status",
            },
            "audio": {
                "stream": "GET /api/audio/{project_id}",
            },
        },
    }
