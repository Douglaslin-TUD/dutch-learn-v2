#!/usr/bin/env python3
"""
Create a project from an existing file in the uploads folder.
Usage: python create_project_from_existing.py <filename> [project_name]
"""

import sys
import asyncio
import uuid
from pathlib import Path

# Add app to path
sys.path.insert(0, str(Path(__file__).parent))

from app.database import get_db_context
from app.models import Project
from app.config import settings
from app.services.processor import process_project_background


async def create_project_from_existing(filename: str, project_name: str):
    """Create a project from an existing file in uploads folder."""

    # Check if file exists in uploads
    upload_path = settings.upload_dir / filename
    if not upload_path.exists():
        print(f"Error: File not found: {upload_path}")
        return None

    project_id = str(uuid.uuid4())

    with get_db_context() as db:
        project = Project(
            id=project_id,
            name=project_name,
            original_file=filename,
            status="pending",
        )
        db.add(project)
        db.commit()
        print(f"Created project: {project_id}")
        print(f"Name: {project_name}")
        print(f"File: {filename}")

    # Start processing
    print("Starting background processing...")
    await process_project_background(project_id)
    print("Processing complete!")

    return project_id


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python create_project_from_existing.py <filename> [project_name]")
        sys.exit(1)

    filename = sys.argv[1]
    project_name = sys.argv[2] if len(sys.argv) > 2 else Path(filename).stem

    asyncio.run(create_project_from_existing(filename, project_name))
