#!/usr/bin/env python3
"""Upload Dutch Learn projects to Google Drive."""

import os
import pickle
from pathlib import Path
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

# Scopes for Google Drive
SCOPES = ['https://www.googleapis.com/auth/drive.file']

BASE_DIR = Path('/data/AI  Tools/Audio for Dutch Learn')
CREDENTIALS_FILE = BASE_DIR / 'credentials.json'
TOKEN_FILE = BASE_DIR / 'token.pickle'
EXPORT_DIR = BASE_DIR / 'export_for_drive'


def get_credentials():
    """Get or refresh OAuth credentials."""
    creds = None

    # Load existing token
    if TOKEN_FILE.exists():
        with open(TOKEN_FILE, 'rb') as token:
            creds = pickle.load(token)

    # Refresh or get new credentials
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(
                str(CREDENTIALS_FILE), SCOPES)
            creds = flow.run_local_server(port=0)

        # Save token for next run
        with open(TOKEN_FILE, 'wb') as token:
            pickle.dump(creds, token)

    return creds


def find_folder(service, folder_name, parent_id=None):
    """Find a folder by name in Google Drive."""
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


def create_folder(service, folder_name, parent_id=None):
    """Create a folder in Google Drive."""
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


def upload_file(service, file_path, parent_id):
    """Upload a file to Google Drive."""
    file_name = os.path.basename(file_path)

    # Determine MIME type
    if file_name.endswith('.json'):
        mime_type = 'application/json'
    elif file_name.endswith('.mp3'):
        mime_type = 'audio/mpeg'
    else:
        mime_type = 'application/octet-stream'

    file_metadata = {
        'name': file_name,
        'parents': [parent_id]
    }

    media = MediaFileUpload(
        file_path,
        mimetype=mime_type,
        resumable=True
    )

    file = service.files().create(
        body=file_metadata,
        media_body=media,
        fields='id, name'
    ).execute()

    return file


def main():
    print("Authenticating with Google Drive...")
    creds = get_credentials()
    service = build('drive', 'v3', credentials=creds)

    # Find or create Dutch Learn folder
    print("Finding 'Dutch Learn' folder...")
    dutch_learn_id = find_folder(service, 'Dutch Learn')

    if not dutch_learn_id:
        print("Creating 'Dutch Learn' folder...")
        dutch_learn_id = create_folder(service, 'Dutch Learn')

    print(f"Dutch Learn folder ID: {dutch_learn_id}")

    # Upload each project folder
    for project_dir in EXPORT_DIR.iterdir():
        if not project_dir.is_dir():
            continue

        project_name = project_dir.name
        print(f"\nUploading project: {project_name}")

        # Create project subfolder
        project_folder_id = create_folder(service, project_name, dutch_learn_id)
        print(f"  Created folder: {project_name}")

        # Upload files in the project folder
        for file_path in project_dir.iterdir():
            if file_path.is_file():
                print(f"  Uploading: {file_path.name}...", end=' ')
                result = upload_file(service, str(file_path), project_folder_id)
                print(f"Done (ID: {result['id']})")

    print("\n=== Upload complete! ===")
    print("You can now import the projects in the Dutch Learn app.")


if __name__ == '__main__':
    main()
