"""
Audio streaming API router.

Provides endpoints for streaming audio files associated with projects.
"""

from pathlib import Path
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import FileResponse, StreamingResponse
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models import Project


router = APIRouter(prefix="/api/audio", tags=["audio"])


def get_content_type(filename: str) -> str:
    """
    Get the content type for an audio file based on extension.

    Args:
        filename: The filename to check.

    Returns:
        str: MIME type for the audio file.
    """
    extension = Path(filename).suffix.lower()
    content_types = {
        ".mp3": "audio/mpeg",
        ".wav": "audio/wav",
        ".m4a": "audio/mp4",
        ".flac": "audio/flac",
        ".ogg": "audio/ogg",
    }
    return content_types.get(extension, "audio/mpeg")


def parse_range_header(range_header: str, file_size: int) -> tuple[int, int]:
    """
    Parse HTTP Range header for partial content requests.

    Args:
        range_header: The Range header value (e.g., "bytes=0-1000").
        file_size: Total file size in bytes.

    Returns:
        tuple: (start_byte, end_byte)

    Raises:
        ValueError: If range header is invalid.
    """
    if not range_header.startswith("bytes="):
        raise ValueError("Invalid range header format")

    range_spec = range_header[6:]  # Remove "bytes="

    if "-" not in range_spec:
        raise ValueError("Invalid range header format")

    start_str, end_str = range_spec.split("-", 1)

    if start_str:
        start = int(start_str)
    else:
        start = 0

    if end_str:
        end = min(int(end_str), file_size - 1)
    else:
        end = file_size - 1

    if start > end or start >= file_size:
        raise ValueError("Invalid range")

    return start, end


async def stream_file_range(
    file_path: Path,
    start: int,
    end: int,
    chunk_size: int = 1024 * 1024,  # 1MB chunks
):
    """
    Generator for streaming a byte range from a file.

    Args:
        file_path: Path to the file.
        start: Start byte position.
        end: End byte position (inclusive).
        chunk_size: Size of chunks to yield.

    Yields:
        bytes: File content chunks.
    """
    with open(file_path, "rb") as f:
        f.seek(start)
        remaining = end - start + 1

        while remaining > 0:
            read_size = min(chunk_size, remaining)
            data = f.read(read_size)
            if not data:
                break
            remaining -= len(data)
            yield data


@router.get("/{project_id}")
async def stream_audio(
    project_id: str,
    request: Request,
    db: Session = Depends(get_db),
):
    """
    Stream audio file for a project.

    Supports HTTP Range requests for seeking in audio playback.

    Args:
        project_id: The project UUID.
        request: FastAPI request object (for Range header).
        db: Database session.

    Returns:
        StreamingResponse or FileResponse: Audio file content.

    Raises:
        HTTPException: If project not found or audio file missing.
    """
    # Get project
    project = db.query(Project).filter(Project.id == project_id).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    if not project.audio_file:
        raise HTTPException(
            status_code=404,
            detail="Audio file not available. Processing may not be complete.",
        )

    # Build audio file path
    audio_path = settings.audio_dir / project.audio_file

    if not audio_path.exists():
        raise HTTPException(
            status_code=404,
            detail="Audio file not found on disk",
        )

    file_size = audio_path.stat().st_size
    content_type = get_content_type(project.audio_file)

    # Check for Range header (for seeking support)
    range_header = request.headers.get("range")

    if range_header:
        try:
            start, end = parse_range_header(range_header, file_size)
            content_length = end - start + 1

            return StreamingResponse(
                stream_file_range(audio_path, start, end),
                status_code=206,  # Partial Content
                media_type=content_type,
                headers={
                    "Content-Range": f"bytes {start}-{end}/{file_size}",
                    "Accept-Ranges": "bytes",
                    "Content-Length": str(content_length),
                    "Content-Disposition": f'inline; filename="{project.audio_file}"',
                },
            )

        except ValueError:
            # Invalid range, fall back to full file
            pass

    # Return full file
    return FileResponse(
        path=audio_path,
        media_type=content_type,
        filename=project.audio_file,
        headers={
            "Accept-Ranges": "bytes",
            "Content-Length": str(file_size),
        },
    )


@router.head("/{project_id}")
async def audio_head(
    project_id: str,
    db: Session = Depends(get_db),
):
    """
    HEAD request for audio file metadata.

    Used by audio players to get file size before streaming.

    Args:
        project_id: The project UUID.
        db: Database session.

    Returns:
        Response with headers only.

    Raises:
        HTTPException: If project not found or audio file missing.
    """
    project = db.query(Project).filter(Project.id == project_id).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    if not project.audio_file:
        raise HTTPException(
            status_code=404,
            detail="Audio file not available",
        )

    audio_path = settings.audio_dir / project.audio_file

    if not audio_path.exists():
        raise HTTPException(status_code=404, detail="Audio file not found")

    file_size = audio_path.stat().st_size
    content_type = get_content_type(project.audio_file)

    return StreamingResponse(
        content=iter([]),  # Empty content for HEAD
        media_type=content_type,
        headers={
            "Accept-Ranges": "bytes",
            "Content-Length": str(file_size),
        },
    )
