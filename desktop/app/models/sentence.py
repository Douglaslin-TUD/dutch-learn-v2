"""
Sentence model for storing transcribed sentences with timestamps and explanations.
"""

from datetime import datetime
from typing import List, Optional
import uuid

from sqlalchemy import Column, String, Integer, Float, Text, DateTime, ForeignKey
from sqlalchemy.orm import relationship

from app.database import Base


class Sentence(Base):
    """
    Represents a transcribed sentence with timestamps and explanations.

    Attributes:
        id: Unique identifier (UUID).
        project_id: Foreign key to parent Project.
        idx: Sentence index/order within the project (0-based).
        text: The Dutch sentence text.
        start_time: Start timestamp in seconds.
        end_time: End timestamp in seconds.
        translation_en: Full English translation of the sentence.
        explanation_nl: Dutch explanation of the sentence.
        explanation_en: English explanation of the sentence.
        created_at: Timestamp when sentence was created.
        project: Related Project object.
        keywords: Related Keyword objects.
    """

    __tablename__ = "sentences"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    project_id = Column(
        String(36),
        ForeignKey("projects.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    idx = Column(Integer, nullable=False)
    text = Column(Text, nullable=False)
    start_time = Column(Float, nullable=False)
    end_time = Column(Float, nullable=False)
    translation_en = Column(Text, nullable=True)
    explanation_nl = Column(Text, nullable=True)
    explanation_en = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    project = relationship("Project", back_populates="sentences")
    keywords = relationship(
        "Keyword",
        back_populates="sentence",
        cascade="all, delete-orphan",
    )

    @property
    def duration(self) -> float:
        """
        Calculate sentence duration in seconds.

        Returns:
            float: Duration in seconds.
        """
        return self.end_time - self.start_time

    @property
    def has_explanation(self) -> bool:
        """
        Check if sentence has been processed with explanations.

        Returns:
            bool: True if explanations exist.
        """
        return bool(self.explanation_nl or self.explanation_en)

    def to_dict(self, include_keywords: bool = True) -> dict:
        """
        Convert sentence to dictionary representation.

        Args:
            include_keywords: Whether to include keyword data.

        Returns:
            dict: Sentence data as dictionary.
        """
        data = {
            "id": self.id,
            "project_id": self.project_id,
            "index": self.idx,
            "text": self.text,
            "start_time": self.start_time,
            "end_time": self.end_time,
            "duration": self.duration,
            "translation_en": self.translation_en,
            "explanation_nl": self.explanation_nl,
            "explanation_en": self.explanation_en,
            "has_explanation": self.has_explanation,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }

        if include_keywords:
            data["keywords"] = [k.to_dict() for k in self.keywords]

        return data

    def __repr__(self) -> str:
        return f"<Sentence(id={self.id}, idx={self.idx}, text={self.text[:30]}...)>"
