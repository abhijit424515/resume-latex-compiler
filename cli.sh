#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
DOCKER_IMAGE="latex-compiler"
CONTAINER_NAME="latex-compiler-container"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Function to find all folders with .tex files
find_tex_folders() {
    find "$PROJECT_ROOT" -maxdepth 2 -name "*.tex" -type f | while read -r texfile; do
        dirname "$texfile"
    done | sort -u
}

# Function to build a single folder
build_folder() {
    local folder_path="$1"
    local folder_name=$(basename "$folder_path")
    
    if [ ! -d "$folder_path" ]; then
        print_error "Folder does not exist: $folder_path"
        return 1
    fi
    
    # Find the main .tex file in the folder
    local tex_file=$(find "$folder_path" -maxdepth 1 -name "*.tex" -type f | head -n 1)
    
    if [ -z "$tex_file" ]; then
        print_error "No .tex file found in: $folder_path"
        return 1
    fi
    
    local tex_filename=$(basename "$tex_file")
    
    print_info "Building $folder_name ($tex_filename)..."
    
    # Calculate relative path from project root (pure bash)
    local rel_path="${folder_path#$PROJECT_ROOT}"
    rel_path="${rel_path#/}"  # Remove leading slash if present
    
    # Run docker and filter out harmless xdvipdfmx ToUnicode CMap warnings
    set +e  # Don't exit on pipe failures
    docker run --rm \
        -v "$PROJECT_ROOT:/workspace" \
        -w "/workspace/$rel_path" \
        "$DOCKER_IMAGE" \
        latexmk -xelatex -interaction=nonstopmode "$tex_filename" 2>&1 | grep -v "xdvipdfmx:warning:.*ToUnicode CMap"
    exit_code=${PIPESTATUS[0]}
    set -e  # Re-enable exit on error
    
    if [ $exit_code -eq 0 ]; then
        print_info "Successfully built $folder_name"
    else
        print_error "Failed to build $folder_name"
        return 1
    fi
}

# Function to clean build artifacts from a folder
clean_folder() {
    local folder_path="$1"
    local folder_name=$(basename "$folder_path")
    
    if [ ! -d "$folder_path" ]; then
        print_error "Folder does not exist: $folder_path"
        return 1
    fi
    
    print_info "Cleaning build artifacts in $folder_name..."
    
    # Remove LaTeX build artifacts using find
    local artifacts_removed=0
    local temp_file=$(mktemp)
    
    # Use find to locate build artifacts
    find "$folder_path" -maxdepth 1 \( \
        -name "*.aux" \
        -o -name "*.fdb_latexmk" \
        -o -name "*.fls" \
        -o -name "*.log" \
        -o -name "*.out" \
        -o -name "*.pdf" \
        -o -name "*.xdv" \
    \) -type f > "$temp_file" 2>/dev/null
    
    # Remove files found
    if [ -s "$temp_file" ]; then
        while IFS= read -r file; do
            if [ -f "$file" ]; then
                rm -f "$file" && artifacts_removed=1
            fi
        done < "$temp_file"
    fi
    
    rm -f "$temp_file"
    
    if [ $artifacts_removed -eq 0 ]; then
        print_info "No build artifacts found in $folder_name"
    else
        print_info "Successfully cleaned $folder_name"
    fi
}

# Function to show help message
show_help() {
    echo "Resume LaTeX Compiler CLI"
    echo ""
    echo "Usage: $0 {init|build|watch|clean|help} [path|all]"
    echo ""
    echo "Commands:"
    echo "  init                          Build the Docker image"
    echo "  build [path|all]              Build LaTeX files in specified folder (default: all)"
    echo "  watch [path|all]              Watch for changes and rebuild automatically (default: all)"
    echo "  clean [path|all]              Remove build artifacts (.aux, .log, .pdf, etc.) (default: all)"
    echo "  help                          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 init                      Build Docker image"
    echo "  $0 build                      Build all resumes"
    echo "  $0 build resume_1pg           Build resume_1pg only"
    echo "  $0 watch                      Watch all folders for changes"
    echo "  $0 watch resume_2pg           Watch resume_2pg for changes"
    echo "  $0 clean                      Clean all build artifacts"
    echo "  $0 clean resume_1pg           Clean build artifacts in resume_1pg"
    echo ""
    echo "Note: For 'watch' command, you need fswatch (macOS) or inotifywait (Linux)"
}

# Function to watch a folder for changes
watch_folder() {
    local folder_path="$1"
    local folder_name=$(basename "$folder_path")
    
    if [ ! -d "$folder_path" ]; then
        print_error "Folder does not exist: $folder_path"
        return 1
    fi
    
    print_info "Watching $folder_name for changes..."
    print_warn "Press Ctrl+C to stop watching"
    
    # Check if fswatch is available (macOS) or inotifywait (Linux)
    if command -v fswatch &> /dev/null; then
        fswatch -r "$folder_path" \
            --include='.*\.tex$' \
            --exclude='.*/\.git/.*' | while read -r changed_file; do
            # Filter out .git directories and non-.tex files
            if [ -f "$changed_file" ] && [[ "$changed_file" == *.tex ]] && [[ "$changed_file" != */.git/* ]]; then
                print_info "Change detected in $folder_name, rebuilding..."
                build_folder "$folder_path" || true
            fi
        done
    elif command -v inotifywait &> /dev/null; then
        while true; do
            changed_file=$(inotifywait -r -e modify,create,delete \
                --exclude '\.(git|aux|log|pdf|xdv|fdb_latexmk|fls|out)' \
                --format '%w%f' \
                "$folder_path" 2>/dev/null | grep '\.tex$')
            if [ -n "$changed_file" ] && [ -f "$changed_file" ]; then
                print_info "Change detected in $folder_name, rebuilding..."
                build_folder "$folder_path" || true
            fi
        done
    else
        print_error "Neither fswatch (macOS) nor inotifywait (Linux) is installed."
        print_error "Please install one of them to use the watch feature."
        print_error "macOS: brew install fswatch"
        print_error "Linux: sudo apt-get install inotify-tools"
        return 1
    fi
}

# Main command handler
case "${1:-}" in
    init)
        print_info "Building Docker image: $DOCKER_IMAGE"
        docker build -t "$DOCKER_IMAGE" "$PROJECT_ROOT"
        if [ $? -eq 0 ]; then
            print_info "Docker image built successfully!"
        else
            print_error "Failed to build Docker image"
            exit 1
        fi
        ;;
    
    build)
        if [ -z "${2:-}" ] || [ "${2:-}" = "all" ]; then
            print_info "Building all folders with .tex files..."
            folders=$(find_tex_folders)
            if [ -z "$folders" ]; then
                print_error "No folders with .tex files found"
                exit 1
            fi
            
            for folder in $folders; do
                build_folder "$folder" || true
            done
        else
            # Build specific folder
            folder_path="${2}"
            # Handle both absolute and relative paths
            if [ ! -d "$folder_path" ]; then
                folder_path="$PROJECT_ROOT/$folder_path"
            fi
            folder_path=$(realpath "$folder_path")
            
            if [[ "$folder_path" != "$PROJECT_ROOT"* ]]; then
                print_error "Folder must be within project root: $PROJECT_ROOT"
                exit 1
            fi
            
            build_folder "$folder_path"
        fi
        ;;
    
    watch)
        if [ -z "${2:-}" ] || [ "${2:-}" = "all" ]; then
            print_info "Building all folders with .tex files before watching..."
            folders=$(find_tex_folders)
            if [ -z "$folders" ]; then
                print_error "No folders with .tex files found"
                exit 1
            fi
            
            # Build all folders first
            for folder in $folders; do
                build_folder "$folder" || true
            done
            
            print_info "Watching all folders with .tex files..."
            print_warn "Watching entire project for .tex file changes..."
            print_warn "Press Ctrl+C to stop watching"
            
            if command -v fswatch &> /dev/null; then
                # Watch all .tex files recursively, excluding .git and build artifacts
                fswatch -r "$PROJECT_ROOT" \
                    --include='.*\.tex$' \
                    --exclude='.*/\.git/.*' | while read -r changed_file; do
                    # Filter out .git directories and non-.tex files
                    if [ -f "$changed_file" ] && [[ "$changed_file" == *.tex ]] && [[ "$changed_file" != */.git/* ]]; then
                        folder=$(dirname "$changed_file")
                        folder_name=$(basename "$folder")
                        print_info "Change detected in $folder_name, rebuilding..."
                        build_folder "$folder" || true
                    fi
                done
            elif command -v inotifywait &> /dev/null; then
                while true; do
                    changed_file=$(inotifywait -r -e modify,create,delete \
                        --exclude '\.(git|aux|log|pdf|xdv|fdb_latexmk|fls|out)' \
                        --format '%w%f' \
                        "$PROJECT_ROOT" 2>/dev/null | grep '\.tex$')
                    if [ -n "$changed_file" ] && [ -f "$changed_file" ]; then
                        folder=$(dirname "$changed_file")
                        folder_name=$(basename "$folder")
                        print_info "Change detected in $folder_name, rebuilding..."
                        build_folder "$folder" || true
                    fi
                done
            else
                print_error "Neither fswatch (macOS) nor inotifywait (Linux) is installed."
                print_error "Please install one of them to use the watch feature."
                exit 1
            fi
        else
            # Watch specific folder
            folder_path="${2}"
            # Handle both absolute and relative paths
            if [ ! -d "$folder_path" ]; then
                folder_path="$PROJECT_ROOT/$folder_path"
            fi
            folder_path=$(realpath "$folder_path")
            
            if [[ "$folder_path" != "$PROJECT_ROOT"* ]]; then
                print_error "Folder must be within project root: $PROJECT_ROOT"
                exit 1
            fi
            
            # Build folder first before watching
            print_info "Building folder before watching..."
            build_folder "$folder_path" || true
            
            watch_folder "$folder_path"
        fi
        ;;
    
    clean)
        if [ -z "${2:-}" ] || [ "${2:-}" = "all" ]; then
            print_info "Cleaning all folders with .tex files..."
            folders=$(find_tex_folders)
            if [ -z "$folders" ]; then
                print_error "No folders with .tex files found"
                exit 1
            fi
            
            for folder in $folders; do
                clean_folder "$folder" || true
            done
        else
            # Clean specific folder
            folder_path="${2}"
            # Handle both absolute and relative paths
            if [ ! -d "$folder_path" ]; then
                folder_path="$PROJECT_ROOT/$folder_path"
            fi
            folder_path=$(realpath "$folder_path")
            
            if [[ "$folder_path" != "$PROJECT_ROOT"* ]]; then
                print_error "Folder must be within project root: $PROJECT_ROOT"
                exit 1
            fi
            
            clean_folder "$folder_path"
        fi
        ;;
    
    help|--help|-h)
        show_help
        ;;
    
    *)
        print_error "Unknown command: ${1:-}"
        echo ""
        show_help
        exit 1
        ;;
esac

