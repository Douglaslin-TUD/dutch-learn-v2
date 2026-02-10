"""Tests for desktop/app/services/progress_merger.py."""

import json
from datetime import datetime
from unittest.mock import patch

import pytest

from app.services.progress_merger import ProgressMerger, merge_progress_files


class TestProgressMerger:
    """Tests for the ProgressMerger class."""

    @pytest.fixture
    def merger(self):
        """Provide a fresh ProgressMerger instance."""
        return ProgressMerger()

    # --- Sentence merging ---

    def test_merge_prefers_higher_learn_count(self, merger):
        """Remote has higher learn_count; merged result should take the max."""
        local = {
            "id": "p1",
            "name": "Test",
            "sentences": [
                {"id": "s1", "text": "Hallo", "learn_count": 3, "order": 0},
            ],
            "keywords": [],
            "progress": {},
        }
        remote = {
            "id": "p1",
            "name": "Test",
            "sentences": [
                {"id": "s1", "text": "Hallo", "learn_count": 5, "order": 0},
            ],
            "keywords": [],
            "progress": {},
        }
        result = merger.merge(local, remote)
        assert result["sentences"][0]["learn_count"] == 5

    def test_merge_local_wins_when_higher(self, merger):
        """Local has higher learn_count; merged result should keep local value."""
        local = {
            "id": "p1",
            "name": "Test",
            "sentences": [
                {"id": "s1", "text": "Hallo", "learn_count": 7, "order": 0},
            ],
            "keywords": [],
            "progress": {},
        }
        remote = {
            "id": "p1",
            "name": "Test",
            "sentences": [
                {"id": "s1", "text": "Hallo", "learn_count": 2, "order": 0},
            ],
            "keywords": [],
            "progress": {},
        }
        result = merger.merge(local, remote)
        assert result["sentences"][0]["learn_count"] == 7

    def test_merge_keeps_local_only_sentences(self, merger):
        """Sentences only in local should appear in merged output."""
        local = {
            "id": "p1",
            "name": "Test",
            "sentences": [
                {"id": "s1", "text": "Local only", "learn_count": 1, "order": 0},
            ],
            "keywords": [],
            "progress": {},
        }
        remote = {
            "id": "p1",
            "name": "Test",
            "sentences": [],
            "keywords": [],
            "progress": {},
        }
        result = merger.merge(local, remote)
        assert len(result["sentences"]) == 1
        assert result["sentences"][0]["text"] == "Local only"

    def test_merge_keeps_remote_only_sentences(self, merger):
        """Sentences only in remote should appear in merged output."""
        local = {
            "id": "p1",
            "name": "Test",
            "sentences": [],
            "keywords": [],
            "progress": {},
        }
        remote = {
            "id": "p1",
            "name": "Test",
            "sentences": [
                {"id": "s1", "text": "Remote only", "learn_count": 4, "order": 0},
            ],
            "keywords": [],
            "progress": {},
        }
        result = merger.merge(local, remote)
        assert len(result["sentences"]) == 1
        assert result["sentences"][0]["text"] == "Remote only"
        assert result["sentences"][0]["learn_count"] == 4

    def test_merge_learned_flag_is_or(self, merger):
        """If either side marks a sentence as learned, merged should be True."""
        local = {
            "id": "p1",
            "name": "Test",
            "sentences": [
                {"id": "s1", "text": "Hallo", "learned": False, "learn_count": 1, "order": 0},
            ],
            "keywords": [],
            "progress": {},
        }
        remote = {
            "id": "p1",
            "name": "Test",
            "sentences": [
                {"id": "s1", "text": "Hallo", "learned": True, "learn_count": 3, "order": 0},
            ],
            "keywords": [],
            "progress": {},
        }
        result = merger.merge(local, remote)
        assert result["sentences"][0]["learned"] is True

    def test_merge_learned_both_false(self, merger):
        """If neither side marks learned, result should be False."""
        local = {
            "id": "p1",
            "name": "Test",
            "sentences": [
                {"id": "s1", "text": "Hallo", "learned": False, "learn_count": 0, "order": 0},
            ],
            "keywords": [],
            "progress": {},
        }
        remote = {
            "id": "p1",
            "name": "Test",
            "sentences": [
                {"id": "s1", "text": "Hallo", "learned": False, "learn_count": 0, "order": 0},
            ],
            "keywords": [],
            "progress": {},
        }
        result = merger.merge(local, remote)
        assert result["sentences"][0]["learned"] is False

    def test_merge_sentences_sorted_by_order(self, merger):
        """Merged sentences should be sorted by the 'index' field."""
        local = {
            "id": "p1",
            "name": "Test",
            "sentences": [
                {"id": "s2", "text": "Second", "learn_count": 0, "index": 2},
            ],
            "keywords": [],
            "progress": {},
        }
        remote = {
            "id": "p1",
            "name": "Test",
            "sentences": [
                {"id": "s1", "text": "First", "learn_count": 0, "index": 1},
                {"id": "s3", "text": "Third", "learn_count": 0, "index": 3},
            ],
            "keywords": [],
            "progress": {},
        }
        result = merger.merge(local, remote)
        assert len(result["sentences"]) == 3
        assert [s["id"] for s in result["sentences"]] == ["s1", "s2", "s3"]

    def test_merge_sentence_none_learn_count_treated_as_zero(self, merger):
        """A None learn_count should be treated as 0."""
        local = {
            "id": "p1",
            "name": "Test",
            "sentences": [
                {"id": "s1", "text": "Hallo", "learn_count": None, "order": 0},
            ],
            "keywords": [],
            "progress": {},
        }
        remote = {
            "id": "p1",
            "name": "Test",
            "sentences": [
                {"id": "s1", "text": "Hallo", "learn_count": 3, "order": 0},
            ],
            "keywords": [],
            "progress": {},
        }
        result = merger.merge(local, remote)
        assert result["sentences"][0]["learn_count"] == 3

    # --- Keyword merging ---

    def test_merge_keywords_prefers_local(self, merger):
        """When same keyword ID exists in both, local data should win."""
        local = {
            "id": "p1",
            "name": "Test",
            "sentences": [],
            "keywords": [
                {"id": "k1", "word": "fiets", "meaning_en": "bicycle (local)"},
            ],
            "progress": {},
        }
        remote = {
            "id": "p1",
            "name": "Test",
            "sentences": [],
            "keywords": [
                {"id": "k1", "word": "fiets", "meaning_en": "bicycle (remote)"},
            ],
            "progress": {},
        }
        result = merger.merge(local, remote)
        assert len(result["keywords"]) == 1
        assert result["keywords"][0]["meaning_en"] == "bicycle (local)"

    def test_merge_keywords_adds_remote_only(self, merger):
        """Keywords only in remote should be added to merged result."""
        local = {
            "id": "p1",
            "name": "Test",
            "sentences": [],
            "keywords": [
                {"id": "k1", "word": "fiets", "meaning_en": "bicycle"},
            ],
            "progress": {},
        }
        remote = {
            "id": "p1",
            "name": "Test",
            "sentences": [],
            "keywords": [
                {"id": "k2", "word": "huis", "meaning_en": "house"},
            ],
            "progress": {},
        }
        result = merger.merge(local, remote)
        assert len(result["keywords"]) == 2
        words = {k["word"] for k in result["keywords"]}
        assert words == {"fiets", "huis"}

    def test_merge_keywords_empty_both(self, merger):
        """Empty keyword lists from both sides should produce empty result."""
        local = {
            "id": "p1",
            "name": "Test",
            "sentences": [],
            "keywords": [],
            "progress": {},
        }
        remote = {
            "id": "p1",
            "name": "Test",
            "sentences": [],
            "keywords": [],
            "progress": {},
        }
        result = merger.merge(local, remote)
        assert result["keywords"] == []

    # --- Progress merging ---

    def test_merge_progress_remote_wins_when_more_recent(self, merger):
        """When remote has a more recent last_sync, its progress dict is used."""
        local = {
            "id": "p1",
            "name": "Test",
            "sentences": [],
            "keywords": [],
            "progress": {
                "last_sync": "2026-01-10T08:00:00",
                "custom_local": "local_value",
            },
        }
        remote = {
            "id": "p1",
            "name": "Test",
            "sentences": [],
            "keywords": [],
            "progress": {
                "last_sync": "2026-01-15T10:00:00",
                "custom_remote": "remote_value",
            },
        }
        result = merger.merge(local, remote)
        # The _merge_progress picks remote dict, but then merge() overwrites
        # total_sentences, learned_sentences, and last_sync.
        # We can check that the remote-specific key survived.
        assert "custom_remote" in result["progress"]

    def test_merge_progress_local_wins_when_more_recent(self, merger):
        """When local has a more recent last_sync, its progress dict is used."""
        local = {
            "id": "p1",
            "name": "Test",
            "sentences": [],
            "keywords": [],
            "progress": {
                "last_sync": "2026-01-20T10:00:00",
                "custom_local": "local_value",
            },
        }
        remote = {
            "id": "p1",
            "name": "Test",
            "sentences": [],
            "keywords": [],
            "progress": {
                "last_sync": "2026-01-15T10:00:00",
                "custom_remote": "remote_value",
            },
        }
        result = merger.merge(local, remote)
        assert "custom_local" in result["progress"]

    def test_merge_progress_local_wins_when_remote_has_no_sync(self, merger):
        """When remote has no last_sync, local progress should be used."""
        local = {
            "id": "p1",
            "name": "Test",
            "sentences": [],
            "keywords": [],
            "progress": {"last_sync": "2026-01-20T10:00:00", "note": "local"},
        }
        remote = {
            "id": "p1",
            "name": "Test",
            "sentences": [],
            "keywords": [],
            "progress": {"note": "remote"},
        }
        result = merger.merge(local, remote)
        assert result["progress"]["note"] == "local"

    def test_merge_progress_remote_wins_when_local_has_no_sync(self, merger):
        """When local has no last_sync but remote does, remote progress is used."""
        local = {
            "id": "p1",
            "name": "Test",
            "sentences": [],
            "keywords": [],
            "progress": {"note": "local"},
        }
        remote = {
            "id": "p1",
            "name": "Test",
            "sentences": [],
            "keywords": [],
            "progress": {"last_sync": "2026-01-15T10:00:00", "note": "remote"},
        }
        result = merger.merge(local, remote)
        assert result["progress"]["note"] == "remote"

    def test_merge_progress_recalculates_totals(self, merger):
        """Merged progress should recalculate total and learned sentence counts."""
        local = {
            "id": "p1",
            "name": "Test",
            "sentences": [
                {"id": "s1", "text": "A", "learned": True, "learn_count": 5, "order": 0},
                {"id": "s2", "text": "B", "learned": False, "learn_count": 1, "order": 1},
            ],
            "keywords": [],
            "progress": {},
        }
        remote = {
            "id": "p1",
            "name": "Test",
            "sentences": [
                {"id": "s3", "text": "C", "learned": True, "learn_count": 2, "order": 2},
            ],
            "keywords": [],
            "progress": {},
        }
        result = merger.merge(local, remote)
        assert result["progress"]["total_sentences"] == 3
        assert result["progress"]["learned_sentences"] == 2

    # --- Project metadata ---

    def test_merge_prefers_local_name(self, merger):
        """Project name should come from local data."""
        local = {
            "id": "p1",
            "name": "Local Name",
            "sentences": [],
            "keywords": [],
            "progress": {},
        }
        remote = {
            "id": "p1",
            "name": "Remote Name",
            "sentences": [],
            "keywords": [],
            "progress": {},
        }
        result = merger.merge(local, remote)
        assert result["name"] == "Local Name"

    def test_merge_created_at_uses_earliest(self, merger):
        """The created_at timestamp should be the earliest of the two."""
        local = {
            "id": "p1",
            "name": "Test",
            "created_at": "2026-01-15T10:00:00",
            "sentences": [],
            "keywords": [],
            "progress": {},
        }
        remote = {
            "id": "p1",
            "name": "Test",
            "created_at": "2026-01-10T08:00:00",
            "sentences": [],
            "keywords": [],
            "progress": {},
        }
        result = merger.merge(local, remote)
        assert result["created_at"] == "2026-01-10T08:00:00"

    def test_merge_sets_updated_at(self, merger):
        """The updated_at field should be set to the current time."""
        local = {
            "id": "p1",
            "name": "Test",
            "sentences": [],
            "keywords": [],
            "progress": {},
        }
        remote = {
            "id": "p1",
            "name": "Test",
            "sentences": [],
            "keywords": [],
            "progress": {},
        }
        before = datetime.now()
        result = merger.merge(local, remote)
        after = datetime.now()
        updated = datetime.fromisoformat(result["updated_at"])
        assert before <= updated <= after

    def test_merge_status_from_local(self, merger):
        """Status should prefer local value."""
        local = {
            "id": "p1",
            "name": "Test",
            "status": "ready",
            "sentences": [],
            "keywords": [],
            "progress": {},
        }
        remote = {
            "id": "p1",
            "name": "Test",
            "status": "completed",
            "sentences": [],
            "keywords": [],
            "progress": {},
        }
        result = merger.merge(local, remote)
        assert result["status"] == "ready"

    # --- Timestamp helpers ---

    def test_parse_timestamp_valid(self, merger):
        """Valid ISO timestamp should be parsed to datetime."""
        result = merger._parse_timestamp("2026-01-15T10:00:00")
        assert isinstance(result, datetime)
        assert result.year == 2026

    def test_parse_timestamp_with_z_suffix(self, merger):
        """Timestamps ending with Z should be handled correctly."""
        result = merger._parse_timestamp("2026-01-15T10:00:00Z")
        assert isinstance(result, datetime)

    def test_parse_timestamp_invalid(self, merger):
        """Invalid timestamp strings should return None."""
        assert merger._parse_timestamp("not-a-date") is None

    def test_parse_timestamp_empty(self, merger):
        """Empty string should return None."""
        assert merger._parse_timestamp("") is None

    def test_earliest_timestamp_both_valid(self, merger):
        """Should return the earlier of two valid timestamps."""
        early = "2026-01-10T08:00:00"
        late = "2026-01-15T10:00:00"
        assert merger._earliest_timestamp(early, late) == early
        assert merger._earliest_timestamp(late, early) == early

    def test_earliest_timestamp_one_none(self, merger):
        """When one timestamp is None, return the other."""
        ts = "2026-01-15T10:00:00"
        assert merger._earliest_timestamp(ts, None) == ts
        assert merger._earliest_timestamp(None, ts) == ts

    def test_earliest_timestamp_both_none(self, merger):
        """When both timestamps are None, return None."""
        assert merger._earliest_timestamp(None, None) is None


class TestMergeProgressFiles:
    """Tests for the merge_progress_files convenience function."""

    def test_round_trip(self, tmp_path):
        """Merge two JSON files and verify the output file is created with correct data."""
        local_data = {
            "id": "p1",
            "name": "Test",
            "sentences": [
                {"id": "s1", "text": "Hallo", "learn_count": 3, "order": 0},
            ],
            "keywords": [],
            "progress": {},
        }
        remote_data = {
            "id": "p1",
            "name": "Test",
            "sentences": [
                {"id": "s1", "text": "Hallo", "learn_count": 5, "order": 0},
            ],
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

        # Verify the file was written correctly
        written = json.loads(output_path.read_text())
        assert written["sentences"][0]["learn_count"] == 5

    def test_output_file_contains_valid_json(self, tmp_path):
        """The output file should contain valid JSON that can be loaded back."""
        local_data = {
            "id": "p1",
            "name": "Test",
            "sentences": [],
            "keywords": [],
            "progress": {},
        }
        remote_data = {
            "id": "p1",
            "name": "Test",
            "sentences": [],
            "keywords": [],
            "progress": {},
        }

        local_path = tmp_path / "local.json"
        remote_path = tmp_path / "remote.json"
        output_path = tmp_path / "merged.json"

        local_path.write_text(json.dumps(local_data))
        remote_path.write_text(json.dumps(remote_data))

        merge_progress_files(str(local_path), str(remote_path), str(output_path))

        loaded = json.loads(output_path.read_text())
        assert loaded["id"] == "p1"
        assert loaded["name"] == "Test"
        assert "sentences" in loaded
        assert "keywords" in loaded
        assert "progress" in loaded
