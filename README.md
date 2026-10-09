# MyPaperHub

MyPaperHub is an offline-first academic paper library for personal use. It lets you:

- import your own PDFs
- search by title, author, DOI, year, and keywords
- view PDFs locally
- query a local AI assistant offline
- store metadata in SQLite with FTS5 search
- keep everything local and internet-free

Legal notice:
This app is for accessing papers you own or have permission to use. You are responsible for ensuring you have the right to add any PDFs.

## Features

- Offline-only app
- SQLite database with FTS5 search
- Local PDF viewer
- Library management to add new PDFs
- Localization: English + Spanish
- Local AI assistant using a bundled LiteRT-LM model
- No internet permission required

## Project structure

- `lib/` — Flutter app source
- `assets/translations/` — localization files
- `assets/models/` — local LLM model files
- `python/prepare_library.py` — PDF ingestion + SQLite DB generation
- `sample_data/` — sample PDFs folder

## Setup

1. Install Flutter 3.22+:
   - https://flutter.dev/docs/get-started/install

2. Install Android Studio / Xcode / desktop toolchain as needed.

3. Clone or create the project:
   - `flutter create mypaperhub`
   - replace the project files with this code

4. Install dependencies:
   - `flutter pub get`

5. Generate localization assets if needed:
   - This project uses `easy_localization` and loads JSON from `assets/translations`.

6. Put your local LLM model into:
   - `assets/models/qwen3_1.7b.tflite`

   If the model is not present, the AI assistant will show a message instead of failing.

## Run locally

Android:
- `flutter run -d android`

Linux:
- `flutter run -d linux`

macOS:
- `flutter run -d macos`

Windows:
- `flutter run -d windows`

## Build release

Android:
- `flutter build apk --release`

iOS:
- `flutter build ios --release`

macOS:
- `flutter build macos --release`

Linux:
- `flutter build linux --release`

Windows:
- `flutter build windows --release`

## Prepare your local paper library

Use the Python script:

```bash
python3 python/prepare_library.py --pdf_dir ./sample_data/papers --output_dir ./output