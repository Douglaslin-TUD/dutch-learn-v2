"""
Project model for storing uploaded audio/video project metadata.
"""

from datetime import datetime
from typing import List, Optional
import uuid

from sqlalchemy import Column, String, Integer, DateTime, Text, CheckConstraint
from sqlalchemy.orm import relationship

from app.database import Base


class Project(Base):
    """
    Represents an uploaded audio/video project.

    Attributes:
        id: Unique identifier (UUID).
        name: Project display name.
        original_file: Original uploaded filename.
        audio_file: Path to extracted audio file.
        status: Processing status (pending, extracting, transcribing, explaining, ready, error).
        error_message: Error details if status is 'error'.
        total_sentences: Total number of sentences to process.
        processed_sentences: Number of sentences processed so far.
        created_at: Timestamp when project was created.
        updated_at: Timestamp when project was last updated.
        sentences: Related Sentence objects.
    """

    __tablename__ = "projects"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String(255), nullable=False)
    original_file = Column(String(255), nullable=False)
    audio_file = Column(String(255), nullable=True)
    status = Column(
        String(20),
        nullable=False,
        default="pending",
    )
    error_message = Column(Text, nullable=True)
    total_sentences = Column(Integer, default=0)
    processed_sentences = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    sentences = relationship(
        "Sentence",
        back_populates="project",
        cascade="all, delete-orphan",
        order_by="Sentence.idx",
    )

    __table_args__ = (
        CheckConstraint(
            "status IN ('pending', 'extracting', 'transcribing', 'explaining', 'ready', 'error')",
            name="check_valid_status",
        ),
    )

    @property
    def progress(self) -> int:
        """
        Calculate overall processing progress as a percentage.

        Returns:
            int: Progress percentage (0-100).
        """
        stages = {
            "pending": 0,
            "extracting": 10,
            "transcribing": 30,
            "explaining": 50,
            "ready": 100,
            "error": 0,
        }
        base = stages.get(self.status, 0)

        if self.status == "explaining" and self.total_sentences > 0:
            explanation_progress = self.processed_sentences / self.total_sentences
            return 50 + int(explanation_progress * 45)

        return base

    @property
    def current_stage_description(self) -> str:
        """
        Get human-readable description of current processing stage.

        Returns:
            str: Description of current stage.
        """
        descriptions = {
            "pending": "Waiting to start...",
            "extracting": "Extracting audio from video...",
            "transcribing": "Transcribing audio to text...",
            "explaining": f"Generating explanations ({self.processed_sentences}/{self.total_sentences})...",
            "ready": "Processing complete",
            "error": f"Error: {self.error_message or 'Unknown error'}",
        }
        return descriptions.get(self.status, "Unknown status")

    def to_dict(self, include_sentences: bool = False) -> dict:
        """
        Convert project to dictionary representation.

        Args:
            include_sentences: Whether to include sentence data.

        Returns:
            dict: Project data as dictionary.
        """
        data = {
            "id": self.id,
            "name": self.name,
            "original_file": self.original_file,
            "audio_file": self.audio_file,
            "status": self.status,
            "error_message": self.error_message,
            "progress": self.progress,
            "current_stage": self.current_stage_description,
            "total_sentences": self.total_sentences,
            "processed_sentences": self.processed_sentences,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }

        if include_sentences:
            data["sentences"] = [s.to_dict() for s in self.sentences]

        return data

    def __repr__(self) -> str:
        return f"<Project(id={self.id}, name={self.name}, status={self.status})>"
