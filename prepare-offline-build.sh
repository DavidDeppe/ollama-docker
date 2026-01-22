#!/bin/bash

##############################################################################
# Offline Docker Build Preparation Script
# Run this on a machine WITH network access
# Creates files for offline building on another machine
##############################################################################

set -e

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║       Ollama Offline Docker Build Preparation                      ║"
echo "║  Run this on a machine WITH network access                         ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Configuration
BASE_IMAGE="ollama/ollama:latest"
MODELS=("llama3.2" "gemma:2b")
OUTPUT_DIR="./offline-build-package"
COMPRESS=true

echo "✓ Configuration:"
echo "  Base image: $BASE_IMAGE"
echo "  Models: ${MODELS[@]}"
echo "  Output directory: $OUTPUT_DIR"
echo ""

# Step 1: Verify Docker is running
echo "1️⃣  Checking Docker daemon..."
if ! docker ps > /dev/null 2>&1; then
    echo "❌ Docker daemon is not running!"
    exit 1
fi
echo "   ✓ Docker is running"
echo ""

# Step 2: Pull base image
echo "2️⃣  Pulling base image: $BASE_IMAGE"
docker pull "$BASE_IMAGE"
echo "   ✓ Base image pulled"
echo ""

# Step 3: Create temporary container for models
echo "3️⃣  Preparing to cache models..."
TEMP_CONTAINER="ollama-model-cache-$$"
echo "   Starting temporary container: $TEMP_CONTAINER"
docker run -d -v ollama_cache:/root/.ollama \
    --name "$TEMP_CONTAINER" \
    "$BASE_IMAGE" > /dev/null

echo "   Downloading models (this may take 5-10 minutes)..."
for model in "${MODELS[@]}"; do
    echo "   → Pulling $model..."
    docker exec "$TEMP_CONTAINER" ollama pull "$model" || {
        echo "   ⚠️  Failed to pull $model"
        docker stop "$TEMP_CONTAINER" > /dev/null
        docker rm "$TEMP_CONTAINER" > /dev/null
        exit 1
    }
done
echo "   ✓ All models cached"
echo ""

# Step 4: Extract models to directory
echo "4️⃣  Extracting models to directory..."
mkdir -p "$OUTPUT_DIR/models"
docker run --rm \
    -v ollama_cache:/root/.ollama:ro \
    -v "$(pwd)/$OUTPUT_DIR/models:/output" \
    alpine:latest \
    sh -c "cp -r /root/.ollama/models/* /output/ 2>/dev/null || true"
echo "   ✓ Models extracted"
echo ""

# Step 5: Save base image
echo "5️⃣  Saving base image to tar file..."
docker save "$BASE_IMAGE" -o "$OUTPUT_DIR/ollama-base.tar"
echo "   ✓ Base image saved"
echo ""

# Step 6: Copy Dockerfile
echo "6️⃣  Copying build files..."
cp Dockerfile.models "$OUTPUT_DIR/" 2>/dev/null || {
    echo "   ⚠️  Dockerfile.models not found, creating default..."
    cat > "$OUTPUT_DIR/Dockerfile.models" << 'DOCKERFILE'
FROM ollama/ollama:latest AS builder
COPY ./models /root/.ollama/models

FROM ollama/ollama:latest
COPY --from=builder /root/.ollama /root/.ollama

ENV OLLAMA_HOST=0.0.0.0:11434
ENV OLLAMA_KEEP_ALIVE=24h

EXPOSE 11434

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -f http://localhost:11434 || exit 1

CMD ["serve"]
DOCKERFILE
}

cp .dockerignore "$OUTPUT_DIR/" 2>/dev/null || true
echo "   ✓ Build files copied"
echo ""

# Step 7: Create instructions file
echo "7️⃣  Creating deployment instructions..."
cat > "$OUTPUT_DIR/INSTRUCTIONS.txt" << 'INSTRUCTIONS'
╔════════════════════════════════════════════════════════════════════════════╗
║              OFFLINE OLLAMA DOCKER BUILD INSTRUCTIONS                      ║
╚════════════════════════════════════════════════════════════════════════════╝

FILES INCLUDED:
  ✓ ollama-base.tar         - Docker base image (3 GB)
  ✓ models/                 - Pre-downloaded models (3.5 GB)
  ✓ Dockerfile.models       - Build instructions
  ✓ .dockerignore          - Build optimizations
  ✓ INSTRUCTIONS.txt        - This file

DEPLOYMENT ON OFFLINE MACHINE:

  1. Load the base image:
     docker load -i ollama-base.tar

  2. Build the Docker image:
     docker build -f Dockerfile.models -t ollama-preloaded:local .
     (This takes ~5 minutes and requires NO network access)

  3. Run the container:
     docker run -d -p 11434:11434 --name ollama ollama-preloaded:local

  4. Verify it works:
     curl http://localhost:11434
     (Should return: "Ollama is running")

  5. Test the models:
     curl http://localhost:11434/api/tags

TROUBLESHOOTING:

  Q: "docker load" fails with "image not found"
  A: Ensure ollama-base.tar is in the current directory

  Q: Build fails with "models not found"
  A: Check that 'models' directory exists and contains subdirectories

  Q: Container starts but models not available
  A: Verify models/ directory has content from step 2

MANUAL COMMANDS:

  # Load base image
  docker load -i ollama-base.tar

  # Build (no network needed)
  docker build -f Dockerfile.models -t ollama-preloaded:local .

  # Run
  docker run -d -p 11434:11434 --name ollama ollama-preloaded:local

  # Test
  curl http://localhost:11434

SUPPORT:
  See OFFLINE_DEPLOYMENT.md in the repository for detailed information.
INSTRUCTIONS

echo "   ✓ Instructions created"
echo ""

# Step 8: Create manifest file
echo "8️⃣  Creating manifest..."
{
    echo "Created: $(date)"
    echo "Base Image: $BASE_IMAGE"
    echo "Models:"
    for model in "${MODELS[@]}"; do
        echo "  - $model"
    done
    echo ""
    echo "File Sizes:"
    du -sh "$OUTPUT_DIR/ollama-base.tar"
    du -sh "$OUTPUT_DIR/models"
    du -sh "$OUTPUT_DIR"
} > "$OUTPUT_DIR/MANIFEST.txt"
echo "   ✓ Manifest created"
echo ""

# Step 9: Cleanup temporary container
echo "9️⃣  Cleaning up temporary resources..."
docker stop "$TEMP_CONTAINER" > /dev/null 2>&1 || true
docker rm "$TEMP_CONTAINER" > /dev/null 2>&1 || true
docker volume rm ollama_cache > /dev/null 2>&1 || true
echo "   ✓ Cleanup complete"
echo ""

# Step 10: Compress if requested
if [ "$COMPRESS" = true ]; then
    echo "🔟 Compressing package for transfer..."
    tar -czf "offline-build-package.tar.gz" "$OUTPUT_DIR"
    echo "   ✓ Compressed: offline-build-package.tar.gz"
    echo ""
fi

# Final summary
echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║                            ✅ READY FOR TRANSFER                          ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "📦 Output Directory: $OUTPUT_DIR"
echo ""
echo "Contents:"
ls -lh "$OUTPUT_DIR" | tail -n +2 | awk '{print "   " $9 " (" $5 ")"}'
echo ""
if [ "$COMPRESS" = true ]; then
    echo "Compressed Package: offline-build-package.tar.gz"
    ls -lh offline-build-package.tar.gz | awk '{print "   Size: " $5}'
    echo ""
    echo "📋 Transfer offline-build-package.tar.gz to your offline machine"
    echo "   Then extract and follow INSTRUCTIONS.txt"
else
    echo "📋 Transfer the entire '$OUTPUT_DIR' folder to your offline machine"
    echo "   Then follow INSTRUCTIONS.txt"
fi
echo ""
echo "Next Steps:"
echo "  1. Transfer files to offline machine"
echo "  2. Run: docker load -i ollama-base.tar"
echo "  3. Run: docker build -f Dockerfile.models -t ollama-preloaded:local ."
echo "  4. Run: docker run -d -p 11434:11434 ollama-preloaded:local"
echo "  5. Test: curl http://localhost:11434"
echo ""

