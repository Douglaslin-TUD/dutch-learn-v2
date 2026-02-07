# desktop/tests/test_projects_api.py
"""Integration tests for /api/projects endpoints."""

import json
import uuid

import pytest

from app.models import Project, Sentence, Keyword, Speaker


class TestListProjects:
    """Tests for GET /api/projects."""

    def test_empty_list(self, client):
        """Empty database should return empty projects list."""
        response = client.get("/api/projects")
        assert response.status_code == 200
        assert response.json()["projects"] == []

    def test_returns_projects(self, client, make_project):
        """Should return all projects."""
        make_project(name="Project A")
        make_project(name="Project B")
        response = client.get("/api/projects")
        assert response.status_code == 200
        assert len(response.json()["projects"]) == 2

    def test_project_list_item_fields(self, client, make_project):
        """Each item in the list should have the expected fields."""
        make_project(name="Test", status="ready")
        response = client.get("/api/projects")
        assert response.status_code == 200
        item = response.json()["projects"][0]
        assert "id" in item
        assert item["name"] == "Test"
        assert item["status"] == "ready"
        assert item["progress"] == 100
        assert "created_at" in item


class TestGetProject:
    """Tests for GET /api/projects/{id}."""

    def test_found(self, client, make_project, make_sentence):
        """Should return project with sentences when found."""
        project = make_project(name="Test")
        make_sentence(project.id, idx=0, text="Hallo")
        response = client.get(f"/api/projects/{project.id}")
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "Test"
        assert len(data["sentences"]) == 1
        assert data["sentences"][0]["text"] == "Hallo"

    def test_includes_speakers(self, client, make_project, make_speaker):
        """Should include speakers in the response."""
        project = make_project()
        make_speaker(project.id, label="A", display_name="Jan")
        response = client.get(f"/api/projects/{project.id}")
        assert response.status_code == 200
        data = response.json()
        assert len(data["speakers"]) == 1
        assert data["speakers"][0]["label"] == "A"

    def test_not_found(self, client):
        """Should return 404 for nonexistent project."""
        response = client.get(f"/api/projects/{uuid.uuid4()}")
        assert response.status_code == 404


class TestDeleteProject:
    """Tests for DELETE /api/projects/{id}."""

    def test_delete_existing(self, client, db, make_project):
        """Should delete the project and return 200."""
        project = make_project()
        response = client.delete(f"/api/projects/{project.id}")
        assert response.status_code == 200
        assert db.query(Project).count() == 0

    def test_delete_cascades_sentences(self, client, db, make_project, make_sentence):
        """Deleting a project should also delete its sentences."""
        project = make_project()
        make_sentence(project.id, idx=0)
        response = client.delete(f"/api/projects/{project.id}")
        assert response.status_code == 200
        assert db.query(Sentence).count() == 0

    def test_delete_not_found(self, client):
        """Should return 404 for nonexistent project."""
        response = client.delete(f"/api/projects/{uuid.uuid4()}")
        assert response.status_code == 404


class TestGetProjectStatus:
    """Tests for GET /api/projects/{id}/status."""

    def test_status_transcribing(self, client, make_project):
        """Should return correct status and progress for transcribing state."""
        project = make_project(status="transcribing")
        response = client.get(f"/api/projects/{project.id}/status")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "transcribing"
        assert data["progress"] == 30

    def test_status_ready(self, client, make_project):
        """Ready project should show 100% progress."""
        project = make_project(status="ready")
        response = client.get(f"/api/projects/{project.id}/status")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ready"
        assert data["progress"] == 100

    def test_status_not_found(self, client):
        """Should return 404 for nonexistent project."""
        response = client.get(f"/api/projects/{uuid.uuid4()}/status")
        assert response.status_code == 404


class TestSpeakerEndpoints:
    """Tests for speaker-related endpoints."""

    def test_get_speakers(self, client, make_project, make_speaker):
        """Should return all speakers for a project."""
        project = make_project()
        make_speaker(project.id, label="A", display_name="Jan")
        make_speaker(project.id, label="B", display_name="Piet")
        response = client.get(f"/api/projects/{project.id}/speakers")
        assert response.status_code == 200
        assert len(response.json()["speakers"]) == 2

    def test_get_speakers_not_found(self, client):
        """Should return 404 for nonexistent project."""
        response = client.get(f"/api/projects/{uuid.uuid4()}/speakers")
        assert response.status_code == 404

    def test_update_speaker_name(self, client, db, make_project, make_speaker):
        """Should update speaker display_name and set is_manual to True."""
        project = make_project()
        speaker = make_speaker(project.id, label="A")
        response = client.put(
            f"/api/projects/{project.id}/speakers/{speaker.id}",
            json={"name": "Jan de Vries"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["speaker"]["display_name"] == "Jan de Vries"
        assert data["speaker"]["is_manual"] is True

    def test_update_speaker_not_found(self, client, make_project):
        """Should return 404 for nonexistent speaker."""
        project = make_project()
        response = client.put(
            f"/api/projects/{project.id}/speakers/{uuid.uuid4()}",
            json={"name": "Nobody"},
        )
        assert response.status_code == 404


class TestExportProject:
    """Tests for GET /api/projects/{id}/export."""

    def test_export(self, client, make_project, make_sentence, make_keyword):
        """Should export project data as JSON with sentences and keywords."""
        project = make_project(name="Export Test", status="ready")
        sentence = make_sentence(project.id, idx=0, text="Hallo wereld")
        make_keyword(sentence.id, word="hallo")

        response = client.get(f"/api/projects/{project.id}/export")
        assert response.status_code == 200
        data = response.json()
        assert data["project"]["name"] == "Export Test"
        assert len(data["sentences"]) == 1
        assert len(data["sentences"][0]["keywords"]) == 1
        assert data["sentences"][0]["keywords"][0]["word"] == "hallo"

    def test_export_has_version(self, client, make_project):
        """Export response should include version metadata."""
        project = make_project(name="V Test", status="ready")
        response = client.get(f"/api/projects/{project.id}/export")
        assert response.status_code == 200
        data = response.json()
        assert data["version"] == "1.0"
        assert "exported_at" in data

    def test_export_not_found(self, client):
        """Should return 404 for nonexistent project."""
        response = client.get(f"/api/projects/{uuid.uuid4()}/export")
        assert response.status_code == 404

    def test_export_content_disposition(self, client, make_project):
        """Response should have Content-Disposition header for download."""
        project = make_project(name="Download Test")
        response = client.get(f"/api/projects/{project.id}/export")
        assert response.status_code == 200
        assert "Content-Disposition" in response.headers
        assert "attachment" in response.headers["Content-Disposition"]
