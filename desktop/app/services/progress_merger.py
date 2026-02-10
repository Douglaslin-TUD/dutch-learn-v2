"""
Progress Merger for Dutch Language Learning Application.

Handles merging learning progress between local and remote data sources.
Uses "last-write-wins" strategy for individual sentence progress.
"""

from datetime import datetime
from typing import Optional


class ProgressMerger:
    """
    Merges learning progress between local and remote project data.

    Strategy:
    - For sentences: Use highest learn_count and latest learned status
    - For progress metadata: Take the most recent sync timestamp
    - Project metadata: Prefer local (name can be edited locally)
    """

    def merge(self, local_data: dict, remote_data: dict) -> dict:
        """
        Merge local and remote project data.

        Args:
            local_data: Local project export data
            remote_data: Remote project data from Google Drive

        Returns:
            Merged project data
        """
        merged = {
            'id': local_data.get('id') or remote_data.get('id'),
            'name': local_data.get('name') or remote_data.get('name'),
            'status': local_data.get('status') or remote_data.get('status', 'ready'),
            'created_at': self._earliest_timestamp(
                local_data.get('created_at'),
                remote_data.get('created_at')
            ),
            'updated_at': datetime.now().isoformat(),
            'sentences': self._merge_sentences(
                local_data.get('sentences', []),
                remote_data.get('sentences', [])
            ),
            'keywords': self._merge_keywords(
                local_data.get('keywords', []),
                remote_data.get('keywords', [])
            ),
            'speakers': self._merge_speakers(
                local_data.get('speakers', []),
                remote_data.get('speakers', []),
            ),
            'progress': self._merge_progress(
                local_data.get('progress', {}),
                remote_data.get('progress', {})
            ),
        }

        # Recalculate progress totals
        merged['progress']['total_sentences'] = len(merged['sentences'])
        merged['progress']['learned_sentences'] = sum(
            1 for s in merged['sentences'] if s.get('learned', False)
        )
        merged['progress']['difficult_sentences'] = sum(
            1 for s in merged['sentences'] if s.get('is_difficult', False)
        )
        merged['progress']['last_sync'] = datetime.now().isoformat()

        return merged

    def _merge_sentences(self, local: list, remote: list) -> list:
        """
        Merge sentence lists, preserving learning progress.

        Takes the higher learn_count and marks as learned if either source has it learned.
        """
        # Index by ID for quick lookup
        local_by_id = {s['id']: s for s in local}
        remote_by_id = {s['id']: s for s in remote}

        merged = []
        all_ids = set(local_by_id.keys()) | set(remote_by_id.keys())

        for sentence_id in all_ids:
            local_s = local_by_id.get(sentence_id, {})
            remote_s = remote_by_id.get(sentence_id, {})

            # Base sentence data - prefer local for text content
            if local_s:
                merged_sentence = local_s.copy()
            else:
                merged_sentence = remote_s.copy()

            # Merge learning progress - use max values
            local_learned = local_s.get('learned', False)
            remote_learned = remote_s.get('learned', False)
            merged_sentence['learned'] = local_learned or remote_learned

            local_count = local_s.get('learn_count', 0) or 0
            remote_count = remote_s.get('learn_count', 0) or 0
            merged_sentence['learn_count'] = max(local_count, remote_count)

            # Merge difficult/review progress
            merged_sentence['is_difficult'] = local_s.get('is_difficult', False) or remote_s.get('is_difficult', False)

            local_review = local_s.get('review_count', 0) or 0
            remote_review = remote_s.get('review_count', 0) or 0
            merged_sentence['review_count'] = max(local_review, remote_review)

            local_lr = local_s.get('last_reviewed')
            remote_lr = remote_s.get('last_reviewed')
            if local_lr and remote_lr:
                local_dt = self._parse_timestamp(local_lr)
                remote_dt = self._parse_timestamp(remote_lr)
                merged_sentence['last_reviewed'] = local_lr if (local_dt and remote_dt and local_dt >= remote_dt) else remote_lr
            else:
                merged_sentence['last_reviewed'] = local_lr or remote_lr

            merged.append(merged_sentence)

        # Sort by order
        merged.sort(key=lambda s: s.get('index', s.get('idx', 0)))

        return merged

    def _merge_keywords(self, local: list, remote: list) -> list:
        """
        Merge keyword lists.

        Keywords don't have learning progress, so just combine unique entries.
        """
        local_by_id = {k['id']: k for k in local}
        remote_by_id = {k['id']: k for k in remote}

        # Prefer local keywords, add remote-only keywords
        merged = list(local_by_id.values())

        for keyword_id, keyword in remote_by_id.items():
            if keyword_id not in local_by_id:
                merged.append(keyword)

        return merged

    def _merge_speakers(self, local_speakers: list, remote_speakers: list) -> list:
        """Merge speaker lists, preferring manually set display names."""
        speaker_map = {}
        for sp in local_speakers:
            speaker_map[sp.get('id', '')] = sp
        for sp in remote_speakers:
            sp_id = sp.get('id', '')
            if sp_id in speaker_map:
                local_sp = speaker_map[sp_id]
                # Prefer manually set names
                if sp.get('is_manual') and not local_sp.get('is_manual'):
                    speaker_map[sp_id] = sp
            else:
                speaker_map[sp_id] = sp
        return list(speaker_map.values())

    def _merge_progress(self, local: dict, remote: dict) -> dict:
        """
        Merge progress metadata.

        Takes the most recent sync timestamp.
        """
        local_sync = local.get('last_sync')
        remote_sync = remote.get('last_sync')

        # Determine which is more recent
        if local_sync and remote_sync:
            local_dt = self._parse_timestamp(local_sync)
            remote_dt = self._parse_timestamp(remote_sync)
            if remote_dt and local_dt and remote_dt > local_dt:
                return remote.copy()
        elif remote_sync and not local_sync:
            return remote.copy()

        return local.copy() if local else {}

    def _earliest_timestamp(self, ts1: Optional[str], ts2: Optional[str]) -> Optional[str]:
        """Return the earliest of two timestamps."""
        if not ts1:
            return ts2
        if not ts2:
            return ts1

        dt1 = self._parse_timestamp(ts1)
        dt2 = self._parse_timestamp(ts2)

        if dt1 and dt2:
            return ts1 if dt1 <= dt2 else ts2
        return ts1 or ts2

    def _parse_timestamp(self, ts: str) -> Optional[datetime]:
        """Parse an ISO format timestamp."""
        if not ts:
            return None

        try:
            # Handle various ISO formats
            if ts.endswith('Z'):
                ts = ts[:-1] + '+00:00'
            return datetime.fromisoformat(ts)
        except (ValueError, TypeError):
            return None


def merge_progress_files(local_path: str, remote_path: str, output_path: str) -> dict:
    """
    Convenience function to merge two progress JSON files.

    Args:
        local_path: Path to local project.json
        remote_path: Path to remote project.json
        output_path: Path to write merged result

    Returns:
        Merged data dict
    """
    import json

    with open(local_path, 'r', encoding='utf-8') as f:
        local_data = json.load(f)

    with open(remote_path, 'r', encoding='utf-8') as f:
        remote_data = json.load(f)

    merger = ProgressMerger()
    merged = merger.merge(local_data, remote_data)

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(merged, f, ensure_ascii=False, indent=2)

    return merged
