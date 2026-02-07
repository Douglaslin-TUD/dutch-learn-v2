"""Shared test fixtures for Desktop backend tests."""

import uuid

import pytest
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
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
        poolclass=StaticPool,
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
