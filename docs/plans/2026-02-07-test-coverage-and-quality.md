# Test Coverage & Code Quality Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add critical-path unit tests to Desktop (Python) and Mobile (Flutter), plus fix code quality issues from `docs/validation/fix_required.md`.

**Architecture:**
- Desktop: pytest with in-memory SQLite, mock external APIs (OpenAI, AssemblyAI, Google Drive, FFmpeg)
- Mobile: flutter_test with mockito, test pure logic first then mocked dependencies
- Three parallel workstreams: Desktop tests (Tasks 1-8), Mobile tests (Tasks 9-16), Code quality (Tasks 17-19)

**Tech Stack:**
- Desktop: pytest, pytest-asyncio, pytest-cov, httpx (TestClient)
- Mobile: flutter_test, mockito, sqflite_common_ffi
- Target: ~50% coverage on critical business logic

---

## Workstream A: Desktop Tests (Tasks 1-8)

### Task 1: Set Up Desktop Test Infrastructure

**Files:**
- Create: `desktop/tests/conftest.py`
- Create: `desktop/tests/__init__.py`
- Create: `desktop/pytest.ini`
- Modify: `desktop/requirements.txt`

**Step 1: Add test dependencies to requirements.txt**

Append to `desktop/requirements.txt`:

```
# Testing
pytest>=7.4.0
pytest-asyncio>=0.21.0
pytest-cov>=4.1.0
```

**Step 2: Create pytest.ini**

```ini
# desktop/pytest.ini
[pytest]
testpaths = tests
asyncio_mode = auto
```

**Step 3: Create tests/__init__.py**

```python
# desktop/tests/__init__.py
```

**Step 4: Create conftest.py with DB fixtures**

```python
# desktop/tests/conftest.py
"""Shared test fixtures for Desktop backend tests."""

import uuid
from datetime import datetime
from contextlib import contextmanager

import pytest
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker, Session
from fastapi.testclient import TestClient

from app.database import Base, get_db
from app.main import app
from app.models import Project, Sentence, Keyword, Speaker


# --- Database Fixtures ---

TEST_DATABASE_URL = "sqlite:///:memory:"

@pytest.fixture
def db_engine():
    """Create a fresh in-memory SQLite engine per test."""
    engine = create_engine(
        TEST_DATABASE_URL,
        connect_args={"check_same_thread": False},
    )

    @event.listens_for(engine, "connect")
    def set_sqlite_pragma(dbapi_connection, connection_record):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    Base.metadata.create_all(bind=engine)
    yield engine
    Base.metadata.drop_all(bind=engine)
    engine.dispose()


@pytest.fixture
def db(db_engine):
    """Provide a clean DB session per test."""
    SessionLocal = sessionmaker(bind=db_engine)
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture
def client(db):
    """FastAPI TestClient with DB dependency override."""
    def override_get_db():
        yield db

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


# --- Factory Fixtures ---

@pytest.fixture
def make_project(db):
    """Factory to create and persist a Project."""
    def _make(
        name="Test Project",
        status="ready",
        total_sentences=10,
        processed_sentences=10,
        original_file="test.mp3",
        audio_file="test_audio.mp3",
    ):
        project = Project(
            id=str(uuid.uuid4()),
            name=name,
            status=status,
            total_sentences=total_sentences,
            processed_sentences=processed_sentences,
            original_file=original_file,
            audio_file=audio_file,
        )
        db.add(project)
        db.commit()
        db.refresh(project)
        return project
    return _make


@pytest.fixture
def make_sentence(db):
    """Factory to create and persist a Sentence."""
    def _make(project_id, idx=0, text="Hallo wereld", start_time=0.0, end_time=2.5, speaker_id=None):
        sentence = Sentence(
            id=str(uuid.uuid4()),
            project_id=project_id,
            idx=idx,
            text=text,
            start_time=start_time,
            end_time=end_time,
            speaker_id=speaker_id,
        )
        db.add(sentence)
        db.commit()
        db.refresh(sentence)
        return sentence
    return _make


@pytest.fixture
def make_keyword(db):
    """Factory to create and persist a Keyword."""
    def _make(sentence_id, word="hallo", meaning_nl="begroeting", meaning_en="hello"):
        keyword = Keyword(
            id=str(uuid.uuid4()),
            sentence_id=sentence_id,
            word=word,
            meaning_nl=meaning_nl,
            meaning_en=meaning_en,
        )
        db.add(keyword)
        db.commit()
        db.refresh(keyword)
        return keyword
    return _make


@pytest.fixture
def make_speaker(db):
    """Factory to create and persist a Speaker."""
    def _make(project_id, label="A", display_name=None):
        speaker = Speaker(
            id=str(uuid.uuid4()),
            project_id=project_id,
            label=label,
            display_name=display_name,
        )
        db.add(speaker)
        db.commit()
        db.refresh(speaker)
        return speaker
    return _make
```

**Step 5: Install dependencies and verify**

Run: `cd desktop && pip install pytest pytest-asyncio pytest-cov`
Run: `cd desktop && python -m pytest --collect-only`
Expected: "no tests ran" (0 collected)

**Step 6: Commit**

```bash
git add desktop/tests/ desktop/pytest.ini desktop/requirements.txt
git commit -m "test: add Desktop pytest infrastructure and fixtures"
```

---

### Task 2: Test Models (Project, Sentence, Keyword, Speaker)

**Files:**
- Create: `desktop/tests/test_models.py`

**Step 1: Write model tests**

```python
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
        # 50 + (5/10) * 45 = 72
        assert project.progress == 72

    def test_progress_ready(self, db, make_project):
        project = make_project(status="ready")
        assert project.progress == 100

    def test_progress_error(self, db, make_project):
        project = make_project(status="error")
        assert project.progress == 0

    def test_current_stage_description(self, db, make_project):
        assert make_project(status="pending").current_stage_description == "Waiting to start"
        assert make_project(status="extracting").current_stage_description == "Extracting audio"
        assert make_project(status="transcribing").current_stage_description == "Transcribing audio"
        assert make_project(status="explaining").current_stage_description == "Generating explanations"
        assert make_project(status="ready").current_stage_description == "Ready"
        assert make_project(status="error").current_stage_description == "Error occurred"

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
```

**Step 2: Run tests**

Run: `cd desktop && python -m pytest tests/test_models.py -v`
Expected: All PASS

**Step 3: Commit**

```bash
git add desktop/tests/test_models.py
git commit -m "test: add model unit tests (Project, Sentence, Keyword, Speaker)"
```

---

### Task 3: Test File Utils

**Files:**
- Create: `desktop/tests/test_file_utils.py`

**Step 1: Write file utils tests**

```python
# desktop/tests/test_file_utils.py
"""Tests for desktop/app/utils/file_utils.py."""

import pytest
from pathlib import Path
from unittest.mock import patch

from app.utils.file_utils import (
    get_file_extension,
    validate_file_extension,
    validate_file_size,
    is_video_file,
    is_audio_file,
    generate_unique_filename,
    get_audio_filename,
    cleanup_file,
    ensure_file_exists,
)


class TestGetFileExtension:

    def test_mp3(self):
        assert get_file_extension("song.mp3") == ".mp3"

    def test_uppercase(self):
        assert get_file_extension("VIDEO.MKV") == ".mkv"

    def test_no_extension(self):
        assert get_file_extension("noext") == ""

    def test_double_extension(self):
        assert get_file_extension("archive.tar.gz") == ".gz"


class TestValidateFileExtension:

    def test_valid_audio(self):
        assert validate_file_extension("track.mp3") is True
        assert validate_file_extension("track.wav") is True
        assert validate_file_extension("track.m4a") is True
        assert validate_file_extension("track.flac") is True

    def test_valid_video(self):
        assert validate_file_extension("clip.mp4") is True
        assert validate_file_extension("clip.mkv") is True
        assert validate_file_extension("clip.avi") is True
        assert validate_file_extension("clip.webm") is True
        assert validate_file_extension("clip.mov") is True

    def test_invalid(self):
        assert validate_file_extension("doc.pdf") is False
        assert validate_file_extension("img.jpg") is False

    def test_case_insensitive(self):
        assert validate_file_extension("track.MP3") is True


class TestValidateFileSize:

    def test_within_limit(self):
        assert validate_file_size(1000) is True

    def test_at_limit(self):
        assert validate_file_size(524288000) is True

    def test_over_limit(self):
        assert validate_file_size(524288001) is False

    def test_zero(self):
        assert validate_file_size(0) is True


class TestIsVideoAudio:

    def test_is_video(self):
        assert is_video_file("clip.mp4") is True
        assert is_video_file("clip.mkv") is True
        assert is_video_file("track.mp3") is False

    def test_is_audio(self):
        assert is_audio_file("track.mp3") is True
        assert is_audio_file("track.flac") is True
        assert is_audio_file("clip.mp4") is False


class TestGenerateUniqueFilename:

    def test_preserves_extension(self):
        result = generate_unique_filename("song.mp3")
        assert result.endswith(".mp3")

    def test_unique(self):
        a = generate_unique_filename("song.mp3")
        b = generate_unique_filename("song.mp3")
        assert a != b

    def test_with_prefix(self):
        result = generate_unique_filename("song.mp3", prefix="audio")
        assert result.startswith("audio_")


class TestGetAudioFilename:

    def test_format(self):
        result = get_audio_filename("abc-123")
        assert result == "abc-123.mp3"


class TestCleanupFile:

    def test_cleanup_existing(self, tmp_path):
        f = tmp_path / "temp.txt"
        f.write_text("data")
        assert cleanup_file(f) is True
        assert not f.exists()

    def test_cleanup_nonexistent(self, tmp_path):
        f = tmp_path / "missing.txt"
        assert cleanup_file(f) is False


class TestEnsureFileExists:

    def test_exists(self, tmp_path):
        f = tmp_path / "real.txt"
        f.write_text("data")
        assert ensure_file_exists(f) is True

    def test_not_exists(self, tmp_path):
        f = tmp_path / "missing.txt"
        assert ensure_file_exists(f) is False
```

**Step 2: Run tests**

Run: `cd desktop && python -m pytest tests/test_file_utils.py -v`
Expected: All PASS

**Step 3: Commit**

```bash
git add desktop/tests/test_file_utils.py
git commit -m "test: add file utils unit tests"
```

---

### Task 4: Test ProgressMerger

**Files:**
- Create: `desktop/tests/test_progress_merger.py`

**Step 1: Write progress merger tests**

```python
# desktop/tests/test_progress_merger.py
"""Tests for desktop/app/services/progress_merger.py."""

import json
import pytest
from pathlib import Path

from app.services.progress_merger import ProgressMerger, merge_progress_files


class TestProgressMerger:

    @pytest.fixture
    def merger(self):
        return ProgressMerger()

    def test_merge_prefers_higher_learn_count(self, merger):
        local = {
            "project": {"id": "p1", "name": "Test"},
            "sentences": [
                {"id": "s1", "text": "Hallo", "learn_count": 3},
            ],
            "keywords": [],
            "progress": {},
        }
        remote = {
            "project": {"id": "p1", "name": "Test"},
            "sentences": [
                {"id": "s1", "text": "Hallo", "learn_count": 5},
            ],
            "keywords": [],
            "progress": {},
        }
        result = merger.merge(local, remote)
        assert result["sentences"][0]["learn_count"] == 5

    def test_merge_local_wins_when_higher(self, merger):
        local = {
            "project": {"id": "p1", "name": "Test"},
            "sentences": [
                {"id": "s1", "text": "Hallo", "learn_count": 7},
            ],
            "keywords": [],
            "progress": {},
        }
        remote = {
            "project": {"id": "p1", "name": "Test"},
            "sentences": [
                {"id": "s1", "text": "Hallo", "learn_count": 2},
            ],
            "keywords": [],
            "progress": {},
        }
        result = merger.merge(local, remote)
        assert result["sentences"][0]["learn_count"] == 7

    def test_merge_keeps_local_only_sentences(self, merger):
        local = {
            "project": {"id": "p1", "name": "Test"},
            "sentences": [
                {"id": "s1", "text": "Local only", "learn_count": 1},
            ],
            "keywords": [],
            "progress": {},
        }
        remote = {
            "project": {"id": "p1", "name": "Test"},
            "sentences": [],
            "keywords": [],
            "progress": {},
        }
        result = merger.merge(local, remote)
        assert len(result["sentences"]) == 1

    def test_merge_keywords_prefers_local(self, merger):
        local = {
            "project": {"id": "p1", "name": "Test"},
            "sentences": [],
            "keywords": [{"id": "k1", "word": "fiets", "meaning_en": "bicycle (local)"}],
            "progress": {},
        }
        remote = {
            "project": {"id": "p1", "name": "Test"},
            "sentences": [],
            "keywords": [{"id": "k1", "word": "fiets", "meaning_en": "bicycle (remote)"}],
            "progress": {},
        }
        result = merger.merge(local, remote)
        assert result["keywords"][0]["meaning_en"] == "bicycle (local)"

    def test_merge_progress_earliest_timestamp(self, merger):
        local = {
            "project": {"id": "p1", "name": "Test"},
            "sentences": [],
            "keywords": [],
            "progress": {"started_at": "2026-01-15T10:00:00"},
        }
        remote = {
            "project": {"id": "p1", "name": "Test"},
            "sentences": [],
            "keywords": [],
            "progress": {"started_at": "2026-01-10T08:00:00"},
        }
        result = merger.merge(local, remote)
        assert result["progress"]["started_at"] == "2026-01-10T08:00:00"

    def test_parse_timestamp_invalid(self, merger):
        assert merger._parse_timestamp("not-a-date") is None

    def test_earliest_timestamp_one_none(self, merger):
        assert merger._earliest_timestamp("2026-01-15T10:00:00", None) == "2026-01-15T10:00:00"
        assert merger._earliest_timestamp(None, "2026-01-15T10:00:00") == "2026-01-15T10:00:00"

    def test_earliest_timestamp_both_none(self, merger):
        assert merger._earliest_timestamp(None, None) is None


class TestMergeProgressFiles:

    def test_round_trip(self, tmp_path):
        local_data = {
            "project": {"id": "p1", "name": "Test"},
            "sentences": [{"id": "s1", "text": "Hallo", "learn_count": 3}],
            "keywords": [],
            "progress": {},
        }
        remote_data = {
            "project": {"id": "p1", "name": "Test"},
            "sentences": [{"id": "s1", "text": "Hallo", "learn_count": 5}],
            "keywords": [],
            "progress": {},
        }

        local_path = tmp_path / "local.json"
        remote_path = tmp_path / "remote.json"
        output_path = tmp_path / "merged.json"

        local_path.write_text(json.dumps(local_data))
        remote_path.write_text(json.dumps(remote_data))

        result = merge_progress_files(str(local_path), str(remote_path), str(output_path))
        assert result["sentences"][0]["learn_count"] == 5
        assert output_path.exists()
```

**Step 2: Run tests**

Run: `cd desktop && python -m pytest tests/test_progress_merger.py -v`
Expected: All PASS

**Step 3: Commit**

```bash
git add desktop/tests/test_progress_merger.py
git commit -m "test: add ProgressMerger unit tests"
```

---

### Task 5: Test ConfigEncryptor

**Files:**
- Create: `desktop/tests/test_config_encryptor.py`

**Step 1: Write config encryptor tests**

```python
# desktop/tests/test_config_encryptor.py
"""Tests for desktop/app/services/config_encryptor.py."""

import json
import pytest
from pathlib import Path
from unittest.mock import patch

from app.services.config_encryptor import (
    ConfigEncryptor,
    ConfigEncryptionError,
    generate_transfer_password,
    export_config_for_mobile,
    import_config_from_mobile,
)


class TestConfigEncryptor:

    def test_encrypt_decrypt_round_trip(self):
        password = "test-password-123"
        encryptor = ConfigEncryptor(password)
        config = {"api_key": "sk-test-12345", "model": "gpt-4o-mini"}

        encrypted = encryptor.encrypt_config(config)
        assert isinstance(encrypted, str)
        assert "sk-test-12345" not in encrypted

        decrypted = encryptor.decrypt_config(encrypted)
        assert decrypted == config

    def test_wrong_password_fails(self):
        encryptor1 = ConfigEncryptor("correct-password")
        encryptor2 = ConfigEncryptor("wrong-password")

        encrypted = encryptor1.encrypt_config({"key": "value"})

        with pytest.raises(ConfigEncryptionError):
            encryptor2.decrypt_config(encrypted)

    def test_custom_salt(self):
        salt = b"custom_salt_bytes"
        encryptor = ConfigEncryptor("password", salt=salt)
        config = {"key": "value"}
        encrypted = encryptor.encrypt_config(config)
        decrypted = encryptor.decrypt_config(encrypted)
        assert decrypted == config

    def test_empty_config(self):
        encryptor = ConfigEncryptor("password")
        encrypted = encryptor.encrypt_config({})
        decrypted = encryptor.decrypt_config(encrypted)
        assert decrypted == {}


class TestGenerateTransferPassword:

    def test_length(self):
        password = generate_transfer_password()
        assert len(password) == 16

    def test_uniqueness(self):
        a = generate_transfer_password()
        b = generate_transfer_password()
        assert a != b


class TestExportImportConfig:

    @patch("app.services.config_encryptor.settings")
    def test_export_import_round_trip(self, mock_settings, tmp_path):
        mock_settings.openai_api_key = "sk-test-key"
        mock_settings.assemblyai_api_key = "aai-test-key"
        mock_settings.gpt_model = "gpt-4o-mini"
        mock_settings.whisper_model = "whisper-1"

        output_path = tmp_path / "config.enc"
        password = "test-password"

        result = export_config_for_mobile(password, output_path=output_path)
        assert result["success"] is True
        assert output_path.exists()

        imported = import_config_from_mobile(output_path, password)
        assert imported["openai_api_key"] == "sk-test-key"
```

**Step 2: Run tests**

Run: `cd desktop && python -m pytest tests/test_config_encryptor.py -v`
Expected: All PASS

**Step 3: Commit**

```bash
git add desktop/tests/test_config_encryptor.py
git commit -m "test: add ConfigEncryptor unit tests"
```

---

### Task 6: Test Audio Router Utilities

**Files:**
- Create: `desktop/tests/test_audio_utils.py`

**Step 1: Write audio utility tests**

```python
# desktop/tests/test_audio_utils.py
"""Tests for audio router utility functions (desktop/app/routers/audio.py)."""

import pytest

from app.routers.audio import get_content_type, parse_range_header


class TestGetContentType:

    def test_mp3(self):
        assert get_content_type("audio.mp3") == "audio/mpeg"

    def test_wav(self):
        assert get_content_type("audio.wav") == "audio/wav"

    def test_m4a(self):
        assert get_content_type("audio.m4a") == "audio/mp4"

    def test_flac(self):
        assert get_content_type("audio.flac") == "audio/flac"

    def test_unknown_defaults_to_octet(self):
        assert get_content_type("file.xyz") == "application/octet-stream"


class TestParseRangeHeader:

    def test_valid_range(self):
        start, end = parse_range_header("bytes=0-999", 5000)
        assert start == 0
        assert end == 999

    def test_open_ended_range(self):
        start, end = parse_range_header("bytes=1000-", 5000)
        assert start == 1000
        assert end == 4999

    def test_suffix_range(self):
        start, end = parse_range_header("bytes=-500", 5000)
        assert start == 4500
        assert end == 4999

    def test_invalid_range_raises(self):
        with pytest.raises(Exception):
            parse_range_header("bytes=5000-6000", 5000)
```

**Step 2: Run tests**

Run: `cd desktop && python -m pytest tests/test_audio_utils.py -v`
Expected: All PASS

**Step 3: Commit**

```bash
git add desktop/tests/test_audio_utils.py
git commit -m "test: add audio router utility tests"
```

---

### Task 7: Test Projects Router (API Integration)

**Files:**
- Create: `desktop/tests/test_projects_api.py`

**Step 1: Write projects API tests**

```python
# desktop/tests/test_projects_api.py
"""Integration tests for /api/projects endpoints."""

import json
import uuid

import pytest

from app.models import Project, Sentence, Keyword, Speaker


class TestListProjects:

    def test_empty_list(self, client):
        response = client.get("/api/projects")
        assert response.status_code == 200
        assert response.json()["projects"] == []

    def test_returns_projects(self, client, make_project):
        make_project(name="Project A")
        make_project(name="Project B")
        response = client.get("/api/projects")
        assert response.status_code == 200
        assert len(response.json()["projects"]) == 2


class TestGetProject:

    def test_found(self, client, make_project, make_sentence):
        project = make_project(name="Test")
        make_sentence(project.id, idx=0, text="Hallo")
        response = client.get(f"/api/projects/{project.id}")
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "Test"
        assert len(data["sentences"]) == 1

    def test_not_found(self, client):
        response = client.get(f"/api/projects/{uuid.uuid4()}")
        assert response.status_code == 404


class TestDeleteProject:

    def test_delete_existing(self, client, db, make_project):
        project = make_project()
        response = client.delete(f"/api/projects/{project.id}")
        assert response.status_code == 200
        assert db.query(Project).count() == 0

    def test_delete_not_found(self, client):
        response = client.delete(f"/api/projects/{uuid.uuid4()}")
        assert response.status_code == 404


class TestGetProjectStatus:

    def test_status(self, client, make_project):
        project = make_project(status="transcribing")
        response = client.get(f"/api/projects/{project.id}/status")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "transcribing"
        assert data["progress"] == 30

    def test_status_not_found(self, client):
        response = client.get(f"/api/projects/{uuid.uuid4()}/status")
        assert response.status_code == 404


class TestSpeakerEndpoints:

    def test_get_speakers(self, client, make_project, make_speaker):
        project = make_project()
        make_speaker(project.id, label="A", display_name="Jan")
        make_speaker(project.id, label="B", display_name="Piet")
        response = client.get(f"/api/projects/{project.id}/speakers")
        assert response.status_code == 200
        assert len(response.json()["speakers"]) == 2

    def test_update_speaker_name(self, client, db, make_project, make_speaker):
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
        project = make_project()
        response = client.put(
            f"/api/projects/{project.id}/speakers/{uuid.uuid4()}",
            json={"name": "Nobody"},
        )
        assert response.status_code == 404


class TestExportProject:

    def test_export(self, client, make_project, make_sentence, make_keyword):
        project = make_project(name="Export Test", status="ready")
        sentence = make_sentence(project.id, idx=0, text="Hallo wereld")
        make_keyword(sentence.id, word="hallo")

        response = client.get(f"/api/projects/{project.id}/export")
        assert response.status_code == 200
        data = response.json()
        assert data["project"]["name"] == "Export Test"
        assert len(data["sentences"]) == 1
        assert len(data["sentences"][0]["keywords"]) == 1

    def test_export_not_ready(self, client, make_project):
        project = make_project(status="transcribing")
        response = client.get(f"/api/projects/{project.id}/export")
        assert response.status_code == 400
```

**Step 2: Run tests**

Run: `cd desktop && python -m pytest tests/test_projects_api.py -v`
Expected: All PASS

**Step 3: Commit**

```bash
git add desktop/tests/test_projects_api.py
git commit -m "test: add projects API integration tests"
```

---

### Task 8: Run Full Desktop Suite with Coverage

**Step 1: Run all tests with coverage**

Run: `cd desktop && python -m pytest tests/ -v --tb=short --cov=app --cov-report=term-missing`
Expected: All tests PASS, coverage report printed

**Step 2: Commit any fixes if needed**

---

## Workstream B: Mobile Tests (Tasks 9-16)

### Task 9: Set Up Mobile Test Fixtures

**Files:**
- Create: `mobile/test/fixtures/test_data.dart`

**Step 1: Create shared test data factory**

```dart
// mobile/test/fixtures/test_data.dart
/// Shared test data factories for unit tests.

import 'package:dutch_learn_app/domain/entities/project.dart';
import 'package:dutch_learn_app/domain/entities/sentence.dart';
import 'package:dutch_learn_app/domain/entities/keyword.dart';
import 'package:dutch_learn_app/domain/entities/drive_file.dart';

class TestData {
  static Project project({
    String id = 'test-project-id',
    String? sourceId,
    String name = 'Test Project',
    int totalSentences = 10,
    String? audioPath,
    DateTime? importedAt,
    DateTime? lastPlayedAt,
    int lastSentenceIndex = 0,
  }) {
    return Project(
      id: id,
      sourceId: sourceId,
      name: name,
      totalSentences: totalSentences,
      audioPath: audioPath,
      importedAt: importedAt ?? DateTime(2026, 1, 15),
      lastPlayedAt: lastPlayedAt,
      lastSentenceIndex: lastSentenceIndex,
    );
  }

  static Keyword keyword({
    String id = 'kw-1',
    String sentenceId = 'sent-1',
    String word = 'fiets',
    String meaningNl = 'tweewieler',
    String meaningEn = 'bicycle',
  }) {
    return Keyword(
      id: id,
      sentenceId: sentenceId,
      word: word,
      meaningNl: meaningNl,
      meaningEn: meaningEn,
    );
  }

  static Sentence sentence({
    String id = 'sent-1',
    String projectId = 'test-project-id',
    int index = 0,
    String text = 'Hallo, hoe gaat het?',
    double startTime = 0.0,
    double endTime = 2.5,
    String? translationEn = 'Hello, how are you?',
    String? explanationNl,
    String? explanationEn,
    List<Keyword>? keywords,
  }) {
    return Sentence(
      id: id,
      projectId: projectId,
      index: index,
      text: text,
      startTime: startTime,
      endTime: endTime,
      translationEn: translationEn,
      explanationNl: explanationNl,
      explanationEn: explanationEn,
      keywords: keywords ?? [],
    );
  }

  static DriveFile driveFile({
    String id = 'drive-file-1',
    String name = 'project.json',
    String mimeType = 'application/json',
    int? size = 1024,
    bool isFolder = false,
  }) {
    return DriveFile(
      id: id,
      name: name,
      mimeType: mimeType,
      size: size,
      isFolder: isFolder,
    );
  }

  /// Standard import JSON matching v1.0 schema.
  static Map<String, dynamic> importJson({
    String projectId = 'source-project-id',
    String projectName = 'Import Test',
    int sentenceCount = 2,
  }) {
    return {
      'version': '1.0',
      'exported_at': '2026-01-15T10:00:00',
      'project': {
        'id': projectId,
        'name': projectName,
        'status': 'ready',
        'total_sentences': sentenceCount,
        'created_at': '2026-01-15T10:00:00',
      },
      'sentences': List.generate(sentenceCount, (i) => {
        return {
          'index': i,
          'text': 'Zin ${i + 1}',
          'start_time': i * 2.0,
          'end_time': (i + 1) * 2.0,
          'translation_en': 'Sentence ${i + 1}',
          'explanation_nl': null,
          'explanation_en': null,
          'keywords': [
            {
              'word': 'woord$i',
              'meaning_nl': 'betekenis $i',
              'meaning_en': 'meaning $i',
            }
          ],
        };
      }),
    };
  }
}
```

**Step 2: Verify compilation**

Run: `cd mobile && flutter test test/fixtures/test_data.dart --no-test`
(This will fail since it's not a test file — just verify no compile errors by importing it in an actual test in the next task.)

**Step 3: Commit**

```bash
git add mobile/test/fixtures/test_data.dart
git commit -m "test: add shared Mobile test fixtures"
```

---

### Task 10: Test DriveFile Entity

**Files:**
- Create: `mobile/test/domain/entities/drive_file_test.dart`

**Step 1: Write DriveFile tests**

```dart
// mobile/test/domain/entities/drive_file_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dutch_learn_app/domain/entities/drive_file.dart';
import '../../fixtures/test_data.dart';

void main() {
  group('DriveFile Entity', () {
    test('isJson detects JSON files', () {
      final file = TestData.driveFile(name: 'data.json', mimeType: 'application/json');
      expect(file.isJson, isTrue);
      expect(file.isMp3, isFalse);
    });

    test('isMp3 detects MP3 files', () {
      final file = TestData.driveFile(name: 'audio.mp3', mimeType: 'audio/mpeg');
      expect(file.isMp3, isTrue);
      expect(file.isJson, isFalse);
    });

    test('extension extracts correctly', () {
      expect(TestData.driveFile(name: 'file.json').extension, '.json');
      expect(TestData.driveFile(name: 'audio.mp3').extension, '.mp3');
      expect(TestData.driveFile(name: 'noext').extension, '');
    });

    test('nameWithoutExtension strips extension', () {
      expect(TestData.driveFile(name: 'project.json').nameWithoutExtension, 'project');
      expect(TestData.driveFile(name: 'noext').nameWithoutExtension, 'noext');
    });

    test('formattedSize formats bytes', () {
      expect(TestData.driveFile(size: 500).formattedSize, contains('B'));
      expect(TestData.driveFile(size: 1024).formattedSize, contains('KB'));
      expect(TestData.driveFile(size: 1048576).formattedSize, contains('MB'));
      expect(TestData.driveFile(size: null).formattedSize, 'Unknown size');
    });

    test('isFolder returns folder state', () {
      expect(TestData.driveFile(isFolder: true).isFolder, isTrue);
      expect(TestData.driveFile(isFolder: false).isFolder, isFalse);
    });

    test('equality by id', () {
      final a = TestData.driveFile(id: 'same');
      final b = TestData.driveFile(id: 'same');
      expect(a, equals(b));
    });
  });
}
```

**Step 2: Run test**

Run: `cd mobile && flutter test test/domain/entities/drive_file_test.dart`
Expected: All PASS

**Step 3: Commit**

```bash
git add mobile/test/domain/entities/drive_file_test.dart
git commit -m "test: add DriveFile entity tests"
```

---

### Task 11: Test SentenceModel and KeywordModel

**Files:**
- Create: `mobile/test/data/models/sentence_model_test.dart`
- Create: `mobile/test/data/models/keyword_model_test.dart`

**Step 1: Write SentenceModel tests**

```dart
// mobile/test/data/models/sentence_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dutch_learn_app/data/models/sentence_model.dart';
import 'package:dutch_learn_app/domain/entities/keyword.dart';

void main() {
  group('SentenceModel', () {
    final testMap = {
      'id': 'sent-1',
      'project_id': 'proj-1',
      'idx': 0,
      'text': 'Hallo wereld',
      'start_time': 0.0,
      'end_time': 2.5,
      'translation_en': 'Hello world',
      'explanation_nl': null,
      'explanation_en': null,
    };

    test('fromMap creates model from DB row', () {
      final model = SentenceModel.fromMap(testMap);
      expect(model.id, 'sent-1');
      expect(model.projectId, 'proj-1');
      expect(model.index, 0);
      expect(model.text, 'Hallo wereld');
      expect(model.startTime, 0.0);
      expect(model.endTime, 2.5);
      expect(model.translationEn, 'Hello world');
    });

    test('toMap creates DB-compatible map', () {
      final model = SentenceModel.fromMap(testMap);
      final map = model.toMap();
      expect(map['id'], 'sent-1');
      expect(map['project_id'], 'proj-1');
      expect(map['idx'], 0);
    });

    test('fromJson creates model from import JSON', () {
      final json = {
        'index': 0,
        'text': 'Test zin',
        'start_time': 1.0,
        'end_time': 3.0,
        'translation_en': 'Test sentence',
        'explanation_nl': null,
        'explanation_en': null,
        'keywords': [],
      };
      final model = SentenceModel.fromJson(json, id: 'new-id', projectId: 'proj-1');
      expect(model.id, 'new-id');
      expect(model.projectId, 'proj-1');
      expect(model.text, 'Test zin');
    });

    test('fromEntity round trips correctly', () {
      final model = SentenceModel.fromMap(testMap);
      final entity = model.toEntity();
      final backToModel = SentenceModel.fromEntity(entity);
      expect(backToModel.id, model.id);
      expect(backToModel.text, model.text);
    });

    test('withKeywords attaches keywords', () {
      final model = SentenceModel.fromMap(testMap);
      expect(model.keywords, isEmpty);
      final withKw = model.withKeywords([
        const Keyword(id: 'k1', sentenceId: 'sent-1', word: 'hallo', meaningNl: 'begroeting', meaningEn: 'hello'),
      ]);
      expect(withKw.keywords.length, 1);
      expect(withKw.keywords[0].word, 'hallo');
    });

    test('handles null optional fields', () {
      final minMap = {
        'id': 'sent-2',
        'project_id': 'proj-1',
        'idx': 1,
        'text': 'Tekst',
        'start_time': 0.0,
        'end_time': 1.0,
        'translation_en': null,
        'explanation_nl': null,
        'explanation_en': null,
      };
      final model = SentenceModel.fromMap(minMap);
      expect(model.translationEn, isNull);
      expect(model.hasTranslation, isFalse);
    });
  });
}
```

**Step 2: Write KeywordModel tests**

```dart
// mobile/test/data/models/keyword_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dutch_learn_app/data/models/keyword_model.dart';

void main() {
  group('KeywordModel', () {
    final testMap = {
      'id': 'kw-1',
      'sentence_id': 'sent-1',
      'word': 'fiets',
      'meaning_nl': 'tweewieler',
      'meaning_en': 'bicycle',
    };

    test('fromMap creates model from DB row', () {
      final model = KeywordModel.fromMap(testMap);
      expect(model.id, 'kw-1');
      expect(model.word, 'fiets');
      expect(model.meaningNl, 'tweewieler');
      expect(model.meaningEn, 'bicycle');
    });

    test('toMap creates DB-compatible map', () {
      final model = KeywordModel.fromMap(testMap);
      final map = model.toMap();
      expect(map['word'], 'fiets');
      expect(map['sentence_id'], 'sent-1');
    });

    test('fromJson creates model from import JSON', () {
      final json = {
        'word': 'huis',
        'meaning_nl': 'gebouw om in te wonen',
        'meaning_en': 'house',
      };
      final model = KeywordModel.fromJson(json, id: 'new-id', sentenceId: 'sent-1');
      expect(model.id, 'new-id');
      expect(model.word, 'huis');
    });

    test('fromEntity round trips correctly', () {
      final model = KeywordModel.fromMap(testMap);
      final entity = model.toEntity();
      final backToModel = KeywordModel.fromEntity(entity);
      expect(backToModel.word, model.word);
      expect(backToModel.meaningEn, model.meaningEn);
    });
  });
}
```

**Step 3: Run tests**

Run: `cd mobile && flutter test test/data/models/sentence_model_test.dart test/data/models/keyword_model_test.dart`
Expected: All PASS

**Step 4: Commit**

```bash
git add mobile/test/data/models/sentence_model_test.dart mobile/test/data/models/keyword_model_test.dart
git commit -m "test: add SentenceModel and KeywordModel tests"
```

---

### Task 12: Test Duration Extension

**Files:**
- Create: `mobile/test/core/extensions/duration_extension_test.dart`

**Step 1: Write duration extension tests**

```dart
// mobile/test/core/extensions/duration_extension_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dutch_learn_app/core/extensions/duration_extension.dart';

void main() {
  group('DurationExtension', () {
    test('formatted returns MM:SS', () {
      expect(const Duration(minutes: 2, seconds: 35).formatted, '02:35');
      expect(const Duration(seconds: 5).formatted, '00:05');
      expect(const Duration(minutes: 10).formatted, '10:00');
    });

    test('formattedWithHours for long durations', () {
      expect(const Duration(hours: 1, minutes: 5, seconds: 30).formattedWithHours, '1:05:30');
      expect(const Duration(minutes: 5, seconds: 30).formattedWithHours, '05:30');
    });

    test('compact format', () {
      expect(const Duration(minutes: 2, seconds: 35).compact, '2m 35s');
      expect(const Duration(seconds: 45).compact, '45s');
    });

    test('asSeconds returns double', () {
      expect(const Duration(seconds: 5, milliseconds: 500).asSeconds, 5.5);
    });

    test('fromSeconds creates Duration', () {
      final d = DurationExtension.fromSeconds(2.5);
      expect(d.inMilliseconds, 2500);
    });

    test('isWithin checks range', () {
      final d = const Duration(seconds: 5);
      expect(d.isWithin(const Duration(seconds: 3), const Duration(seconds: 7)), isTrue);
      expect(d.isWithin(const Duration(seconds: 6), const Duration(seconds: 8)), isFalse);
    });

    test('clamp restricts to range', () {
      final d = const Duration(seconds: 10);
      expect(d.clamp(const Duration(seconds: 0), const Duration(seconds: 5)), const Duration(seconds: 5));
      expect(d.clamp(const Duration(seconds: 0), const Duration(seconds: 15)), const Duration(seconds: 10));
    });

    test('percentOf calculates percentage', () {
      final part = const Duration(seconds: 30);
      final total = const Duration(seconds: 120);
      expect(part.percentOf(total), closeTo(0.25, 0.001));
    });

    test('multiply scales duration', () {
      final d = const Duration(seconds: 10);
      expect(d.multiply(1.5).inMilliseconds, 15000);
    });
  });

  group('DoubleToDuration', () {
    test('seconds extension', () {
      expect(2.5.seconds.inMilliseconds, 2500);
    });

    test('minutes extension', () {
      expect(1.5.minutes.inSeconds, 90);
    });
  });

  group('IntToDuration', () {
    test('seconds extension', () {
      expect(5.seconds, const Duration(seconds: 5));
    });

    test('minutes extension', () {
      expect(2.minutes, const Duration(minutes: 2));
    });
  });
}
```

**Step 2: Run test**

Run: `cd mobile && flutter test test/core/extensions/duration_extension_test.dart`
Expected: All PASS

**Step 3: Commit**

```bash
git add mobile/test/core/extensions/duration_extension_test.dart
git commit -m "test: add Duration extension tests"
```

---

### Task 13: Test String Extension

**Files:**
- Create: `mobile/test/core/extensions/string_extension_test.dart`

**Step 1: Write string extension tests**

```dart
// mobile/test/core/extensions/string_extension_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dutch_learn_app/core/extensions/string_extension.dart';

void main() {
  group('StringExtension', () {
    test('capitalize', () {
      expect('hello'.capitalize, 'Hello');
      expect(''.capitalize, '');
      expect('A'.capitalize, 'A');
    });

    test('titleCase', () {
      expect('hello world'.titleCase, 'Hello World');
    });

    test('truncate', () {
      expect('Hello World'.truncate(5), 'He...');
      expect('Hi'.truncate(10), 'Hi');
    });

    test('normalizeWhitespace', () {
      expect('  hello   world  '.normalizeWhitespace, 'hello world');
    });

    test('isNumeric', () {
      expect('123'.isNumeric, isTrue);
      expect('12.5'.isNumeric, isTrue);
      expect('abc'.isNumeric, isFalse);
    });

    test('isBlank and isNotBlank', () {
      expect(''.isBlank, isTrue);
      expect('  '.isBlank, isTrue);
      expect('hi'.isBlank, isFalse);
      expect('hi'.isNotBlank, isTrue);
    });

    test('nullIfBlank', () {
      expect(''.nullIfBlank, isNull);
      expect('  '.nullIfBlank, isNull);
      expect('hi'.nullIfBlank, 'hi');
    });

    test('snakeToCamel', () {
      expect('hello_world'.snakeToCamel, 'helloWorld');
    });

    test('camelToSnake', () {
      expect('helloWorld'.camelToSnake, 'hello_world');
    });

    test('words splits by whitespace', () {
      expect('hello world'.words, ['hello', 'world']);
    });

    test('containsIgnoreCase', () {
      expect('Hello World'.containsIgnoreCase('hello'), isTrue);
      expect('Hello World'.containsIgnoreCase('xyz'), isFalse);
    });

    test('removeDiacritics', () {
      expect('café'.removeDiacritics, 'cafe');
    });
  });

  group('NullableStringExtension', () {
    test('isNullOrEmpty', () {
      String? nullStr;
      expect(nullStr.isNullOrEmpty, isTrue);
      expect(''.isNullOrEmpty, isTrue);
      expect('hi'.isNullOrEmpty, isFalse);
    });

    test('isNullOrBlank', () {
      String? nullStr;
      expect(nullStr.isNullOrBlank, isTrue);
      expect('  '.isNullOrBlank, isTrue);
    });

    test('orDefault', () {
      String? nullStr;
      expect(nullStr.orDefault('fallback'), 'fallback');
      expect('value'.orDefault('fallback'), 'value');
    });

    test('orEmpty', () {
      String? nullStr;
      expect(nullStr.orEmpty, '');
      expect('hi'.orEmpty, 'hi');
    });
  });
}
```

**Step 2: Run test**

Run: `cd mobile && flutter test test/core/extensions/string_extension_test.dart`
Expected: All PASS

**Step 3: Commit**

```bash
git add mobile/test/core/extensions/string_extension_test.dart
git commit -m "test: add String extension tests"
```

---

### Task 14: Test LearningNotifier (Pure State)

**Files:**
- Create: `mobile/test/presentation/providers/learning_provider_test.dart`

**Step 1: Write LearningNotifier tests**

```dart
// mobile/test/presentation/providers/learning_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dutch_learn_app/presentation/providers/learning_provider.dart';
import 'package:dutch_learn_app/domain/entities/keyword.dart';

void main() {
  late LearningNotifier notifier;

  setUp(() {
    notifier = LearningNotifier();
  });

  group('LearningNotifier', () {
    test('initial state', () {
      expect(notifier.state.selectedSentenceIndex, 0);
      expect(notifier.state.showTranslation, isTrue);
      expect(notifier.state.showExplanationNl, isFalse);
      expect(notifier.state.showExplanationEn, isFalse);
      expect(notifier.state.selectedKeyword, isNull);
      expect(notifier.state.autoAdvance, isTrue);
    });

    test('selectSentence updates index', () {
      notifier.selectSentence(5);
      expect(notifier.state.selectedSentenceIndex, 5);
    });

    test('nextSentence increments within bounds', () {
      notifier.nextSentence(10);
      expect(notifier.state.selectedSentenceIndex, 1);
    });

    test('nextSentence does not exceed max', () {
      notifier.selectSentence(9);
      notifier.nextSentence(10);
      expect(notifier.state.selectedSentenceIndex, 9);
    });

    test('previousSentence decrements', () {
      notifier.selectSentence(3);
      notifier.previousSentence();
      expect(notifier.state.selectedSentenceIndex, 2);
    });

    test('previousSentence does not go below zero', () {
      notifier.previousSentence();
      expect(notifier.state.selectedSentenceIndex, 0);
    });

    test('toggleTranslation toggles visibility', () {
      expect(notifier.state.showTranslation, isTrue);
      notifier.toggleTranslation();
      expect(notifier.state.showTranslation, isFalse);
      notifier.toggleTranslation();
      expect(notifier.state.showTranslation, isTrue);
    });

    test('toggleExplanationNl toggles', () {
      notifier.toggleExplanationNl();
      expect(notifier.state.showExplanationNl, isTrue);
    });

    test('toggleExplanationEn toggles', () {
      notifier.toggleExplanationEn();
      expect(notifier.state.showExplanationEn, isTrue);
    });

    test('selectKeyword and clearKeyword', () {
      const kw = Keyword(
        id: 'k1',
        sentenceId: 's1',
        word: 'fiets',
        meaningNl: 'tweewieler',
        meaningEn: 'bicycle',
      );
      notifier.selectKeyword(kw);
      expect(notifier.state.selectedKeyword?.word, 'fiets');

      notifier.clearKeyword();
      expect(notifier.state.selectedKeyword, isNull);
    });

    test('toggleAutoAdvance toggles', () {
      notifier.toggleAutoAdvance();
      expect(notifier.state.autoAdvance, isFalse);
    });

    test('setAutoAdvance sets directly', () {
      notifier.setAutoAdvance(false);
      expect(notifier.state.autoAdvance, isFalse);
      notifier.setAutoAdvance(true);
      expect(notifier.state.autoAdvance, isTrue);
    });

    test('reset returns to initial state', () {
      notifier.selectSentence(5);
      notifier.toggleTranslation();
      notifier.toggleExplanationNl();
      notifier.reset();
      expect(notifier.state.selectedSentenceIndex, 0);
      expect(notifier.state.showTranslation, isTrue);
      expect(notifier.state.showExplanationNl, isFalse);
    });
  });
}
```

**Step 2: Run test**

Run: `cd mobile && flutter test test/presentation/providers/learning_provider_test.dart`
Expected: All PASS

**Step 3: Commit**

```bash
git add mobile/test/presentation/providers/learning_provider_test.dart
git commit -m "test: add LearningNotifier state tests"
```

---

### Task 15: Test Sentence Entity (expanded)

The existing `widget_test.dart` covers some Sentence tests. Add missing coverage for edge cases.

**Files:**
- Create: `mobile/test/domain/entities/sentence_test.dart`

**Step 1: Write expanded Sentence tests**

```dart
// mobile/test/domain/entities/sentence_test.dart
import 'package:flutter_test/flutter_test.dart';
import '../../fixtures/test_data.dart';

void main() {
  group('Sentence Entity - Extended', () {
    test('duration calculation', () {
      final s = TestData.sentence(startTime: 1.5, endTime: 4.0);
      expect(s.duration, closeTo(2.5, 0.001));
    });

    test('displayNumber is 1-indexed', () {
      expect(TestData.sentence(index: 0).displayNumber, 1);
      expect(TestData.sentence(index: 9).displayNumber, 10);
    });

    test('hasTranslation', () {
      expect(TestData.sentence(translationEn: 'Hello').hasTranslation, isTrue);
      expect(TestData.sentence(translationEn: null).hasTranslation, isFalse);
    });

    test('hasExplanation', () {
      expect(TestData.sentence(explanationNl: 'uitleg').hasExplanation, isTrue);
      expect(TestData.sentence(explanationEn: 'explain').hasExplanation, isTrue);
      expect(TestData.sentence().hasExplanation, isFalse);
    });

    test('hasKeywords', () {
      expect(TestData.sentence(keywords: []).hasKeywords, isFalse);
      expect(TestData.sentence(keywords: [TestData.keyword()]).hasKeywords, isTrue);
    });

    test('words splits text', () {
      final s = TestData.sentence(text: 'Hallo hoe gaat het');
      expect(s.words, ['Hallo', 'hoe', 'gaat', 'het']);
    });

    test('containsPosition works at boundaries', () {
      final s = TestData.sentence(startTime: 2.0, endTime: 5.0);
      expect(s.containsPosition(2.0), isTrue);
      expect(s.containsPosition(3.5), isTrue);
      expect(s.containsPosition(5.0), isTrue);
      expect(s.containsPosition(1.9), isFalse);
      expect(s.containsPosition(5.1), isFalse);
    });

    test('findKeyword finds case-insensitively', () {
      final kw = TestData.keyword(word: 'Fiets');
      final s = TestData.sentence(keywords: [kw]);
      expect(s.findKeyword('fiets')?.word, 'Fiets');
      expect(s.findKeyword('FIETS')?.word, 'Fiets');
      expect(s.findKeyword('auto'), isNull);
    });

    test('isKeyword returns bool', () {
      final kw = TestData.keyword(word: 'fiets');
      final s = TestData.sentence(keywords: [kw]);
      expect(s.isKeyword('fiets'), isTrue);
      expect(s.isKeyword('auto'), isFalse);
    });

    test('copyWith preserves unchanged fields', () {
      final original = TestData.sentence(text: 'original');
      final copied = original.copyWith(text: 'modified');
      expect(copied.text, 'modified');
      expect(copied.id, original.id);
      expect(copied.startTime, original.startTime);
    });

    test('equality by value', () {
      final a = TestData.sentence(id: 'same', text: 'same');
      final b = TestData.sentence(id: 'same', text: 'same');
      expect(a, equals(b));
    });
  });
}
```

**Step 2: Run test**

Run: `cd mobile && flutter test test/domain/entities/sentence_test.dart`
Expected: All PASS

**Step 3: Commit**

```bash
git add mobile/test/domain/entities/sentence_test.dart
git commit -m "test: add expanded Sentence entity tests"
```

---

### Task 16: Run Full Mobile Suite

**Step 1: Run all Mobile tests**

Run: `cd mobile && flutter test`
Expected: All PASS

**Step 2: Check for any failures and fix**

---

## Workstream C: Code Quality Fixes (Tasks 17-19)

### Task 17: Add dispose to SyncNotifier

**Files:**
- Modify: `mobile/lib/presentation/providers/sync_provider.dart`

**Step 1: Add dispose override**

In `SyncNotifier` class (around line 112, after the constructor), add:

```dart
  @override
  void dispose() {
    // Cancel any pending operations
    super.dispose();
  }
```

**Step 2: Run tests**

Run: `cd mobile && flutter test`
Expected: All PASS (no behavioral change)

**Step 3: Commit**

```bash
git add mobile/lib/presentation/providers/sync_provider.dart
git commit -m "fix: add dispose to SyncNotifier"
```

---

### Task 18: Extract Magic Numbers to Constants

**Files:**
- Modify: `mobile/lib/core/constants/app_constants.dart`

**Step 1: Add UI size constants**

Add to `AppConstants` class (after existing UI settings around line 38):

```dart
  // UI Sizes
  static const double emptyStateIconSize = 80.0;
  static const double dialogMaxWidth = 400.0;
  static const double playPauseButtonSize = 64.0;
  static const double progressIndicatorSize = 16.0;
  static const double signInIconSize = 80.0;
```

**Step 2: Update widget files that use magic numbers**

Replace magic numbers in these files with `AppConstants.*`:
- `mobile/lib/presentation/widgets/keyword_popup.dart` - maxWidth: 400 → `AppConstants.dialogMaxWidth`
- `mobile/lib/presentation/screens/home_screen.dart` - icon size 80 → `AppConstants.emptyStateIconSize`
- `mobile/lib/presentation/screens/sync_screen.dart` - icon size 80 → `AppConstants.signInIconSize`
- `mobile/lib/presentation/widgets/audio_player_widget.dart` - size 64 → `AppConstants.playPauseButtonSize`

**Step 3: Run tests**

Run: `cd mobile && flutter test && flutter analyze`
Expected: All PASS, no analysis warnings for these changes

**Step 4: Commit**

```bash
git add mobile/lib/core/constants/app_constants.dart mobile/lib/presentation/
git commit -m "refactor: extract magic numbers to AppConstants"
```

---

### Task 19: Verify Loading State Consistency

**Files:**
- Review only (no changes unless issues found)

**Step 1: Audit loading states**

Check these providers have consistent loading/error patterns:
- `ProjectListState.isLoading` in `project_provider.dart`
- `SyncState.isLoading` / `SyncState.isDownloading` in `sync_provider.dart`
- `AudioState.isLoading` in `audio_provider.dart`

Verify that all async methods:
1. Set `isLoading = true` before the operation
2. Set `isLoading = false` in both success and error paths
3. Set appropriate error state on failure

**Step 2: Fix any inconsistencies found**

**Step 3: Commit if changes made**

```bash
git add -u
git commit -m "fix: ensure consistent loading states across providers"
```

---

## Phase 3: Verification (Task 20)

### Task 20: Final Verification

**Step 1: Run Desktop tests with coverage**

Run: `cd desktop && python -m pytest tests/ -v --tb=short --cov=app --cov-report=term-missing`

**Step 2: Run Mobile tests**

Run: `cd mobile && flutter test`

**Step 3: Run Mobile static analysis**

Run: `cd mobile && flutter analyze`

**Step 4: Verify git status is clean**

Run: `git status`

---

## Summary

| Workstream | Tasks | Description | Can Parallelize |
|------------|-------|-------------|-----------------|
| A: Desktop Tests | 1-8 | pytest infrastructure, models, utils, services, API | Yes (independent) |
| B: Mobile Tests | 9-16 | flutter test fixtures, entities, models, extensions, providers | Yes (independent) |
| C: Code Quality | 17-19 | dispose, constants, loading states | Yes (independent) |
| Verification | 20 | Run all tests, coverage report | After A+B+C |

**Total Tasks:** 20
**Parallel Agents:** 3 (one per workstream A, B, C)
**Sequential Dependency:** Only Task 20 depends on all others

**Test files created:**
- Desktop: 6 test files (~20 test classes, ~60 test methods)
- Mobile: 6 test files (~10 test groups, ~50 test methods)

**Estimated coverage after completion:**
- Desktop: ~40-50% (models, utils, merger, encryptor, API endpoints)
- Mobile: ~25-30% (entities, models, extensions, learning provider)
