# Sentence Splitting Design

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Split long transcription utterances (>100 words) into shorter sentences for easier learning.

**Architecture:** A new `SentenceSplitter` service inserted between AssemblyAI transcription and database storage in the processing pipeline. Uses word-level timestamps from AssemblyAI for precise audio alignment. Punctuation-based splitting with fallback to hard word-count splits. New projects only — no migration of existing data.

**Tech Stack:** Python, AssemblyAI SDK (word-level timestamps), existing processor pipeline

---

## Data Flow

```
AssemblyAI transcript
    -> _parse_transcript() returns utterances + word timestamps
    -> SentenceSplitter.split_utterances() splits any >100 words
    -> processor.py stores the (possibly more) sentences to DB
    -> explainer generates explanations per sentence (now shorter)
```

## Splitting Algorithm

For each utterance exceeding `max_words` (default 100):

1. **Split on sentence-ending punctuation** (`. ? !`) — only where followed by a space and uppercase letter (avoids abbreviations like "d.w.z.")
2. **Split remaining long segments on clause boundaries** (`, ; : —`) — pick split point closest to midpoint for balanced halves
3. **Hard split at 100 words** (last resort) — for segments with no punctuation

After text splitting, map each segment back to word-level timestamps from AssemblyAI. Each segment gets `start = first_word.start`, `end = last_word.end`.

## Edge Cases

- **Short segments:** If a split produces a segment <3 words, merge it back with the adjacent segment
- **Dutch abbreviations:** Pattern-match `punctuation + space + uppercase` to avoid splitting on abbreviations
- **Timestamp precision:** Use word-level start/end directly, no rounding needed
- **No splitting needed:** If all utterances <=100 words, splitter returns them unchanged (zero overhead)

## Files to Change

### New: `desktop/app/services/sentence_splitter.py`
- `WordTimestamp` dataclass: `text`, `start`, `end`
- `SentenceSplitter` class with `split_utterances(utterances, max_words=100)` method
- Pure logic, no DB or API dependencies

### Modify: `desktop/app/services/assemblyai_transcriber.py`
- Add `words: List[WordTimestamp]` field to `UtteranceInfo`
- In `_parse_transcript()`, capture `transcript.words` and group by utterance time range
- Each `UtteranceInfo` now carries its word-level timestamps

### Modify: `desktop/app/services/processor.py`
- In `_transcribe_audio()`, pass utterances through `SentenceSplitter.split_utterances()` before creating Sentence records
- `idx` numbering naturally adjusts since we enumerate the split list

### Modify: `desktop/app/config.py`
- Add `max_sentence_words: int = 100` setting

### No changes needed to:
- Mobile code (receives already-split sentences via sync)
- Explainer (processes whatever sentences exist in DB)
- Database schema (no new columns)
- API endpoints
- Frontend
