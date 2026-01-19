# Dutch Language Learning Application

A web application that enables Dutch language learners to study from audio/video content by providing interactive transcriptions with explanations and vocabulary.

## Features

- **File Upload**: Upload audio files (MP3, WAV, M4A, FLAC) or video files (MP4, MKV, AVI, WebM, MOV)
- **Automatic Transcription**: Transcribe Dutch audio using OpenAI Whisper API with word-level timestamps
- **AI-Powered Explanations**: Generate Dutch and English explanations for each sentence using GPT
- **Vocabulary Extraction**: Automatically extract key vocabulary words with meanings in Dutch and English
- **Interactive Audio Player**: 
  - Click on any sentence to play that specific segment
  - Adjustable playback speed (0.5x to 1.5x)
  - Loop mode for repeating sentences
  - Keyboard shortcuts for navigation
- **Project Management**: Create, view, and delete learning projects
- **Responsive Design**: Works on desktop, tablet, and mobile devices

## Prerequisites

Before running this application, ensure you have:

1. **Python 3.10 or higher**
   ```bash
   python3 --version
   ```

2. **FFmpeg** (for audio extraction from video files)
   ```bash
   # Ubuntu/Debian
   sudo apt install ffmpeg
   
   # macOS
   brew install ffmpeg
   
   # Windows
   # Download from https://ffmpeg.org/download.html
   ```

3. **OpenAI API Key**
   - Sign up at https://platform.openai.com/
   - Create an API key at https://platform.openai.com/api-keys

## Installation

1. **Clone or download this repository**
   ```bash
   cd "/data/AI  Tools/Audio for Dutch Learn"
   ```

2. **Create a virtual environment**
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # Linux/macOS
   # or
   venv\Scripts\activate     # Windows
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Configure environment variables**
   ```bash
   cp .env.example .env
   ```
   
   Edit `.env` and add your OpenAI API key:
   ```
   OPENAI_API_KEY=your_actual_api_key_here
   ```

## Configuration

The application can be configured via the `.env` file:

| Variable | Description | Default |
|----------|-------------|---------|
| `OPENAI_API_KEY` | Your OpenAI API key (required) | - |
| `APP_HOST` | Server host address | `0.0.0.0` |
| `APP_PORT` | Server port | `8000` |
| `DEBUG` | Enable debug mode | `true` |
| `DATABASE_URL` | SQLite database path | `sqlite:///./data/dutch_learning.db` |
| `MAX_FILE_SIZE` | Maximum upload size in bytes | `524288000` (500MB) |
| `WHISPER_MODEL` | OpenAI Whisper model | `whisper-1` |
| `GPT_MODEL` | OpenAI GPT model | `gpt-4o-mini` |

## Usage

1. **Start the application**
   ```bash
   python run.py
   ```

2. **Open your browser** and navigate to:
   ```
   http://localhost:8000
   ```

3. **Upload a file**:
   - Click "New Project" or drag and drop a file
   - Wait for processing (typically 2-5 minutes)

4. **Start learning**:
   - Click on any sentence to play its audio
   - View explanations and vocabulary on the right panel
   - Use keyboard shortcuts for navigation

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Space` | Play/Pause |
| `L` | Toggle loop mode |
| `Arrow Up` | Previous sentence |
| `Arrow Down` | Next sentence |
| `[` | Decrease speed |
| `]` | Increase speed |

## API Documentation

Once the application is running, access the interactive API documentation at:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

### Key Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/projects` | List all projects |
| `POST` | `/api/projects` | Upload new project |
| `GET` | `/api/projects/{id}` | Get project details with sentences |
| `DELETE` | `/api/projects/{id}` | Delete a project |
| `GET` | `/api/projects/{id}/status` | Get processing status |
| `GET` | `/api/audio/{project_id}` | Stream project audio |

## Project Structure

```
/data/AI  Tools/Audio for Dutch Learn/
├── app/
│   ├── main.py           # FastAPI application entry point
│   ├── config.py         # Configuration management
│   ├── database.py       # Database setup and session management
│   ├── models/           # SQLAlchemy database models
│   ├── routers/          # API route handlers
│   ├── services/         # Business logic (audio, transcription, etc.)
│   └── utils/            # Utility functions
├── static/
│   ├── index.html        # Single-page application HTML
│   ├── css/style.css     # Custom styles (extends Tailwind)
│   └── js/               # JavaScript modules
├── data/
│   ├── uploads/          # Uploaded files
│   ├── audio/            # Extracted audio files
│   └── dutch_learning.db # SQLite database
├── docs/                 # Documentation
├── .env                  # Environment configuration
├── requirements.txt      # Python dependencies
└── run.py               # Application runner
```

## Troubleshooting

### FFmpeg not found
```
AudioExtractionError: FFmpeg not found. Please install FFmpeg and ensure it's in PATH.
```
**Solution**: Install FFmpeg and ensure it's in your system PATH.

### OpenAI API key not configured
```
TranscriptionError: OpenAI API key not configured. Set OPENAI_API_KEY in .env file.
```
**Solution**: Add your API key to the `.env` file.

### File too large
```
File too large: XXX MB. Maximum size: 500MB
```
**Solution**: The Whisper API has a 25MB limit. For larger files, the application extracts and compresses audio automatically.

### Audio file too large for Whisper API
```
Audio file too large for Whisper API: XX.X MB (max: 25MB).
```
**Solution**: Try using a shorter audio/video file, or manually split the audio.

### Processing stuck or failed
- Check the project status on the home page
- View error details by clicking on the project
- Check terminal/console for detailed error messages
- Verify your OpenAI API key has sufficient credits

## Technology Stack

- **Backend**: Python 3.10+, FastAPI, SQLAlchemy, SQLite
- **Frontend**: HTML5, Tailwind CSS, Vanilla JavaScript
- **APIs**: OpenAI Whisper (transcription), OpenAI GPT (explanations)
- **Audio Processing**: FFmpeg

## Development

### Running in development mode
```bash
DEBUG=true python run.py
```

### Database
The SQLite database is automatically created on first run at `data/dutch_learning.db`.

## License

This project is for personal educational use.

## Acknowledgments

- [OpenAI](https://openai.com/) for Whisper and GPT APIs
- [FastAPI](https://fastapi.tiangolo.com/) for the excellent Python web framework
- [Tailwind CSS](https://tailwindcss.com/) for utility-first CSS
