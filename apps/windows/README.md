# Windows app plan

The Windows version will eventually package the backend and create a desktop UI.

## Current direction

- Python backend as the core engine
- local SQLite database
- optional local model via Ollama
- desktop interface in Tkinter for the MVP

## Packaging ideas

- PyInstaller for a simple executable
- future migration to .NET MAUI or WPF for a richer product

## Local workflow

1. Start the Toxo backend
2. Ask questions in the desktop UI
3. Save relevant knowledge locally
4. Let the assistant remember what matters to the user
