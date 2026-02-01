"""
Speaker model for storing identified speakers in audio transcriptions.
"""

import uuid
from sqlalchemy import Column, String, Float, Text, Boolean, ForeignKey
from sqlalchemy.orm import relationship

from app.database import Base


class Speaker(Base):
    """
    Represents a speaker identified in an audio transcription.

    Attributes:
        id: Unique identifier (UUID).
        project_id: Foreign key to parent Project.
        label: Original speaker label from diarization (A, B, C...).
        display_name: Human-readable name (auto-inferred or user-set).
        confidence: Confidence score for name inference (0.0-1.0).
        evidence: JSON string of evidence sentences for name inference.
        is_manual: Whether display_name was manually set by user.
    """

    __tablename__ = "speakers"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    project_id = Column(
        String(36),
        ForeignKey("projects.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    label = Column(String(10), nullable=False)
    display_name = Column(String(100), nullable=True)
    confidence = Column(Float, default=0.0)
    evidence = Column(Text, nullable=True)  # JSON string
    is_manual = Column(Boolean, default=False)

    # Relationships
    project = relationship("Project", back_populates="speakers")
    sentences = relationship("Sentence", back_populates="speaker")

    def to_dict(self) -> dict:
        """Convert speaker to dictionary representation."""
        import json
        return {
            "id": self.id,
            "project_id": self.project_id,
            "label": self.label,
            "display_name": self.display_name or f"Speaker {self.label}",
            "confidence": self.confidence,
            "evidence": json.loads(self.evidence) if self.evidence else [],
            "is_manual": self.is_manual,
        }

    def __repr__(self) -> str:
        return f"<Speaker(id={self.id}, label={self.label}, name={self.display_name})>"
