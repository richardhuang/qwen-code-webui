#!/bin/bash

# ============================================
# Qwen Code Web UI - Export Docker Image
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default values
IMAGE_NAME="qwen-code-webui"
OUTPUT_DIR=""
VERSION=""
BUILD_IMAGE=false
PROJECT_DIR=""
PLATFORM="linux/amd64"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -b|--build)
            BUILD_IMAGE=true
            shift
            ;;
        -d|--dir)
            PROJECT_DIR="$2"
            shift 2
            ;;
        -p|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Export Docker image to a tar file for offline deployment."
            echo ""
            echo "Options:"
            echo "  -o, --output <dir>   Output directory (default: current directory)"
            echo "  -v, --version <ver>  Version tag to include in filename"
            echo "  -b, --build          Build image before exporting"
            echo "  -p, --platform <plt> Target platform (default: linux/amd64)"
            echo "  -d, --dir <dir>      Project directory (default: parent of script directory)"
            echo "  -h, --help           Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                              # Export existing image to current directory"
            echo "  $0 -b                           # Build and export (native platform)"
            echo "  $0 -b -p linux/amd64            # Build for amd64 and export"
            echo "  $0 -b -v 0.2.0 -p linux/amd64   # Build with version for amd64"
            echo "  $0 -o ~/Downloads               # Export to Downloads"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                          ║${NC}"
echo -e "${BLUE}║    ${BOLD}Qwen Code Web UI - Export Image${NC}       ${BLUE}║${NC}"
echo -e "${BLUE}║                                          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

# Determine project directory
if [ -z "$PROJECT_DIR" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

# Check if Docker is running
echo -e "${CYAN}▶ Checking Docker...${NC}"
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}✗ Docker is not running. Please start Docker first.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker is running${NC}"

# Build image if requested or if not found
if [ "$BUILD_IMAGE" = true ]; then
    echo -e "${CYAN}▶ Building image...${NC}"

    # Check if Dockerfile exists
    if [ ! -f "$PROJECT_DIR/Dockerfile" ]; then
        echo -e "${RED}✗ Dockerfile not found in: $PROJECT_DIR${NC}"
        exit 1
    fi

    echo -e "  Project directory: $PROJECT_DIR"

    # Determine build command based on platform
    if [ -n "$PLATFORM" ]; then
        echo -e "  Target platform: ${YELLOW}$PLATFORM${NC}"
        echo -e "  ${YELLOW}Note: Cross-platform build may take longer...${NC}"

        # Ensure buildx is available and create builder if needed
        if ! docker buildx version > /dev/null 2>&1; then
            echo -e "${RED}✗ docker buildx is not available. Please update Docker.${NC}"
            exit 1
        fi

        # Create a builder instance for cross-platform builds if not exists
        BUILDER_NAME="multiarch-builder"
        if ! docker buildx inspect "$BUILDER_NAME" > /dev/null 2>&1; then
            echo -e "  Creating buildx builder: $BUILDER_NAME"
            docker buildx create --name "$BUILDER_NAME" --driver docker-container --use > /dev/null
        else
            docker buildx use "$BUILDER_NAME" > /dev/null
        fi

        # Bootstrap the builder
        docker buildx inspect --bootstrap > /dev/null 2>&1 || true

        BUILD_CMD="docker buildx build --platform $PLATFORM --load -t $IMAGE_NAME:latest"
    else
        # Native build
        BUILD_CMD="docker build -t $IMAGE_NAME:latest"
    fi

    echo -e "  This may take a few minutes..."
    echo ""

    cd "$PROJECT_DIR"
    # Use pipefail to catch build errors in pipeline
    set -o pipefail
    $BUILD_CMD . 2>&1 | while read -r line; do
        # Only show important build steps
        if echo "$line" | grep -qE "^\[.*\]|^Step|ERROR|FAILED|Successfully|warning|WARN"; then
            echo -e "  $line"
        fi
    done
    BUILD_EXIT_CODE=$?
    set +o pipefail

    if [ $BUILD_EXIT_CODE -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✓ Image built successfully${NC}"
    else
        echo -e "${RED}✗ Failed to build image${NC}"
        exit 1
    fi
else
    # Check if image exists
    echo -e "${CYAN}▶ Checking image...${NC}"
    if ! docker image inspect "$IMAGE_NAME:latest" > /dev/null 2>&1; then
        echo -e "${RED}✗ Image not found: $IMAGE_NAME:latest${NC}"
        echo ""
        echo -e "  ${YELLOW}Options:${NC}"
        echo -e "    1. Build the image: $0 --build"
        echo -e "    2. Build manually:  docker build -t $IMAGE_NAME:latest ."
        exit 1
    fi
    echo -e "${GREEN}✓ Image found: $IMAGE_NAME:latest${NC}"
fi

# Get image info
IMAGE_SIZE=$(docker image inspect "$IMAGE_NAME:latest" --format='{{.Size}}' 2>/dev/null)
IMAGE_SIZE_MB=$((IMAGE_SIZE / 1024 / 1024))

# Get version from image if not specified
if [ -z "$VERSION" ]; then
    VERSION=$(docker image inspect "$IMAGE_NAME:latest" --format='{{index .Config.Labels "version"}}' 2>/dev/null || echo "")
    if [ -z "$VERSION" ] || [ "$VERSION" = "<nil>" ]; then
        VERSION=$(date +%Y%m%d)
    fi
fi

# Set output directory
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="$(pwd)"
fi

# Create output directory if needed
mkdir -p "$OUTPUT_DIR"

# Generate filename
FILENAME="qwen-code-webui-${VERSION}.tar"
OUTPUT_PATH="${OUTPUT_DIR}/${FILENAME}"

echo ""
echo -e "${BOLD}Export Details:${NC}"
echo -e "  Image:    ${GREEN}$IMAGE_NAME:latest${NC}"
echo -e "  Size:     ${GREEN}${IMAGE_SIZE_MB} MB${NC}"
echo -e "  Output:   ${GREEN}$OUTPUT_PATH${NC}"
echo ""

# Check if file already exists
if [ -f "$OUTPUT_PATH" ] || [ -f "${OUTPUT_PATH}.gz" ]; then
    EXISTING_FILE="${OUTPUT_PATH}"
    [ -f "${OUTPUT_PATH}.gz" ] && EXISTING_FILE="${OUTPUT_PATH}.gz"
    
    echo -e "${YELLOW}File already exists: $EXISTING_FILE${NC}"
    read -p "Overwrite? [y/N]: " overwrite
    if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
        echo -e "${YELLOW}Export cancelled.${NC}"
        exit 0
    fi
    rm -f "$OUTPUT_PATH" "${OUTPUT_PATH}.gz"
fi

# Export image
echo -e "${CYAN}▶ Exporting image...${NC}"
echo -e "  This may take a few minutes..."
echo ""

docker save "$IMAGE_NAME:latest" -o "$OUTPUT_PATH"

# Compress with gzip
echo ""
echo -e "${CYAN}▶ Compressing...${NC}"
gzip -f "$OUTPUT_PATH"
OUTPUT_PATH="${OUTPUT_PATH}.gz"
FILENAME="${FILENAME}.gz"

# Make file readable by all users (for deployment on other machines)
chmod a+r "$OUTPUT_PATH"

# Get final file size
FINAL_SIZE=$(stat -f%z "$OUTPUT_PATH" 2>/dev/null || stat -c%s "$OUTPUT_PATH" 2>/dev/null)
FINAL_SIZE_MB=$((FINAL_SIZE / 1024 / 1024))

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                          ║${NC}"
echo -e "${GREEN}║         ${BOLD}Export Complete!${NC}                ${GREEN}║${NC}"
echo -e "${GREEN}║                                          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}File:${NC}     ${GREEN}$OUTPUT_PATH${NC}"
echo -e "  ${BOLD}Size:${NC}     ${GREEN}${FINAL_SIZE_MB} MB${NC} (compressed)"
echo ""
echo -e "  ${BLUE}To deploy on another machine:${NC}"
echo -e "    1. Copy the tar file to the target machine"
echo -e "    2. Run: ./scripts/install/docker-method/install.sh -i $FILENAME"
echo ""