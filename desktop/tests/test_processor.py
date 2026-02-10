"""Tests for the Processor pipeline."""

import json

import pytest
from unittest.mock import AsyncMock, patch

from app.models import Project, Speaker
from app.services.processor import Processor
from app.services.speaker_identifier import SpeakerIdentification


# --- Helpers ---

def _make_processor_with_mock_identifier(mock_identify: AsyncMock) -> Processor:
    """Create a Processor with a mocked SpeakerIdentifier.identify method."""
    proc = Processor()
    proc._init_api_services()
    proc.speaker_identifier.identify = mock_identify
    return proc


# --- TestIdentifySpeakers ---

class TestIdentifySpeakers:
    """Tests for Processor._identify_speakers()."""

    @pytest.mark.asyncio
    async def test_calls_identifier_with_transcript(
        self, db, make_project, make_speaker, make_sentence
    ):
        """Verify _identify_speakers builds transcript and calls the identifier."""
        project = make_project(status="identifying")
        spk_a = make_speaker(project.id, label="A")
        spk_b = make_speaker(project.id, label="B")
        make_sentence(project.id, idx=0, text="Hallo, ik ben Jan.", speaker_id=spk_a.id)
        make_sentence(project.id, idx=1, text="Welkom Jan.", speaker_id=spk_b.id)

        mock_identify = AsyncMock(return_value={})
        proc = _make_processor_with_mock_identifier(mock_identify)

        await proc._identify_speakers(project, db)

        mock_identify.assert_called_once()
        transcript_arg, project_name_arg = mock_identify.call_args.args
        assert len(transcript_arg) == 2
        assert transcript_arg[0] == {"label": "A", "text": "Hallo, ik ben Jan."}
        assert transcript_arg[1] == {"label": "B", "text": "Welkom Jan."}
        assert project_name_arg == project.name

    @pytest.mark.asyncio
    async def test_updates_speaker_display_names(
        self, db, make_project, make_speaker, make_sentence
    ):
        """Verify speakers get display_name and evidence updated after identification."""
        project = make_project(status="identifying")
        spk_a = make_speaker(project.id, label="A")
        spk_b = make_speaker(project.id, label="B")
        make_sentence(project.id, idx=0, text="Ik ben Jan.", speaker_id=spk_a.id)
        make_sentence(project.id, idx=1, text="Dag Jan.", speaker_id=spk_b.id)

        mock_results = {
            "A": SpeakerIdentification(
                label="A", name="Jan de Vries", role="Developer",
                confidence="high", evidence="Said his name",
            ),
            "B": SpeakerIdentification(
                label="B", name="de presentator", role="Host",
                confidence="medium", evidence="Addressed Jan by name",
            ),
        }
        mock_identify = AsyncMock(return_value=mock_results)
        proc = _make_processor_with_mock_identifier(mock_identify)

        await proc._identify_speakers(project, db)

        # Refresh from DB to verify persistence
        db.refresh(spk_a)
        db.refresh(spk_b)

        assert spk_a.display_name == "Jan de Vries"
        evidence_a = json.loads(spk_a.evidence)
        assert evidence_a["role"] == "Developer"
        assert evidence_a["confidence"] == "high"
        assert evidence_a["reasoning"] == "Said his name"

        assert spk_b.display_name == "de presentator"
        evidence_b = json.loads(spk_b.evidence)
        assert evidence_b["role"] == "Host"
        assert evidence_b["confidence"] == "medium"

    @pytest.mark.asyncio
    async def test_non_blocking_on_failure(
        self, db, make_project, make_speaker, make_sentence
    ):
        """Verify pipeline continues if identification fails (exception is caught)."""
        project = make_project(status="identifying")
        spk = make_speaker(project.id, label="A")
        make_sentence(project.id, idx=0, text="Hallo.", speaker_id=spk.id)

        mock_identify = AsyncMock(side_effect=Exception("API timeout"))
        proc = _make_processor_with_mock_identifier(mock_identify)

        # Should NOT raise -- the exception is caught inside _identify_speakers
        await proc._identify_speakers(project, db)

        # Speaker should be unchanged
        db.refresh(spk)
        assert spk.display_name is None

    @pytest.mark.asyncio
    async def test_skips_when_no_speakers(self, db, make_project, make_sentence):
        """Verify _identify_speakers returns early when no speakers exist."""
        project = make_project(status="identifying")
        make_sentence(project.id, idx=0, text="Hallo wereld.")

        mock_identify = AsyncMock()
        proc = _make_processor_with_mock_identifier(mock_identify)

        await proc._identify_speakers(project, db)

        mock_identify.assert_not_called()

    @pytest.mark.asyncio
    async def test_skips_when_no_sentences(self, db, make_project, make_speaker):
        """Verify _identify_speakers returns early when no sentences exist."""
        project = make_project(status="identifying")
        make_speaker(project.id, label="A")

        mock_identify = AsyncMock()
        proc = _make_processor_with_mock_identifier(mock_identify)

        await proc._identify_speakers(project, db)

        mock_identify.assert_not_called()


# --- TestUpdateProjectStatus ---

class TestUpdateProjectStatus:
    """Tests for Processor._update_project_status()."""

    def test_updates_status(self, db, make_project):
        """Verify status change works."""
        project = make_project(status="pending")
        proc = Processor()

        proc._update_project_status(db, project.id, "extracting")

        db.refresh(project)
        assert project.status == "extracting"

    def test_sets_error_message(self, db, make_project):
        """Verify error message is set."""
        project = make_project(status="pending")
        proc = Processor()

        proc._update_project_status(
            db, project.id, "error", error_message="Something went wrong"
        )

        db.refresh(project)
        assert project.status == "error"
        assert project.error_message == "Something went wrong"

    def test_ignores_nonexistent_project(self, db):
        """Verify no crash for bad project ID."""
        proc = Processor()

        # Should not raise any exception
        proc._update_project_status(db, "nonexistent-uuid", "error")
