"""
Google Drive Sync Service for Dutch Language Learning Application.

Provides bidirectional sync functionality between local database and Google Drive.
"""

import json
import pickle
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload, MediaIoBaseDownload

from app.config import settings


# Scopes for Google Drive - file scope allows creating/modifying files we create
SCOPES = ['https://www.googleapis.com/auth/drive.file']

# Google Drive folder name
DRIVE_FOLDER_NAME = 'Dutch Learn'


class SyncError(Exception):
    """Exception raised for sync-related errors."""
    pass


class SyncService:
    """
    Service for syncing projects with Google Drive.

    Handles authentication, upload, download, and progress merging.
    """

    def __init__(self):
        self.base_dir = Path(settings.base_dir)
        self.credentials_file = self.base_dir / 'credentials.json'
        self.token_file = self.base_dir / 'token.pickle'
        self.export_dir = self.base_dir / 'export_for_drive'
        self._service = None
        self._drive_folder_id = None

    @property
    def is_configured(self) -> bool:
        """Check if Google Drive credentials are configured."""
        return self.credentials_file.exists()

    @property
    def is_authenticated(self) -> bool:
        """Check if we have valid authentication."""
        if not self.token_file.exists():
            return False
        try:
            creds = self._load_credentials()
            return creds is not None and creds.valid
        except Exception:
            return False

    def _load_credentials(self):
        """Load OAuth credentials from token file."""
        if not self.token_file.exists():
            return None

        with open(self.token_file, 'rb') as token:
            return pickle.load(token)

    def _save_credentials(self, creds):
        """Save OAuth credentials to token file."""
        with open(self.token_file, 'wb') as token:
            pickle.dump(creds, token)

    def get_credentials(self):
        """
        Get or refresh OAuth credentials.

        Returns valid credentials, refreshing if needed.
        Raises SyncError if authentication fails.
        """
        if not self.is_configured:
            raise SyncError('Google Drive credentials not configured. Place credentials.json in the project directory.')

        creds = self._load_credentials()

        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
            else:
                flow = InstalledAppFlow.from_client_secrets_file(
                    str(self.credentials_file), SCOPES)
                creds = flow.run_local_server(port=0)

            self._save_credentials(creds)

        return creds

    def get_service(self):
        """Get or create Google Drive API service."""
        if self._service is None:
            creds = self.get_credentials()
            self._service = build('drive', 'v3', credentials=creds)
        return self._service

    def _find_folder(self, folder_name: str, parent_id: Optional[str] = None) -> Optional[str]:
        """Find a folder by name in Google Drive."""
        service = self.get_service()

        query = f"name='{folder_name}' and mimeType='application/vnd.google-apps.folder' and trashed=false"
        if parent_id:
            query += f" and '{parent_id}' in parents"

        results = service.files().list(
            q=query,
            spaces='drive',
            fields='files(id, name)'
        ).execute()

        files = results.get('files', [])
        return files[0]['id'] if files else None

    def _create_folder(self, folder_name: str, parent_id: Optional[str] = None) -> str:
        """Create a folder in Google Drive."""
        service = self.get_service()

        file_metadata = {
            'name': folder_name,
            'mimeType': 'application/vnd.google-apps.folder'
        }
        if parent_id:
            file_metadata['parents'] = [parent_id]

        folder = service.files().create(
            body=file_metadata,
            fields='id'
        ).execute()

        return folder.get('id')

    def _get_or_create_drive_folder(self) -> str:
        """Get or create the Dutch Learn folder in Drive."""
        if self._drive_folder_id:
            return self._drive_folder_id

        self._drive_folder_id = self._find_folder(DRIVE_FOLDER_NAME)
        if not self._drive_folder_id:
            self._drive_folder_id = self._create_folder(DRIVE_FOLDER_NAME)

        return self._drive_folder_id

    def _upload_file(self, file_path: Path, parent_id: str) -> dict:
        """Upload a file to Google Drive."""
        service = self.get_service()

        # Determine MIME type
        suffix = file_path.suffix.lower()
        mime_types = {
            '.json': 'application/json',
            '.mp3': 'audio/mpeg',
            '.m4a': 'audio/mp4',
            '.wav': 'audio/wav',
        }
        mime_type = mime_types.get(suffix, 'application/octet-stream')

        # Check if file already exists
        query = f"name='{file_path.name}' and '{parent_id}' in parents and trashed=false"
        results = service.files().list(q=query, fields='files(id)').execute()
        existing = results.get('files', [])

        media = MediaFileUpload(
            str(file_path),
            mimetype=mime_type,
            resumable=True
        )

        if existing:
            # Update existing file
            file = service.files().update(
                fileId=existing[0]['id'],
                media_body=media,
                fields='id, name, modifiedTime'
            ).execute()
        else:
            # Create new file
            file_metadata = {
                'name': file_path.name,
                'parents': [parent_id]
            }
            file = service.files().create(
                body=file_metadata,
                media_body=media,
                fields='id, name, modifiedTime'
            ).execute()

        return file

    def _download_file(self, file_id: str, dest_path: Path) -> None:
        """Download a file from Google Drive."""
        service = self.get_service()

        request = service.files().get_media(fileId=file_id)

        dest_path.parent.mkdir(parents=True, exist_ok=True)

        with open(dest_path, 'wb') as f:
            downloader = MediaIoBaseDownload(f, request)
            done = False
            while not done:
                _, done = downloader.next_chunk()

    def _list_drive_projects(self) -> list:
        """List all project folders in Dutch Learn on Drive."""
        service = self.get_service()
        drive_folder_id = self._get_or_create_drive_folder()

        # Find all subfolders (projects)
        query = f"'{drive_folder_id}' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false"
        results = service.files().list(
            q=query,
            fields='files(id, name, modifiedTime)'
        ).execute()

        return results.get('files', [])

    def _list_project_files(self, project_folder_id: str) -> list:
        """List files in a project folder."""
        service = self.get_service()

        query = f"'{project_folder_id}' in parents and trashed=false"
        results = service.files().list(
            q=query,
            fields='files(id, name, mimeType, modifiedTime)'
        ).execute()

        return results.get('files', [])

    async def upload_to_drive(self, project_ids: Optional[list] = None) -> dict:
        """
        Upload projects to Google Drive.

        Args:
            project_ids: Optional list of project IDs to upload. If None, uploads all.

        Returns:
            dict with upload results
        """
        from app.database import get_db
        from app.models import Project

        results = {
            'uploaded': [],
            'errors': [],
            'skipped': []
        }

        # Get Drive folder
        drive_folder_id = self._get_or_create_drive_folder()

        # Get projects from database
        db = next(get_db())
        try:
            query = db.query(Project).filter(Project.status == 'ready')
            if project_ids:
                query = query.filter(Project.id.in_(project_ids))

            projects = query.all()

            for project in projects:
                try:
                    # Export project to JSON
                    export_data = self._export_project(project, db)

                    # Create project folder in Drive
                    project_folder_id = self._find_folder(project.id, drive_folder_id)
                    if not project_folder_id:
                        project_folder_id = self._create_folder(project.id, drive_folder_id)

                    # Write and upload project.json
                    temp_json = self.export_dir / project.id / 'project.json'
                    temp_json.parent.mkdir(parents=True, exist_ok=True)
                    with open(temp_json, 'w', encoding='utf-8') as f:
                        json.dump(export_data, f, ensure_ascii=False, indent=2)

                    self._upload_file(temp_json, project_folder_id)

                    # Upload audio file if exists
                    audio_path = Path(settings.audio_dir) / f"{project.id}.mp3"
                    if audio_path.exists():
                        # Copy to export dir with standard name
                        import shutil
                        temp_audio = self.export_dir / project.id / 'audio.mp3'
                        shutil.copy(audio_path, temp_audio)
                        self._upload_file(temp_audio, project_folder_id)

                    results['uploaded'].append({
                        'id': project.id,
                        'name': project.name
                    })

                except Exception as e:
                    results['errors'].append({
                        'id': project.id,
                        'error': str(e)
                    })
        finally:
            db.close()

        return results

    def _export_project(self, project, db) -> dict:
        """Export a project to JSON format."""
        from app.models import Sentence, Keyword, Speaker

        sentences = db.query(Sentence).filter(Sentence.project_id == project.id).order_by(Sentence.idx).all()
        keywords = db.query(Keyword).filter(Keyword.sentence_id.in_([s.id for s in sentences])).all()
        speakers = db.query(Speaker).filter(Speaker.project_id == project.id).all()

        # Build keyword lookup by sentence_id
        keyword_map = {}
        for k in keywords:
            keyword_map.setdefault(k.sentence_id, []).append(k)

        return {
            'id': project.id,
            'name': project.name,
            'status': project.status,
            'created_at': project.created_at.isoformat() if project.created_at else None,
            'updated_at': project.updated_at.isoformat() if project.updated_at else None,
            'speakers': [
                {
                    'id': sp.id,
                    'label': sp.label,
                    'display_name': sp.display_name,
                    'confidence': sp.confidence,
                    'evidence': sp.evidence,
                    'is_manual': sp.is_manual,
                }
                for sp in speakers
            ],
            'sentences': [
                {
                    'id': s.id,
                    'index': s.idx,
                    'text': s.text,
                    'start_time': s.start_time,
                    'end_time': s.end_time,
                    'translation_en': s.translation_en,
                    'explanation_nl': s.explanation_nl,
                    'explanation_en': s.explanation_en,
                    'speaker_id': s.speaker_id,
                    'learned': s.learned or False,
                    'learn_count': s.learn_count or 0,
                    'is_difficult': s.is_difficult or False,
                    'review_count': s.review_count or 0,
                    'last_reviewed': s.last_reviewed.isoformat() if s.last_reviewed else None,
                    'keywords': [
                        {
                            'word': k.word,
                            'meaning_nl': k.meaning_nl,
                            'meaning_en': k.meaning_en,
                        }
                        for k in keyword_map.get(s.id, [])
                    ],
                }
                for s in sentences
            ],
            'keywords': [
                {
                    'id': k.id,
                    'word': k.word,
                    'meaning_nl': k.meaning_nl,
                    'meaning_en': k.meaning_en,
                    'sentence_id': k.sentence_id,
                }
                for k in keywords
            ],
            'progress': {
                'total_sentences': len(sentences),
                'learned_sentences': sum(1 for s in sentences if s.learned),
                'difficult_sentences': sum(1 for s in sentences if s.is_difficult),
                'last_sync': datetime.now(timezone.utc).isoformat(),
            }
        }

    async def download_from_drive(self, project_ids: Optional[list] = None) -> dict:
        """
        Download projects from Google Drive.

        Args:
            project_ids: Optional list of project IDs to download. If None, downloads all.

        Returns:
            dict with download results
        """
        from app.services.progress_merger import ProgressMerger

        results = {
            'downloaded': [],
            'merged': [],
            'errors': [],
            'new': []
        }

        # List projects on Drive
        drive_projects = self._list_drive_projects()

        if project_ids:
            drive_projects = [p for p in drive_projects if p['name'] in project_ids]

        for project_folder in drive_projects:
            try:
                project_id = project_folder['name']
                project_folder_id = project_folder['id']

                # List files in project folder
                files = self._list_project_files(project_folder_id)

                # Find project.json
                json_file = next((f for f in files if f['name'] == 'project.json'), None)
                if not json_file:
                    results['errors'].append({
                        'id': project_id,
                        'error': 'project.json not found'
                    })
                    continue

                # Download project.json to temp location
                temp_dir = self.export_dir / 'downloads' / project_id
                temp_dir.mkdir(parents=True, exist_ok=True)

                json_path = temp_dir / 'project.json'
                self._download_file(json_file['id'], json_path)

                with open(json_path, 'r', encoding='utf-8') as f:
                    remote_data = json.load(f)

                # Check if project exists locally
                from app.database import get_db
                from app.models import Project

                db = next(get_db())
                try:
                    local_project = db.query(Project).filter(Project.id == project_id).first()

                    if local_project:
                        # Merge progress
                        merger = ProgressMerger()
                        merged_data = merger.merge(
                            self._export_project(local_project, db),
                            remote_data
                        )

                        # Update local database with merged data
                        self._import_project(merged_data, db)

                        results['merged'].append({
                            'id': project_id,
                            'name': remote_data.get('name', project_id)
                        })
                    else:
                        # New project - import entirely
                        self._import_project(remote_data, db)

                        # Download audio if available
                        audio_file = next((f for f in files if f['name'] == 'audio.mp3'), None)
                        if audio_file:
                            audio_path = Path(settings.audio_dir) / f"{project_id}.mp3"
                            self._download_file(audio_file['id'], audio_path)

                        results['new'].append({
                            'id': project_id,
                            'name': remote_data.get('name', project_id)
                        })

                    results['downloaded'].append({
                        'id': project_id,
                        'name': remote_data.get('name', project_id)
                    })
                finally:
                    db.close()

            except Exception as e:
                results['errors'].append({
                    'id': project_folder['name'],
                    'error': str(e)
                })

        return results

    def _import_project(self, data: dict, db) -> None:
        """Import a project from JSON data into database."""
        import uuid as _uuid
        from app.models import Project, Sentence, Keyword, Speaker
        from datetime import datetime

        project_id = data['id']

        # Get or create project
        project = db.query(Project).filter(Project.id == project_id).first()
        if not project:
            project = Project(
                id=project_id,
                name=data.get('name', project_id),
                status=data.get('status', 'ready'),
            )
            db.add(project)
        else:
            project.name = data.get('name', project.name)
            project.status = data.get('status', project.status)

        # Import speakers
        for sp_data in data.get('speakers', []):
            speaker = db.query(Speaker).filter(Speaker.id == sp_data['id']).first()
            if speaker:
                # Only update if not manually set locally, or if remote is manual
                if not speaker.is_manual or sp_data.get('is_manual', False):
                    speaker.display_name = sp_data.get('display_name')
                    speaker.is_manual = sp_data.get('is_manual', False)
            else:
                speaker = Speaker(
                    id=sp_data['id'],
                    project_id=project_id,
                    label=sp_data['label'],
                    display_name=sp_data.get('display_name'),
                    confidence=sp_data.get('confidence', 0.0),
                    evidence=sp_data.get('evidence'),
                    is_manual=sp_data.get('is_manual', False),
                )
                db.add(speaker)

        # Update sentences
        for s_data in data.get('sentences', []):
            sentence = db.query(Sentence).filter(Sentence.id == s_data['id']).first()
            if sentence:
                # Update learning progress
                sentence.learned = s_data.get('learned', sentence.learned)
                sentence.learn_count = s_data.get('learn_count', sentence.learn_count)
                sentence.is_difficult = s_data.get('is_difficult', sentence.is_difficult)
                sentence.review_count = max(
                    s_data.get('review_count', 0) or 0,
                    sentence.review_count or 0,
                )
                lr_str = s_data.get('last_reviewed')
                if lr_str:
                    try:
                        remote_lr = datetime.fromisoformat(lr_str.replace('Z', '+00:00'))
                        # Make naive for comparison with SQLite-stored timestamps
                        if remote_lr.tzinfo is not None:
                            remote_lr = remote_lr.replace(tzinfo=None)
                        if not sentence.last_reviewed or remote_lr > sentence.last_reviewed:
                            sentence.last_reviewed = remote_lr
                    except (ValueError, TypeError):
                        pass
            else:
                sentence = Sentence(
                    id=s_data['id'],
                    project_id=project_id,
                    idx=s_data.get('index', s_data.get('idx', 0)),
                    text=s_data['text'],
                    start_time=s_data.get('start_time'),
                    end_time=s_data.get('end_time'),
                    translation_en=s_data.get('translation_en'),
                    explanation_nl=s_data.get('explanation_nl'),
                    explanation_en=s_data.get('explanation_en'),
                    speaker_id=s_data.get('speaker_id'),
                    learned=s_data.get('learned', False),
                    learn_count=s_data.get('learn_count', 0),
                    is_difficult=s_data.get('is_difficult', False),
                    review_count=s_data.get('review_count', 0),
                    last_reviewed=datetime.fromisoformat(s_data['last_reviewed'].replace('Z', '+00:00')) if s_data.get('last_reviewed') else None,
                )
                db.add(sentence)

        # Update keywords (top-level format)
        for k_data in data.get('keywords', []):
            keyword = db.query(Keyword).filter(Keyword.id == k_data['id']).first()
            if not keyword:
                keyword = Keyword(
                    id=k_data['id'],
                    sentence_id=k_data.get('sentence_id'),
                    word=k_data['word'],
                    meaning_nl=k_data.get('meaning_nl'),
                    meaning_en=k_data.get('meaning_en'),
                )
                db.add(keyword)

        # Import keywords from sentences (nested format)
        for s_data in data.get('sentences', []):
            sentence_id = s_data['id']
            # Check if this sentence exists locally
            sentence = db.query(Sentence).filter(Sentence.id == sentence_id).first()
            if sentence:
                for k_data in s_data.get('keywords', []):
                    # Check by word + sentence_id to avoid duplicates
                    existing = db.query(Keyword).filter(
                        Keyword.sentence_id == sentence_id,
                        Keyword.word == k_data.get('word', ''),
                    ).first()
                    if not existing:
                        keyword = Keyword(
                            id=str(_uuid.uuid4()),
                            sentence_id=sentence_id,
                            word=k_data.get('word', ''),
                            meaning_nl=k_data.get('meaning_nl'),
                            meaning_en=k_data.get('meaning_en'),
                        )
                        db.add(keyword)

        db.commit()

    def get_sync_status(self) -> dict:
        """Get current sync status."""
        from app.database import get_db
        from app.models import Project

        status = {
            'configured': self.is_configured,
            'authenticated': self.is_authenticated,
            'local_projects': 0,
            'remote_projects': 0,
            'last_sync': None,
        }

        # Count local projects
        db = next(get_db())
        try:
            status['local_projects'] = db.query(Project).filter(Project.status == 'ready').count()
        finally:
            db.close()

        # Count remote projects if authenticated
        if self.is_authenticated:
            try:
                remote_projects = self._list_drive_projects()
                status['remote_projects'] = len(remote_projects)
            except Exception:
                pass

        return status
