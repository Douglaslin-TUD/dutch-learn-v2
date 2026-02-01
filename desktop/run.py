#!/usr/bin/env python3
"""
Application runner for Dutch Language Learning Application.

Usage:
    python run.py

This script loads environment variables and starts the FastAPI server.
"""

import os
import sys
from pathlib import Path

# Add the project root to Python path
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

# Load environment variables
from dotenv import load_dotenv
load_dotenv()

import uvicorn
from app.config import settings


def main() -> None:
    """Run the FastAPI application server."""
    print(f"Starting Dutch Language Learning Application...")
    print(f"Server running at: http://{settings.app_host}:{settings.app_port}")
    print(f"API Documentation: http://{settings.app_host}:{settings.app_port}/docs")

    uvicorn.run(
        "app.main:app",
        host=settings.app_host,
        port=settings.app_port,
        reload=settings.debug,
        log_level="info" if settings.debug else "warning",
    )


if __name__ == "__main__":
    main()
