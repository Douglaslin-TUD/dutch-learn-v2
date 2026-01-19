# User Stories
# Dutch Language Learning Mobile App

**Document Version:** 1.0
**Date:** 2025-12-31

---

## Overview

This document contains all user stories for the Dutch Language Learning mobile app, organized by feature area. Each story follows the standard format and includes detailed acceptance criteria for development and testing.

**Priority Legend:**
- **P0**: Must have for MVP
- **P1**: Should have for MVP
- **P2**: Nice to have, can be deferred

---

## 1. Google Drive Integration

### US-01: Connect to Google Drive
**Priority:** P0

**As a** Dutch learner
**I want to** connect my Google Drive account to the app
**So that** I can access my exported project files

### Acceptance Criteria:
- [ ] App displays "Connect to Google Drive" button on first launch or when not connected
- [ ] Tapping button opens Google OAuth consent screen
- [ ] User can select/confirm their Google account
- [ ] App requests only Google Drive read permission (drive.readonly scope)
- [ ] Successful authentication returns to app with confirmation message
- [ ] Connection status is persisted across app restarts
- [ ] If authentication fails, error message is shown with retry option

**Technical Notes:**
- Use `google_sign_in` and `googleapis` packages
- Store OAuth tokens using `flutter_secure_storage`
- Handle token refresh automatically

---

### US-02: Browse Google Drive Files
**Priority:** P0

**As a** Dutch learner
**I want to** browse my Google Drive folders and files
**So that** I can find and select project files to import

### Acceptance Criteria:
- [ ] App displays root folder contents after connection
- [ ] Each item shows: file/folder name, type icon, size (for files), modified date
- [ ] Tapping a folder navigates into it
- [ ] Back button/gesture returns to parent folder
- [ ] Breadcrumb trail shows current path
- [ ] Files are filtered to show only .json and .mp3 files
- [ ] Pull-to-refresh reloads current folder contents
- [ ] Empty folder shows appropriate message

---

### US-03: Download Project Files
**Priority:** P0

**As a** Dutch learner
**I want to** download JSON and MP3 files from Google Drive
**So that** I can import projects for offline study

### Acceptance Criteria:
- [ ] User can select a JSON file and tap "Download"
- [ ] User can select an MP3 file and tap "Download"
- [ ] Download progress is shown (percentage and bytes)
- [ ] Downloads can proceed concurrently
- [ ] Network interruption shows error with retry option
- [ ] Completed downloads are confirmed with success message
- [ ] Downloaded files are stored in app-private storage
- [ ] Large files (>100MB) show warning about storage space

---

### US-04: Disconnect from Google Drive
**Priority:** P2

**As a** Dutch learner
**I want to** disconnect my Google Drive account
**So that** I can use a different account or protect my privacy

### Acceptance Criteria:
- [ ] Settings screen shows "Disconnect Google Drive" option
- [ ] Confirmation dialog warns that connection will be removed
- [ ] Disconnecting clears OAuth tokens
- [ ] Local projects and audio files are NOT deleted
- [ ] App returns to "Connect to Google Drive" state
- [ ] User can reconnect with same or different account

---

## 2. Data Import and Storage

### US-05: Import Project from JSON
**Priority:** P0

**As a** Dutch learner
**I want to** import a downloaded JSON file into the app
**So that** the project data is stored locally for study

### Acceptance Criteria:
- [ ] After JSON download, app prompts "Import this project?"
- [ ] Import validates JSON format matches v1.0 schema
- [ ] Invalid JSON shows specific error message
- [ ] Import creates project record with: id, name, status, sentence count, import date
- [ ] Import creates sentence records with all fields
- [ ] Import creates keyword records linked to sentences
- [ ] Import progress is shown for large projects (100+ sentences)
- [ ] Successful import shows confirmation with project name
- [ ] Import handles UTF-8 characters correctly (Dutch special characters)

---

### US-06: Link Audio File to Project
**Priority:** P0

**As a** Dutch learner
**I want to** associate an MP3 file with an imported project
**So that** I can play audio during study

### Acceptance Criteria:
- [ ] After project import, app prompts to select matching MP3
- [ ] MP3 selection screen shows downloaded audio files
- [ ] Selected MP3 is copied to project-specific storage location
- [ ] Project record is updated with audio file path
- [ ] If no MP3 is selected, project still works (text-only mode)
- [ ] MP3 can be added/changed later from project settings
- [ ] File size is displayed to help identify correct MP3

---

### US-07: Detect Duplicate Projects
**Priority:** P1

**As a** Dutch learner
**I want to** be warned if I try to import a project that already exists
**So that** I don't accidentally create duplicates

### Acceptance Criteria:
- [ ] Before import, app checks if project ID already exists
- [ ] If duplicate found, dialog shows options:
  - "Skip" - cancel import
  - "Replace" - delete existing and import new
  - "Import as new" - create with new ID (rare use case)
- [ ] Default action is "Skip" for safety
- [ ] Replaced project's audio file is also deleted

---

## 3. Project Management

### US-08: View Project List
**Priority:** P0

**As a** Dutch learner
**I want to** see a list of all my imported projects
**So that** I can choose which one to study

### Acceptance Criteria:
- [ ] Home screen displays list of imported projects
- [ ] Each project card shows: name, sentence count, import date
- [ ] Projects with audio show audio indicator icon
- [ ] Tapping a project opens the learning screen
- [ ] Empty state shows "No projects - connect to Google Drive to import"
- [ ] List scrolls smoothly with 50+ projects
- [ ] Last studied project is visually indicated

---

### US-09: Delete Project
**Priority:** P0

**As a** Dutch learner
**I want to** delete a project I no longer need
**So that** I can free up storage space

### Acceptance Criteria:
- [ ] Long-press or swipe on project shows delete option
- [ ] Confirmation dialog: "Delete [Project Name]? This will remove all sentences and audio."
- [ ] Confirming deletes: project record, all sentences, all keywords, audio file
- [ ] Cancelled deletion keeps project intact
- [ ] Deleted project disappears from list immediately
- [ ] Storage space is reclaimed (verify audio file deleted)

---

### US-10: View Project Details
**Priority:** P1

**As a** Dutch learner
**I want to** see detailed information about a project
**So that** I can understand its scope before studying

### Acceptance Criteria:
- [ ] Project detail screen accessible via info button or menu
- [ ] Details shown: name, sentence count, total audio duration (if available)
- [ ] Details shown: import date, source file name (from JSON)
- [ ] Details shown: storage used (JSON + audio size)
- [ ] Option to re-link different MP3 file
- [ ] Option to delete project from details screen

---

### US-11: Sort and Search Projects
**Priority:** P2

**As a** Dutch learner
**I want to** sort and search my project list
**So that** I can quickly find the project I want

### Acceptance Criteria:
- [ ] Sort options: by name (A-Z, Z-A), by import date (newest, oldest)
- [ ] Default sort is by import date (newest first)
- [ ] Sort preference is saved across sessions
- [ ] Search bar filters projects by name
- [ ] Search is case-insensitive
- [ ] Search results update as user types (debounced)
- [ ] Clear search button resets to full list

---

## 4. Audio Playback

### US-12: Play Sentence Audio
**Priority:** P0

**As a** Dutch learner
**I want to** play the audio for the current sentence
**So that** I can hear proper Dutch pronunciation

### Acceptance Criteria:
- [ ] Play button starts audio from current sentence's start_time
- [ ] Audio plays through current sentence (until end_time)
- [ ] Pause button stops playback at current position
- [ ] Resume continues from paused position
- [ ] Play/pause button toggles appropriately
- [ ] If no audio file linked, play button is disabled with tooltip
- [ ] Audio plays through device speaker or connected headphones

---

### US-13: Auto-Advance to Next Sentence
**Priority:** P0

**As a** Dutch learner
**I want to** have the display auto-advance when a sentence ends
**So that** I can follow along without manual navigation

### Acceptance Criteria:
- [ ] When audio reaches current sentence's end_time, display advances
- [ ] Next sentence becomes current and is highlighted
- [ ] Playback continues seamlessly into next sentence
- [ ] At last sentence, playback stops (does not loop to first)
- [ ] Auto-advance can be disabled in settings (for manual mode)
- [ ] Visual transition is smooth (no jarring jumps)

---

### US-14: Loop Current Sentence
**Priority:** P0

**As a** Dutch learner
**I want to** loop the current sentence repeatedly
**So that** I can practice difficult pronunciations

### Acceptance Criteria:
- [ ] Loop toggle button available on playback controls
- [ ] When loop is ON, audio repeats from start_time to end_time
- [ ] Loop continues until user disables or navigates away
- [ ] Loop indicator is clearly visible when active
- [ ] Small pause (0.5s) between loop iterations for clarity
- [ ] Navigating to different sentence disables loop
- [ ] Loop state is NOT persisted (resets each session)

---

### US-15: Control Playback Speed
**Priority:** P0

**As a** Dutch learner
**I want to** adjust the audio playback speed
**So that** I can slow down for difficult content or speed up for review

### Acceptance Criteria:
- [ ] Speed control accessible from playback controls
- [ ] Speed options: 0.5x, 0.75x, 1.0x, 1.25x, 1.5x
- [ ] Default speed is 1.0x
- [ ] Speed change applies immediately to current playback
- [ ] Speed setting is persisted per session
- [ ] Speed indicator shows current setting (e.g., "0.75x")
- [ ] Audio pitch is preserved at different speeds (not chipmunk effect)

---

### US-16: Seek Within Audio
**Priority:** P1

**As a** Dutch learner
**I want to** seek to any position in the audio
**So that** I can replay specific parts

### Acceptance Criteria:
- [ ] Progress bar shows current position and total duration
- [ ] Dragging progress bar seeks to that position
- [ ] Seeking updates current sentence based on position
- [ ] Tapping on progress bar jumps to that position
- [ ] Seek is accurate within 200ms
- [ ] While seeking, position updates in real-time

---

### US-17: Background Audio Playback
**Priority:** P1

**As a** Dutch learner
**I want to** continue listening when the screen is off or app is backgrounded
**So that** I can listen while multitasking

### Acceptance Criteria:
- [ ] Audio continues when device screen turns off
- [ ] Audio continues when app is moved to background
- [ ] Notification shows current project and playback controls
- [ ] Notification controls: play/pause, previous, next
- [ ] Returning to app shows current playback state
- [ ] Battery optimization warning if applicable

---

### US-18: Hardware Media Button Support
**Priority:** P1

**As a** Dutch learner
**I want to** control playback with physical or Bluetooth buttons
**So that** I can control audio without looking at my phone

### Acceptance Criteria:
- [ ] Play/pause button toggles playback
- [ ] Next button advances to next sentence
- [ ] Previous button goes to previous sentence
- [ ] Works with wired headphone buttons
- [ ] Works with Bluetooth headphone/earphone buttons
- [ ] Works with car Bluetooth systems

---

### US-19: Remember Playback Position
**Priority:** P1

**As a** Dutch learner
**I want to** resume from where I left off
**So that** I don't lose my place when I close the app

### Acceptance Criteria:
- [ ] Last played sentence index is saved per project
- [ ] Opening a project resumes at last sentence
- [ ] Option to "Start from beginning" available
- [ ] Position is saved when navigating away or closing app
- [ ] Position is saved on app crash (if possible)

---

## 5. Learning Interface

### US-20: View Current Sentence
**Priority:** P0

**As a** Dutch learner
**I want to** see the current Dutch sentence prominently displayed
**So that** I can read along with the audio

### Acceptance Criteria:
- [ ] Dutch sentence is displayed in large, readable font (18sp minimum)
- [ ] Font supports Dutch characters (ij, special accents)
- [ ] Sentence wraps appropriately on screen width
- [ ] Sentence area is visually distinct from other content
- [ ] Long sentences are fully visible (scrollable if needed)
- [ ] Current sentence is highlighted when audio is playing

---

### US-21: View Translation
**Priority:** P0

**As a** Dutch learner
**I want to** see the English translation of the current sentence
**So that** I can understand the meaning

### Acceptance Criteria:
- [ ] English translation displayed below Dutch sentence
- [ ] Translation font is slightly smaller than Dutch (16sp)
- [ ] Translation is clearly labeled or visually distinct
- [ ] Translation is visible by default (not hidden)
- [ ] Option to hide/show translation available (for testing self)
- [ ] Hidden state is indicated visually

---

### US-22: View Explanations
**Priority:** P0

**As a** Dutch learner
**I want to** see explanations in Dutch and English
**So that** I can understand grammar and usage

### Acceptance Criteria:
- [ ] Dutch explanation displayed in expandable section
- [ ] English explanation displayed in separate expandable section
- [ ] Sections are collapsed by default (to reduce clutter)
- [ ] Tapping header expands/collapses section
- [ ] Expanded state shows full explanation text
- [ ] Explanations support multiple paragraphs if present
- [ ] Empty explanations show "No explanation available"

---

### US-23: Navigate Between Sentences
**Priority:** P0

**As a** Dutch learner
**I want to** navigate to previous or next sentences
**So that** I can study at my own pace

### Acceptance Criteria:
- [ ] Previous button moves to preceding sentence
- [ ] Next button moves to following sentence
- [ ] At first sentence, previous button is disabled
- [ ] At last sentence, next button is disabled (or shows completion)
- [ ] Navigation updates audio position (seeks to new sentence)
- [ ] Navigation is instant (no loading delay for local data)
- [ ] Current sentence index displayed (e.g., "15 / 810")

---

### US-24: Swipe Navigation
**Priority:** P2

**As a** Dutch learner
**I want to** swipe left/right to navigate sentences
**So that** I can navigate quickly with gestures

### Acceptance Criteria:
- [ ] Swipe left moves to next sentence
- [ ] Swipe right moves to previous sentence
- [ ] Swipe gesture has appropriate threshold (not too sensitive)
- [ ] Visual feedback during swipe (card animation)
- [ ] Same boundary behavior as button navigation
- [ ] Can be disabled in settings (for accessibility)

---

### US-25: View Sentence List
**Priority:** P1

**As a** Dutch learner
**I want to** see a list of all sentences and jump to any one
**So that** I can quickly navigate to specific content

### Acceptance Criteria:
- [ ] List button opens sentence overview screen
- [ ] Each item shows: index, first 50 characters of Dutch text
- [ ] Current sentence is highlighted in list
- [ ] Tapping a sentence returns to learning screen at that sentence
- [ ] List scrolls smoothly with 1000+ sentences
- [ ] List maintains scroll position if reopened
- [ ] Search/filter option for finding specific sentences

---

## 6. Vocabulary Features

### US-26: Tap Word for Definition
**Priority:** P0

**As a** Dutch learner
**I want to** tap on a word to see its definition
**So that** I can learn vocabulary in context

### Acceptance Criteria:
- [ ] Tapping a word in the Dutch sentence shows popup
- [ ] Popup displays if word matches a keyword for current sentence
- [ ] Popup shows: word, Dutch meaning (meaning_nl), English meaning (meaning_en)
- [ ] Popup appears near tapped word (not blocking it)
- [ ] Tapping outside popup or X button closes it
- [ ] If word has no definition, popup shows "No definition available" or no popup
- [ ] Word matching is case-insensitive

---

### US-27: Highlight Defined Words
**Priority:** P1

**As a** Dutch learner
**I want to** see which words have definitions available
**So that** I know what I can tap to learn more

### Acceptance Criteria:
- [ ] Words that match keywords are visually highlighted
- [ ] Highlight style: underline or subtle background color
- [ ] Highlight is unobtrusive (doesn't distract from reading)
- [ ] Highlighting can be toggled on/off in settings
- [ ] Default is ON

---

### US-28: View Keywords List
**Priority:** P1

**As a** Dutch learner
**I want to** see all keywords for the current sentence
**So that** I can study vocabulary systematically

### Acceptance Criteria:
- [ ] Keywords section displayed below explanations
- [ ] Each keyword shows: word, Dutch meaning, English meaning
- [ ] Keywords are collapsible (like explanations)
- [ ] Empty keywords shows "No vocabulary for this sentence"
- [ ] Tapping a keyword could highlight it in sentence (nice to have)

---

### US-29: Browse Project Vocabulary
**Priority:** P2

**As a** Dutch learner
**I want to** browse all vocabulary from a project
**So that** I can review words outside of sentence context

### Acceptance Criteria:
- [ ] Vocabulary list accessible from project menu
- [ ] Shows all unique keywords across all sentences
- [ ] List is sorted alphabetically by Dutch word
- [ ] Each item shows: word, English meaning (meaning_en)
- [ ] Tapping word shows full details (both meanings)
- [ ] Option to jump to first sentence containing that word
- [ ] Search/filter by word

---

### US-30: Search All Vocabulary
**Priority:** P2

**As a** Dutch learner
**I want to** search vocabulary across all projects
**So that** I can find words I've encountered before

### Acceptance Criteria:
- [ ] Global vocabulary search accessible from main menu
- [ ] Search matches Dutch word or English meaning
- [ ] Results show: word, meaning, source project name
- [ ] Tapping result navigates to that sentence in that project
- [ ] Search is performant with 10,000+ vocabulary items
- [ ] Recent searches are remembered

---

## 7. Settings and Preferences

### US-31: Configure Display Settings
**Priority:** P2

**As a** Dutch learner
**I want to** customize the display appearance
**So that** the app is comfortable for extended study

### Acceptance Criteria:
- [ ] Font size options: Small, Medium (default), Large, Extra Large
- [ ] Theme options: Light (default), Dark, System
- [ ] Translation visibility default: Shown/Hidden
- [ ] Settings are persisted across sessions
- [ ] Changes apply immediately (no restart required)

---

### US-32: Configure Audio Settings
**Priority:** P2

**As a** Dutch learner
**I want to** customize audio behavior
**So that** playback suits my study style

### Acceptance Criteria:
- [ ] Auto-advance toggle: ON (default) / OFF
- [ ] Default playback speed setting
- [ ] Background playback toggle: ON (default) / OFF
- [ ] Settings are persisted across sessions

---

### US-33: View Storage Usage
**Priority:** P2

**As a** Dutch learner
**I want to** see how much storage the app is using
**So that** I can manage my device space

### Acceptance Criteria:
- [ ] Settings shows total app storage usage
- [ ] Breakdown by: Database, Audio files, Cache
- [ ] Individual project sizes visible in project list/details
- [ ] "Clear cache" option if applicable
- [ ] Storage values update after project deletion

---

## 8. Error Handling and Edge Cases

### US-34: Handle Missing Audio Gracefully
**Priority:** P1

**As a** Dutch learner
**I want to** use the app even without audio files
**So that** I can still study text content

### Acceptance Criteria:
- [ ] Projects without audio show "No audio" indicator
- [ ] Playback controls are disabled but visible
- [ ] Tooltip explains how to add audio
- [ ] All text features work normally
- [ ] Navigation works normally (based on sentence index)

---

### US-35: Handle Corrupted Data
**Priority:** P1

**As a** Dutch learner
**I want to** be informed if project data is corrupted
**So that** I can re-import or seek help

### Acceptance Criteria:
- [ ] Import validates JSON structure before saving
- [ ] Invalid JSON shows specific error: "Invalid format" or "Missing fields"
- [ ] Corrupted audio file detected on first play attempt
- [ ] Corrupted audio shows error with option to re-link different file
- [ ] Database errors show user-friendly message with retry option

---

### US-36: Handle Low Storage
**Priority:** P2

**As a** Dutch learner
**I want to** be warned before storage becomes full
**So that** I can manage space proactively

### Acceptance Criteria:
- [ ] Before download, check available storage space
- [ ] If insufficient space, warn user before download starts
- [ ] Suggest deleting old projects to free space
- [ ] Show size of file to be downloaded
- [ ] Handle "storage full" error gracefully during download

---

## 9. Accessibility

### US-37: Support Screen Readers
**Priority:** P2

**As a** Dutch learner with visual impairment
**I want to** use the app with TalkBack
**So that** I can access the learning content

### Acceptance Criteria:
- [ ] All interactive elements have semantic labels
- [ ] Dutch text is announced with Dutch language hint
- [ ] Playback controls are accessible
- [ ] Navigation is possible with gestures
- [ ] Custom actions for common operations

---

### US-38: Support Large Text
**Priority:** P1

**As a** Dutch learner with visual needs
**I want to** use system font scaling
**So that** text is readable for me

### Acceptance Criteria:
- [ ] App respects system font size settings
- [ ] Layout adapts to larger fonts without breaking
- [ ] Minimum touch target size: 48dp
- [ ] No text truncation at largest font settings (use scrolling)

---

## Appendix: Story Map

```
                    EPIC                          MVP    v1.1
                      |                            |      |
   +------------------+------------------+         |      |
   |                  |                  |         |      |
Google Drive     Import/Store       Study         |      |
   |                  |                  |         |      |
   +--US-01           +--US-05           +--US-12  |      |
   +--US-02           +--US-06           +--US-13  |      |
   +--US-03           +--US-07           +--US-14  |      |
   +--US-04           +--US-08           +--US-15  |      |
                      +--US-09           +--US-16  |      |
                      +--US-10           +--US-20  |      |
                      +--US-11           +--US-21  |      |
                                         +--US-22  |      |
                                         +--US-23  |      |
                                         +--US-26  |      |
                                                   |      |
   Audio Advanced    Vocabulary Adv    Settings   |      |
   |                  |                  |         |      |
   +--US-17           +--US-27           +--US-31  |      |
   +--US-18           +--US-28           +--US-32  |      |
   +--US-19           +--US-29           +--US-33  |      |
                      +--US-30                     |      |
```

---

**Document Control**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-12-31 | Requirements Analyst | Initial user stories |
