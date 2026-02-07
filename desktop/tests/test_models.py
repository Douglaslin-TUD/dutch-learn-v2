# desktop/tests/test_models.py
"""Tests for ORM models: Project, Sentence, Keyword, Speaker."""

import json
import uuid

import pytest

from app.models import Project, Sentence, Keyword, Speaker


class TestProjectModel:
    """Tests for Project model properties and serialization."""

    def test_progress_pending(self, db, make_project):
        project = make_project(status="pending", total_sentences=0, processed_sentences=0)
        assert project.progress == 0

    def test_progress_extracting(self, db, make_project):
        project = make_project(status="extracting")
        assert project.progress == 10

    def test_progress_transcribing(self, db, make_project):
        project = make_project(status="transcribing")
        assert project.progress == 30

    def test_progress_explaining_partial(self, db, make_project):
        project = make_project(status="explaining", total_sentences=10, processed_sentences=5)
        # 50 + int(5/10 * 45) = 50 + 22 = 72
        assert project.progress == 72

    def test_progress_ready(self, db, make_project):
        project = make_project(status="ready")
        assert project.progress == 100

    def test_progress_error(self, db, make_project):
        project = make_project(status="error")
        assert project.progress == 0

    def test_current_stage_description(self, db, make_project):
        assert make_project(status="pending").current_stage_description == "Waiting to start..."
        assert make_project(status="extracting").current_stage_description == "Extracting audio from video..."
        assert make_project(status="transcribing").current_stage_description == "Transcribing audio to text..."
        assert "Generating explanations" in make_project(status="explaining").current_stage_description
        assert make_project(status="ready").current_stage_description == "Processing complete"
        assert "Error" in make_project(status="error").current_stage_description

    def test_to_dict_basic(self, db, make_project):
        project = make_project(name="My Project", status="ready")
        d = project.to_dict()
        assert d["name"] == "My Project"
        assert d["status"] == "ready"
        assert d["progress"] == 100
        assert "sentences" not in d
        assert "speakers" not in d

    def test_to_dict_with_sentences(self, db, make_project, make_sentence):
        project = make_project()
        make_sentence(project.id, idx=0, text="Zin een")
        db.refresh(project)
        d = project.to_dict(include_sentences=True)
        assert len(d["sentences"]) == 1
        assert d["sentences"][0]["text"] == "Zin een"

    def test_to_dict_with_speakers(self, db, make_project, make_speaker):
        project = make_project()
        make_speaker(project.id, label="A", display_name="Jan")
        db.refresh(project)
        d = project.to_dict(include_speakers=True)
        assert len(d["speakers"]) == 1
        assert d["speakers"][0]["label"] == "A"


class TestSentenceModel:
    """Tests for Sentence model properties and serialization."""

    def test_duration(self, db, make_project, make_sentence):
        project = make_project()
        sentence = make_sentence(project.id, start_time=1.0, end_time=3.5)
        assert sentence.duration == pytest.approx(2.5)

    def test_has_explanation_false(self, db, make_project, make_sentence):
        project = make_project()
        sentence = make_sentence(project.id)
        assert sentence.has_explanation is False

    def test_has_explanation_true(self, db, make_project):
        project = make_project()
        sentence = Sentence(
            id=str(uuid.uuid4()),
            project_id=project.id,
            idx=0,
            text="Test",
            start_time=0.0,
            end_time=1.0,
            explanation_nl="Nederlandse uitleg",
        )
        db.add(sentence)
        db.commit()
        assert sentence.has_explanation is True

    def test_to_dict_with_keywords(self, db, make_project, make_sentence, make_keyword):
        project = make_project()
        sentence = make_sentence(project.id, text="Hallo wereld")
        make_keyword(sentence.id, word="hallo")
        db.refresh(sentence)
        d = sentence.to_dict(include_keywords=True)
        assert d["text"] == "Hallo wereld"
        assert len(d["keywords"]) == 1
        assert d["keywords"][0]["word"] == "hallo"

    def test_to_dict_without_keywords(self, db, make_project, make_sentence):
        project = make_project()
        sentence = make_sentence(project.id)
        d = sentence.to_dict(include_keywords=False)
        assert "keywords" not in d

    def test_to_dict_with_speaker(self, db, make_project, make_speaker, make_sentence):
        project = make_project()
        speaker = make_speaker(project.id, label="B", display_name="Piet")
        sentence = make_sentence(project.id, speaker_id=speaker.id)
        db.refresh(sentence)
        d = sentence.to_dict()
        assert d["speaker"]["label"] == "B"
        assert d["speaker"]["display_name"] == "Piet"


class TestKeywordModel:
    """Tests for Keyword model serialization."""

    def test_to_dict(self, db, make_project, make_sentence, make_keyword):
        project = make_project()
        sentence = make_sentence(project.id)
        keyword = make_keyword(sentence.id, word="fiets", meaning_nl="tweewieler", meaning_en="bicycle")
        d = keyword.to_dict()
        assert d["word"] == "fiets"
        assert d["meaning_nl"] == "tweewieler"
        assert d["meaning_en"] == "bicycle"


class TestSpeakerModel:
    """Tests for Speaker model serialization."""

    def test_to_dict_with_display_name(self, db, make_project, make_speaker):
        project = make_project()
        speaker = make_speaker(project.id, label="A", display_name="Jan")
        d = speaker.to_dict()
        assert d["label"] == "A"
        assert d["display_name"] == "Jan"

    def test_to_dict_fallback_display_name(self, db, make_project, make_speaker):
        project = make_project()
        speaker = make_speaker(project.id, label="B", display_name=None)
        d = speaker.to_dict()
        assert d["display_name"] == "Speaker B"

    def test_to_dict_evidence_json(self, db, make_project):
        project = make_project()
        speaker = Speaker(
            id=str(uuid.uuid4()),
            project_id=project.id,
            label="A",
            evidence=json.dumps(["Hallo", "Goedemorgen"]),
        )
        db.add(speaker)
        db.commit()
        d = speaker.to_dict()
        assert d["evidence"] == ["Hallo", "Goedemorgen"]

    def test_to_dict_null_evidence(self, db, make_project, make_speaker):
        project = make_project()
        speaker = make_speaker(project.id, label="C")
        d = speaker.to_dict()
        assert d["evidence"] == []


class TestCascadeDeletes:
    """Tests for cascade delete behavior."""

    def test_delete_project_cascades_sentences(self, db, make_project, make_sentence):
        project = make_project()
        make_sentence(project.id, idx=0)
        make_sentence(project.id, idx=1)
        db.delete(project)
        db.commit()
        assert db.query(Sentence).count() == 0

    def test_delete_project_cascades_speakers(self, db, make_project, make_speaker):
        project = make_project()
        make_speaker(project.id, label="A")
        db.delete(project)
        db.commit()
        assert db.query(Speaker).count() == 0

    def test_delete_sentence_cascades_keywords(self, db, make_project, make_sentence, make_keyword):
        project = make_project()
        sentence = make_sentence(project.id)
        make_keyword(sentence.id)
        db.delete(sentence)
        db.commit()
        assert db.query(Keyword).count() == 0
