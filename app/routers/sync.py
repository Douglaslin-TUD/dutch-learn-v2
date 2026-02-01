"""
API router for Google Drive sync operations.

Provides endpoints for:
- Uploading projects to Google Drive
- Downloading projects from Google Drive
- Getting sync status
"""

from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.services.sync_service import SyncService, SyncError
from app.services.config_encryptor import (
    ConfigEncryptor,
    ConfigEncryptionError,
    export_config_for_mobile,
    generate_transfer_password,
)


router = APIRouter(prefix="/api/sync", tags=["sync"])


class SyncRequest(BaseModel):
    """Request model for sync operations."""
    project_ids: Optional[list[str]] = None


class SyncStatusResponse(BaseModel):
    """Response model for sync status."""
    configured: bool
    authenticated: bool
    local_projects: int
    remote_projects: int
    last_sync: Optional[str] = None


class SyncResultResponse(BaseModel):
    """Response model for sync results."""
    success: bool
    message: str
    uploaded: list[dict] = []
    downloaded: list[dict] = []
    merged: list[dict] = []
    new: list[dict] = []
    errors: list[dict] = []


# Singleton sync service instance
_sync_service: Optional[SyncService] = None


def get_sync_service() -> SyncService:
    """Get or create sync service instance."""
    global _sync_service
    if _sync_service is None:
        _sync_service = SyncService()
    return _sync_service


@router.get("/status", response_model=SyncStatusResponse)
async def get_sync_status():
    """
    Get current sync status.

    Returns:
        SyncStatusResponse with configuration and project counts.
    """
    service = get_sync_service()
    status = service.get_sync_status()
    return SyncStatusResponse(**status)


@router.post("/upload", response_model=SyncResultResponse)
async def upload_to_drive(request: SyncRequest = SyncRequest()):
    """
    Upload projects to Google Drive.

    Args:
        request: Optional list of project IDs to upload. If empty, uploads all.

    Returns:
        SyncResultResponse with upload results.
    """
    service = get_sync_service()

    if not service.is_configured:
        raise HTTPException(
            status_code=400,
            detail="Google Drive not configured. Place credentials.json in the project directory."
        )

    try:
        results = await service.upload_to_drive(request.project_ids)

        uploaded_count = len(results['uploaded'])
        error_count = len(results['errors'])

        if error_count > 0:
            message = f"Uploaded {uploaded_count} project(s) with {error_count} error(s)"
        else:
            message = f"Successfully uploaded {uploaded_count} project(s)"

        return SyncResultResponse(
            success=error_count == 0,
            message=message,
            uploaded=results['uploaded'],
            errors=results['errors']
        )

    except SyncError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Sync failed: {str(e)}")


@router.post("/download", response_model=SyncResultResponse)
async def download_from_drive(request: SyncRequest = SyncRequest()):
    """
    Download projects from Google Drive.

    Args:
        request: Optional list of project IDs to download. If empty, downloads all.

    Returns:
        SyncResultResponse with download results.
    """
    service = get_sync_service()

    if not service.is_configured:
        raise HTTPException(
            status_code=400,
            detail="Google Drive not configured. Place credentials.json in the project directory."
        )

    try:
        results = await service.download_from_drive(request.project_ids)

        downloaded_count = len(results['downloaded'])
        merged_count = len(results['merged'])
        new_count = len(results['new'])
        error_count = len(results['errors'])

        parts = []
        if new_count > 0:
            parts.append(f"{new_count} new")
        if merged_count > 0:
            parts.append(f"{merged_count} merged")
        if error_count > 0:
            parts.append(f"{error_count} error(s)")

        message = f"Downloaded {downloaded_count} project(s)"
        if parts:
            message += f" ({', '.join(parts)})"

        return SyncResultResponse(
            success=error_count == 0,
            message=message,
            downloaded=results['downloaded'],
            merged=results['merged'],
            new=results['new'],
            errors=results['errors']
        )

    except SyncError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Sync failed: {str(e)}")


@router.post("/sync", response_model=SyncResultResponse)
async def full_sync(request: SyncRequest = SyncRequest()):
    """
    Perform full bidirectional sync.

    First uploads local changes, then downloads remote changes.

    Args:
        request: Optional list of project IDs to sync. If empty, syncs all.

    Returns:
        SyncResultResponse with combined results.
    """
    service = get_sync_service()

    if not service.is_configured:
        raise HTTPException(
            status_code=400,
            detail="Google Drive not configured. Place credentials.json in the project directory."
        )

    try:
        # Upload first
        upload_results = await service.upload_to_drive(request.project_ids)

        # Then download
        download_results = await service.download_from_drive(request.project_ids)

        total_errors = upload_results['errors'] + download_results['errors']
        error_count = len(total_errors)

        message = f"Synced: {len(upload_results['uploaded'])} uploaded, {len(download_results['downloaded'])} downloaded"
        if error_count > 0:
            message += f", {error_count} error(s)"

        return SyncResultResponse(
            success=error_count == 0,
            message=message,
            uploaded=upload_results['uploaded'],
            downloaded=download_results['downloaded'],
            merged=download_results['merged'],
            new=download_results['new'],
            errors=total_errors
        )

    except SyncError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Sync failed: {str(e)}")


class ExportConfigRequest(BaseModel):
    """Request model for config export."""
    password: Optional[str] = None  # If not provided, generates a new password


class ExportConfigResponse(BaseModel):
    """Response model for config export."""
    success: bool
    password: str
    message: str
    encrypted_config: Optional[str] = None


@router.post("/export-config", response_model=ExportConfigResponse)
async def export_config(request: ExportConfigRequest = ExportConfigRequest()):
    """
    Export encrypted configuration (API keys) for mobile transfer.

    If no password is provided, generates a secure random password.
    The password must be shared with the mobile device out-of-band.

    Returns:
        ExportConfigResponse with password and encrypted config.
    """
    try:
        # Use provided password or generate new one
        password = request.password or generate_transfer_password()

        # Export config
        result = export_config_for_mobile(password)

        return ExportConfigResponse(
            success=True,
            password=password,
            message="Config exported. Share the password with your mobile device securely.",
            encrypted_config=result['encrypted_config']
        )

    except ConfigEncryptionError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Export failed: {str(e)}")
