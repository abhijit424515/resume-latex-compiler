# Resume LaTeX Compiler

A Docker-based LaTeX resume compilation system with a simple CLI for building multiple resume variants.

## Features

- 🐳 **Docker-based**: Consistent LaTeX environment across all systems
- 📝 **Multi-project support**: Build multiple resume variants from separate folders
- 🔄 **Auto-rebuild**: Watch mode for automatic rebuilding on file changes
- 🧹 **Clean build artifacts**: Remove temporary files with a single command
- ⚡ **Fast compilation**: Uses `latexmk` with XeLaTeX for efficient builds

## Prerequisites

- Docker installed and running
- (Optional) `fswatch` (macOS) or `inotifywait` (Linux) for watch mode

## Quick Start

1. **Initialize the Docker image:**

```bash
./cli.sh init
```

2. **Build all resumes:**

```bash
./cli.sh build
```

3. **Build a specific resume:**

```bash
./cli.sh build resume_1pg
```

## Commands

### `init`

Build the Docker image with TeXLive and required fonts.

```bash
./cli.sh init
```

### `build [path|all]`

Compile LaTeX files to PDF. Defaults to all folders if no path is specified.

```bash
./cli.sh build              # Build all resumes
./cli.sh build resume_1pg   # Build specific folder
./cli.sh build resume_2pg   # Build specific folder
```

### `watch [path|all]`

Watch for changes to `.tex` files and automatically rebuild. Requires `fswatch` (macOS) or `inotifywait` (Linux).

```bash
./cli.sh watch              # Watch all folders
./cli.sh watch resume_1pg   # Watch specific folder
```

**Install watch tools:**

- macOS: `brew install fswatch`
- Linux: `sudo apt-get install inotify-tools`

### `clean [path|all]`

Remove build artifacts (`.aux`, `.log`, `.pdf`, `.xdv`, etc.). Defaults to all folders.

```bash
./cli.sh clean              # Clean all folders
./cli.sh clean resume_1pg   # Clean specific folder
```

### `help`

Show help message with usage and examples.

```bash
./cli.sh help
```

## Project Structure

```
resume/
├── cli.sh              # Main CLI script
├── Dockerfile          # Docker image configuration
├── .vscode/            # VS Code workspace settings
│   ├── settings.json   # Auto-save on focus change (see note below)
│   └── extensions.json  # Recommended PDF viewer extension
├── resume_1pg/         # One-page resume variant
│   ├── main.tex
│   └── .latexmkrc
├── resume_2pg/         # Two-page resume variant
│   ├── main.tex
│   └── .latexmkrc
└── fonts/              # Custom fonts (optional)
```

> **Note on Auto-Save Setting**: The workspace is configured with `files.autoSave: "onFocusChange"` (saves when you switch tabs/windows, not on a delay). This prevents frequent saves while typing, which would otherwise trigger the compiler repeatedly and slow down your workflow. The compiler will run when you're done editing and switch focus.

## How It Works

1. **Docker Image**: Uses `registry.gitlab.com/islandoftex/images/texlive:latest-full` as the base
2. **Volume Mounting**: The entire project is mounted as a volume for live editing
3. **Font Installation**: Custom fonts from `fonts/` are automatically installed at runtime
4. **Compilation**: Uses `latexmk` with XeLaTeX for robust multi-pass compilation

## Build Artifacts

The following files are generated during compilation and can be cleaned with `./cli.sh clean`:

- `*.aux` - Auxiliary files
- `*.log` - Compilation logs
- `*.pdf` - Output PDF files
- `*.xdv` - XeTeX device-independent files
- `*.fdb_latexmk` - latexmk database
- `*.fls` - File list
- `*.out` - Hyperref output

## Troubleshooting

**Docker not found:**

- Ensure Docker is installed and the daemon is running

**Watch mode not working:**

- Install `fswatch` (macOS) or `inotifywait` (Linux)
- Check that the tools are in your PATH

**Build fails:**

- Check that the Docker image was built: `./cli.sh init`
- Verify your `.tex` files are valid LaTeX
- Check Docker logs for detailed error messages

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
