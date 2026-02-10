"""Tests for the SpeakerIdentifier service."""

import json

import pytest
from unittest.mock import AsyncMock, patch, MagicMock

from app.services.speaker_identifier import SpeakerIdentifier, SpeakerIdentification


class TestBuildPrompt:
    """Test prompt construction."""

    def test_formats_transcript_with_speaker_labels(self):
        identifier = SpeakerIdentifier(api_key="test-key")
        transcript = [
            {"label": "A", "text": "Hallo, ik ben Jan."},
            {"label": "B", "text": "Welkom Jan."},
        ]
        prompt = identifier._build_prompt(transcript, "Test Project")
        assert "[A] Hallo, ik ben Jan." in prompt
        assert "[B] Welkom Jan." in prompt
        assert "Test Project" in prompt

    def test_empty_transcript_returns_prompt(self):
        identifier = SpeakerIdentifier(api_key="test-key")
        prompt = identifier._build_prompt([], "Empty")
        assert "Empty" in prompt


class TestParseResponse:
    """Test response parsing."""

    def test_parses_valid_response(self):
        identifier = SpeakerIdentifier(api_key="test-key")
        response_json = {
            "speakers": [
                {
                    "label": "A",
                    "name": "Jan de Vries",
                    "role": "Manager",
                    "confidence": "high",
                    "evidence": "Introduced himself at the start",
                },
                {
                    "label": "B",
                    "name": "de presentator",
                    "role": "",
                    "confidence": "low",
                    "evidence": "No name mentioned",
                },
            ]
        }
        results = identifier._parse_response(json.dumps(response_json))
        assert "A" in results
        assert results["A"].name == "Jan de Vries"
        assert results["A"].role == "Manager"
        assert results["A"].confidence == "high"
        assert "B" in results
        assert results["B"].name == "de presentator"

    def test_handles_malformed_json(self):
        identifier = SpeakerIdentifier(api_key="test-key")
        results = identifier._parse_response("not valid json {{{")
        assert results == {}

    def test_handles_missing_speakers_key(self):
        identifier = SpeakerIdentifier(api_key="test-key")
        results = identifier._parse_response('{"other": "data"}')
        assert results == {}

    def test_handles_incomplete_speaker_entry(self):
        identifier = SpeakerIdentifier(api_key="test-key")
        response_json = {
            "speakers": [
                {"label": "A", "name": "Jan"},  # missing role, confidence, evidence
            ]
        }
        results = identifier._parse_response(json.dumps(response_json))
        assert "A" in results
        assert results["A"].name == "Jan"
        assert results["A"].role == ""
        assert results["A"].confidence == "low"


class TestIdentify:
    """Test the main identify method."""

    @pytest.mark.asyncio
    async def test_calls_openai_and_returns_results(self):
        identifier = SpeakerIdentifier(api_key="test-key")

        mock_response = MagicMock()
        mock_response.choices = [MagicMock()]
        mock_response.choices[0].message.content = json.dumps({
            "speakers": [
                {
                    "label": "A",
                    "name": "Jan",
                    "role": "Developer",
                    "confidence": "high",
                    "evidence": "Said his name",
                }
            ]
        })

        with patch.object(identifier.client.chat.completions, 'create',
                          new_callable=AsyncMock, return_value=mock_response):
            transcript = [{"label": "A", "text": "Ik ben Jan."}]
            results = await identifier.identify(transcript, "Test")

        assert "A" in results
        assert results["A"].name == "Jan"

    @pytest.mark.asyncio
    async def test_returns_empty_on_api_error(self):
        identifier = SpeakerIdentifier(api_key="test-key")

        with patch.object(identifier.client.chat.completions, 'create',
                          new_callable=AsyncMock, side_effect=Exception("API down")):
            transcript = [{"label": "A", "text": "Hallo."}]
            results = await identifier.identify(transcript, "Test")

        assert results == {}

    @pytest.mark.asyncio
    async def test_empty_transcript_returns_empty(self):
        identifier = SpeakerIdentifier(api_key="test-key")
        results = await identifier.identify([], "Test")
        assert results == {}
