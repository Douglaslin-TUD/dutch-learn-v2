"""
Keyword model for storing vocabulary words extracted from sentences.
"""

import uuid

from sqlalchemy import Column, String, Text, ForeignKey
from sqlalchemy.orm import relationship

from app.database import Base


class Keyword(Base):
    """
    Represents a vocabulary word extracted from a sentence.

    Attributes:
        id: Unique identifier (UUID).
        sentence_id: Foreign key to parent Sentence.
        word: The Dutch vocabulary word.
        meaning_nl: Dutch meaning/definition.
        meaning_en: English meaning/translation.
        sentence: Related Sentence object.
    """

    __tablename__ = "keywords"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    sentence_id = Column(
        String(36),
        ForeignKey("sentences.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    word = Column(String(100), nullable=False)
    meaning_nl = Column(Text, nullable=False)
    meaning_en = Column(Text, nullable=False)

    # Relationships
    sentence = relationship("Sentence", back_populates="keywords")

    def to_dict(self) -> dict:
        """
        Convert keyword to dictionary representation.

        Returns:
            dict: Keyword data as dictionary.
        """
        return {
            "id": self.id,
            "sentence_id": self.sentence_id,
            "word": self.word,
            "meaning_nl": self.meaning_nl,
            "meaning_en": self.meaning_en,
        }

    def __repr__(self) -> str:
        return f"<Keyword(id={self.id}, word={self.word})>"
