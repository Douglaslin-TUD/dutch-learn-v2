"""
Database configuration and session management.

Uses SQLAlchemy with SQLite for data persistence.
"""

from contextlib import contextmanager
from typing import Generator

from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker, Session, declarative_base

from app.config import settings


# Create SQLAlchemy engine
engine = create_engine(
    settings.database_url,
    connect_args={"check_same_thread": False},  # Required for SQLite
    echo=settings.debug,
)


# Enable foreign key constraints for SQLite
@event.listens_for(engine, "connect")
def set_sqlite_pragma(dbapi_connection, connection_record):
    """Enable foreign key support in SQLite."""
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.close()


# Create session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base class for models
Base = declarative_base()


def get_db() -> Generator[Session, None, None]:
    """
    Dependency for FastAPI that provides a database session.

    Yields:
        Session: SQLAlchemy database session.

    Example:
        @app.get("/items")
        def get_items(db: Session = Depends(get_db)):
            return db.query(Item).all()
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@contextmanager
def get_db_context() -> Generator[Session, None, None]:
    """
    Context manager for database sessions in non-FastAPI contexts.

    Yields:
        Session: SQLAlchemy database session.

    Example:
        with get_db_context() as db:
            project = db.query(Project).first()
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db() -> None:
    """
    Initialize the database by creating all tables.

    This should be called once at application startup.
    """
    # Import models to register them with Base
    from app.models import project, speaker, sentence, keyword

    Base.metadata.create_all(bind=engine)
    migrate_db()


def migrate_db() -> None:
    """Add columns to existing databases that create_all won't add."""
    import sqlite3
    from pathlib import Path

    db_path = settings.database_url.replace("sqlite:///", "")
    if not Path(db_path).exists():
        return

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("PRAGMA table_info(sentences)")
    existing = {row[1] for row in cursor.fetchall()}

    migrations = [
        ("learned", "ALTER TABLE sentences ADD COLUMN learned BOOLEAN NOT NULL DEFAULT 0"),
        ("learn_count", "ALTER TABLE sentences ADD COLUMN learn_count INTEGER NOT NULL DEFAULT 0"),
        ("is_difficult", "ALTER TABLE sentences ADD COLUMN is_difficult BOOLEAN NOT NULL DEFAULT 0"),
        ("review_count", "ALTER TABLE sentences ADD COLUMN review_count INTEGER NOT NULL DEFAULT 0"),
        ("last_reviewed", "ALTER TABLE sentences ADD COLUMN last_reviewed DATETIME"),
    ]

    for col_name, sql in migrations:
        if col_name not in existing:
            cursor.execute(sql)

    conn.commit()
    conn.close()
