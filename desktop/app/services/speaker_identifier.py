"""
Speaker identification service using OpenAI GPT API.

Analyzes conversation transcripts to identify speakers by name and role
based on contextual clues in the dialogue.
"""

import json
import logging
from dataclasses import dataclass
from typing import Dict, List, Optional

from openai import AsyncOpenAI

from app.config import settings


logger = logging.getLogger(__name__)


@dataclass
class SpeakerIdentification:
    """Result of identifying a single speaker."""

    label: str
    name: str
    role: str = ""
    confidence: str = "low"
    evidence: str = ""


class SpeakerIdentifier:
    """
    Service for identifying speakers in a conversation transcript using GPT.

    Sends the full transcript to GPT and asks it to infer speaker identities
    based on contextual clues like introductions, name mentions, and job titles.

    Example:
        identifier = SpeakerIdentifier()
        results = await identifier.identify(
            [{"label": "A", "text": "Ik ben Jan."}],
            "Interview Project",
        )
        print(results["A"].name)  # "Jan"
    """

    def __init__(self, api_key: Optional[str] = None):
        """
        Initialize the speaker identifier.

        Args:
            api_key: OpenAI API key. Uses settings.openai_api_key if not provided.
        """
        self.api_key = api_key or settings.openai_api_key
        self.client = AsyncOpenAI(api_key=self.api_key)
        self.model = settings.gpt_model

    def _build_prompt(self, transcript: List[Dict[str, str]], project_name: str) -> str:
        """
        Build the prompt for speaker identification.

        Args:
            transcript: List of dicts with 'label' and 'text' keys.
            project_name: Name of the project for context.

        Returns:
            The formatted prompt string.
        """
        lines = [f"[{entry['label']}] {entry['text']}" for entry in transcript]
        transcript_text = "\n".join(lines)

        return f"""You are analyzing a Dutch conversation transcript titled "{project_name}".
The transcript has speaker labels (A, B, C, etc.) assigned by automatic diarization.

Based on context clues (introductions, name mentions, job titles, how others address them),
identify each speaker.

<transcript>
{transcript_text}
</transcript>

Return ONLY a valid JSON object in this exact format:
{{
  "speakers": [
    {{
      "label": "A",
      "name": "Jan de Vries",
      "role": "IT Service Manager",
      "confidence": "high",
      "evidence": "Introduced himself at the start and others refer to him as Jan"
    }}
  ]
}}

Rules:
- If you cannot determine a name, use a descriptive label in Dutch like "de presentator" or "de manager"
- confidence: "high" = name explicitly mentioned, "medium" = inferred from context, "low" = guess
- evidence: brief explanation of how you determined the identity
- Include ALL speaker labels found in the transcript"""

    def _parse_response(self, content: str) -> Dict[str, SpeakerIdentification]:
        """
        Parse the GPT response into SpeakerIdentification objects.

        Args:
            content: Raw JSON string from the GPT response.

        Returns:
            Dict mapping speaker labels to SpeakerIdentification objects.
            Returns empty dict on parse failure.
        """
        try:
            data = json.loads(content)
        except (json.JSONDecodeError, TypeError):
            logger.warning("Failed to parse speaker identification response as JSON")
            return {}

        speakers = data.get("speakers", [])
        if not isinstance(speakers, list):
            return {}

        results: Dict[str, SpeakerIdentification] = {}
        for entry in speakers:
            if not isinstance(entry, dict) or "label" not in entry:
                continue
            label = entry["label"]
            results[label] = SpeakerIdentification(
                label=label,
                name=entry.get("name", f"Speaker {label}"),
                role=entry.get("role", ""),
                confidence=entry.get("confidence", "low"),
                evidence=entry.get("evidence", ""),
            )
        return results

    async def identify(
        self,
        transcript: List[Dict[str, str]],
        project_name: str,
    ) -> Dict[str, SpeakerIdentification]:
        """
        Identify speakers in a transcript.

        Args:
            transcript: List of dicts with 'label' and 'text' keys.
            project_name: Name of the project for context.

        Returns:
            Dict mapping speaker labels to SpeakerIdentification objects.
            Returns empty dict on any error.
        """
        if not transcript:
            return {}

        prompt = self._build_prompt(transcript, project_name)

        try:
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3,
                response_format={"type": "json_object"},
            )
            content = response.choices[0].message.content
            return self._parse_response(content)
        except Exception as e:
            logger.warning(f"Speaker identification API call failed: {e}")
            return {}
