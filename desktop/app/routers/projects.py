"""
Projects API router.

Provides CRUD operations for projects including file upload and processing status.
Also provides export/import functionality for data synchronization.
"""

import json
from pathlib import Path
from typing import List, Optional
import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, BackgroundTasks, Body
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db, init_db
from app.models import Project, Sentence, Keyword, Speaker
from app.services.processor import process_project_background
from app.utils.file_utils import (
    validate_file_extension,
    validate_file_size,
    generate_unique_filename,
    get_file_extension,
    cleanup_project_files,
    FileValidationError,
)


router = APIRouter(prefix="/api/projects", tags=["projects"])


# Pydantic schemas for API responses
class KeywordResponse(BaseModel):
    """Schema for keyword data in API responses."""
    id: str
    word: str
    meaning_nl: str
    meaning_en: str

    class Config:
        from_attributes = True


class SentenceResponse(BaseModel):
    """Schema for sentence data in API responses."""
    id: str
    index: int
    text: str
    start_time: float
    end_time: float
    duration: float
    translation_en: Optional[str]
    explanation_nl: Optional[str]
    explanation_en: Optional[str]
    has_explanation: bool
    keywords: List[KeywordResponse]

    class Config:
        from_attributes = True


class ProjectListItem(BaseModel):
    """Schema for project list item."""
    id: str
    name: str
    status: str
    progress: int
    created_at: str

    class Config:
        from_attributes = True


class ProjectDetail(BaseModel):
    """Schema for detailed project data."""
    id: str
    name: str
    original_file: str
    audio_file: Optional[str]
    status: str
    error_message: Optional[str]
    progress: int
    current_stage: str
    total_sentences: int
    processed_sentences: int
    created_at: str
    updated_at: str
    sentences: List[SentenceResponse]

    class Config:
        from_attributes = True


class ProjectStatus(BaseModel):
    """Schema for project processing status."""
    id: str
    status: str
    progress: int
    current_stage: str
    error_message: Optional[str]

    class Config:
        from_attributes = True


class ProjectListResponse(BaseModel):
    """Schema for project list response."""
    projects: List[ProjectListItem]


# Ensure database is initialized
init_db()


@router.get("", response_model=ProjectListResponse)
async def list_projects(db: Session = Depends(get_db)) -> ProjectListResponse:
    """
    List all projects.

    Returns:
        ProjectListResponse: List of all projects with basic info.
    """
    projects = db.query(Project).order_by(Project.created_at.desc()).all()

    return ProjectListResponse(
        projects=[
            ProjectListItem(
                id=p.id,
                name=p.name,
                status=p.status,
                progress=p.progress,
                created_at=p.created_at.isoformat() if p.created_at else "",
            )
            for p in projects
        ]
    )


@router.post("", response_model=ProjectListItem)
async def create_project(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
) -> ProjectListItem:
    """
    Create a new project by uploading a file.

    Uploads the file, creates a project record, and starts background processing.

    Args:
        background_tasks: FastAPI background tasks for async processing.
        file: The uploaded audio/video file.
        db: Database session.

    Returns:
        ProjectListItem: The created project info.

    Raises:
        HTTPException: If file validation fails or upload fails.
    """
    # Validate file
    if not file.filename:
        raise HTTPException(status_code=400, detail="No filename provided")

    try:
        validate_file_extension(file.filename)
    except FileValidationError as e:
        raise HTTPException(status_code=400, detail=str(e))

    # Read file content
    content = await file.read()

    try:
        validate_file_size(len(content))
    except FileValidationError as e:
        raise HTTPException(status_code=400, detail=str(e))

    # Generate unique filename and save file
    unique_filename = generate_unique_filename(file.filename)
    upload_path = settings.upload_dir / unique_filename

    try:
        with open(upload_path, "wb") as f:
            f.write(content)
    except IOError as e:
        raise HTTPException(status_code=500, detail=f"Failed to save file: {str(e)}")

    # Create project record
    project_id = str(uuid.uuid4())
    project_name = Path(file.filename).stem  # Filename without extension

    project = Project(
        id=project_id,
        name=project_name,
        original_file=unique_filename,
        status="pending",
    )
    db.add(project)
    db.commit()
    db.refresh(project)

    # Start background processing
    background_tasks.add_task(process_project_background, project_id)

    return ProjectListItem(
        id=project.id,
        name=project.name,
        status=project.status,
        progress=project.progress,
        created_at=project.created_at.isoformat() if project.created_at else "",
    )


@router.get("/{project_id}")
async def get_project(
    project_id: str,
    db: Session = Depends(get_db),
):
    """
    Get a specific project with sentences and speakers.

    Args:
        project_id: The project UUID.
        db: Database session.

    Returns:
        dict: Full project data with sentences, keywords, and speakers.

    Raises:
        HTTPException: If project not found.
    """
    project = db.query(Project).filter(Project.id == project_id).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    return project.to_dict(include_sentences=True, include_speakers=True)


@router.delete("/{project_id}")
async def delete_project(
    project_id: str,
    db: Session = Depends(get_db),
) -> JSONResponse:
    """
    Delete a project and all associated files.

    Args:
        project_id: The project UUID.
        db: Database session.

    Returns:
        JSONResponse: Success message.

    Raises:
        HTTPException: If project not found.
    """
    project = db.query(Project).filter(Project.id == project_id).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    # Clean up files
    cleanup_project_files(project.original_file, project.audio_file)

    # Delete project (cascades to sentences and keywords)
    db.delete(project)
    db.commit()

    return JSONResponse(
        content={"message": "Project deleted successfully", "id": project_id}
    )


@router.get("/{project_id}/status", response_model=ProjectStatus)
async def get_project_status(
    project_id: str,
    db: Session = Depends(get_db),
) -> ProjectStatus:
    """
    Get the current processing status of a project.

    Args:
        project_id: The project UUID.
        db: Database session.

    Returns:
        ProjectStatus: Current processing status and progress.

    Raises:
        HTTPException: If project not found.
    """
    project = db.query(Project).filter(Project.id == project_id).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    return ProjectStatus(
        id=project.id,
        status=project.status,
        progress=project.progress,
        current_stage=project.current_stage_description,
        error_message=project.error_message,
    )


@router.get("/{project_id}/export")
async def export_project(
    project_id: str,
    db: Session = Depends(get_db),
) -> Response:
    """
    Export a project with all sentences and keywords as JSON.

    This endpoint allows exporting project data for backup or sync with Android app.
    The exported JSON includes all processed data (sentences, translations, explanations, keywords).

    Args:
        project_id: The project UUID.
        db: Database session.

    Returns:
        Response: JSON file download.

    Raises:
        HTTPException: If project not found.
    """
    project = db.query(Project).filter(Project.id == project_id).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    sentences = (
        db.query(Sentence)
        .filter(Sentence.project_id == project_id)
        .order_by(Sentence.idx)
        .all()
    )

    export_data = {
        "version": "1.0",
        "exported_at": datetime.utcnow().isoformat(),
        "project": {
            "id": project.id,
            "name": project.name,
            "status": project.status,
            "total_sentences": project.total_sentences,
            "created_at": project.created_at.isoformat() if project.created_at else None,
        },
        "sentences": []
    }

    for s in sentences:
        keywords = db.query(Keyword).filter(Keyword.sentence_id == s.id).all()
        export_data["sentences"].append({
            "index": s.idx,
            "text": s.text,
            "start_time": s.start_time,
            "end_time": s.end_time,
            "translation_en": s.translation_en,
            "explanation_nl": s.explanation_nl,
            "explanation_en": s.explanation_en,
            "keywords": [
                {
                    "word": k.word,
                    "meaning_nl": k.meaning_nl,
                    "meaning_en": k.meaning_en,
                }
                for k in keywords
            ],
        })

    json_content = json.dumps(export_data, ensure_ascii=False, indent=2)
    filename = f"{project.name}_export.json"

    return Response(
        content=json_content,
        media_type="application/json",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
        },
    )


@router.get("/export/all")
async def export_all_projects(
    db: Session = Depends(get_db),
) -> Response:
    """
    Export all projects with sentences and keywords as JSON.

    This endpoint allows exporting all project data for backup or sync with Android app.

    Args:
        db: Database session.

    Returns:
        Response: JSON file download containing all projects.
    """
    projects = db.query(Project).filter(Project.status == "ready").all()

    export_data = {
        "version": "1.0",
        "exported_at": datetime.utcnow().isoformat(),
        "projects": []
    }

    for project in projects:
        sentences = (
            db.query(Sentence)
            .filter(Sentence.project_id == project.id)
            .order_by(Sentence.idx)
            .all()
        )

        project_data = {
            "id": project.id,
            "name": project.name,
            "status": project.status,
            "total_sentences": project.total_sentences,
            "created_at": project.created_at.isoformat() if project.created_at else None,
            "sentences": []
        }

        for s in sentences:
            keywords = db.query(Keyword).filter(Keyword.sentence_id == s.id).all()
            project_data["sentences"].append({
                "index": s.idx,
                "text": s.text,
                "start_time": s.start_time,
                "end_time": s.end_time,
                "translation_en": s.translation_en,
                "explanation_nl": s.explanation_nl,
                "explanation_en": s.explanation_en,
                "keywords": [
                    {
                        "word": k.word,
                        "meaning_nl": k.meaning_nl,
                        "meaning_en": k.meaning_en,
                    }
                    for k in keywords
                ],
            })

        export_data["projects"].append(project_data)

    json_content = json.dumps(export_data, ensure_ascii=False, indent=2)

    return Response(
        content=json_content,
        media_type="application/json",
        headers={
            "Content-Disposition": 'attachment; filename="dutch_learn_export.json"',
        },
    )


@router.post("/import")
async def import_project(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
) -> JSONResponse:
    """
    Import a project from exported JSON file.

    This endpoint allows importing project data from a backup or from another device.
    Note: Audio files are not included in the export; only text data is imported.

    Args:
        file: The JSON file to import.
        db: Database session.

    Returns:
        JSONResponse: Import result with project IDs.

    Raises:
        HTTPException: If import fails.
    """
    if not file.filename or not file.filename.endswith('.json'):
        raise HTTPException(status_code=400, detail="Please upload a JSON file")

    try:
        content = await file.read()
        import_data = json.loads(content.decode('utf-8'))
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid JSON file")

    imported_projects = []

    # Handle single project export
    if "project" in import_data:
        projects_to_import = [{
            **import_data["project"],
            "sentences": import_data.get("sentences", [])
        }]
    # Handle all projects export
    elif "projects" in import_data:
        projects_to_import = import_data["projects"]
    else:
        raise HTTPException(status_code=400, detail="Invalid export format")

    for project_data in projects_to_import:
        # Check if project already exists
        existing = db.query(Project).filter(Project.id == project_data.get("id")).first()
        if existing:
            # Skip existing projects
            continue

        # Create new project
        project = Project(
            id=str(uuid.uuid4()),  # Generate new ID
            name=project_data.get("name", "Imported Project"),
            original_file="",
            audio_file="",
            status="ready",  # Mark as ready since we're importing processed data
            total_sentences=len(project_data.get("sentences", [])),
            processed_sentences=len(project_data.get("sentences", [])),
        )
        db.add(project)
        db.flush()

        # Import sentences
        for sent_data in project_data.get("sentences", []):
            sentence = Sentence(
                id=str(uuid.uuid4()),
                project_id=project.id,
                idx=sent_data.get("index", 0),
                text=sent_data.get("text", ""),
                start_time=sent_data.get("start_time", 0),
                end_time=sent_data.get("end_time", 0),
                translation_en=sent_data.get("translation_en"),
                explanation_nl=sent_data.get("explanation_nl"),
                explanation_en=sent_data.get("explanation_en"),
            )
            db.add(sentence)
            db.flush()

            # Import keywords
            for kw_data in sent_data.get("keywords", []):
                keyword = Keyword(
                    id=str(uuid.uuid4()),
                    sentence_id=sentence.id,
                    word=kw_data.get("word", ""),
                    meaning_nl=kw_data.get("meaning_nl", ""),
                    meaning_en=kw_data.get("meaning_en", ""),
                )
                db.add(keyword)

        imported_projects.append({
            "id": project.id,
            "name": project.name,
            "sentences_count": len(project_data.get("sentences", [])),
        })

    db.commit()

    return JSONResponse(
        content={
            "message": f"Successfully imported {len(imported_projects)} project(s)",
            "projects": imported_projects,
        }
    )


@router.put("/{project_id}/speakers/{speaker_id}")
async def update_speaker(
    project_id: str,
    speaker_id: str,
    name: str = Body(..., embed=True),
    db: Session = Depends(get_db),
):
    """
    Update speaker display name.

    This marks the speaker as manually named, preventing auto-override.

    Args:
        project_id: The project UUID.
        speaker_id: The speaker UUID.
        name: The new display name.
        db: Database session.

    Returns:
        dict: Success status and updated speaker data.

    Raises:
        HTTPException: If speaker not found.
    """
    speaker = (
        db.query(Speaker)
        .filter(Speaker.id == speaker_id, Speaker.project_id == project_id)
        .first()
    )

    if not speaker:
        raise HTTPException(status_code=404, detail="Speaker not found")

    speaker.display_name = name
    speaker.is_manual = True
    db.commit()

    return {"success": True, "speaker": speaker.to_dict()}


@router.get("/{project_id}/speakers")
async def get_speakers(
    project_id: str,
    db: Session = Depends(get_db),
):
    """
    Get all speakers for a project.

    Args:
        project_id: The project UUID.
        db: Database session.

    Returns:
        dict: List of speakers.

    Raises:
        HTTPException: If project not found.
    """
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    speakers = (
        db.query(Speaker)
        .filter(Speaker.project_id == project_id)
        .all()
    )

    return {"speakers": [s.to_dict() for s in speakers]}
