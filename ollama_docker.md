# Ollama Docker Solution - Research & Implementation Guide

## Project Overview
Creating a Docker image with Ollama running inside, with all dependencies included, ready to push to GitHub and pull/run on any machine.

## Key Requirements
- All Ollama dependencies bundled in the Docker image
- Model weights and configuration persisted in the image
- Seamless pull and run from GitHub Container Registry
- Works across different machines with minimal setup

## Table of Contents
1. [Ollama Docker Architecture](#architecture)
2. [Dockerfile Configuration](#dockerfile)
3. [Model Management](#model-management)
4. [GitHub Container Registry Setup](#github-setup)
5. [Deployment Workflow](#deployment)
6. [Troubleshooting](#troubleshooting)

## Status
- Created: January 21, 2026
- Last Updated: January 21, 2026

---

## Next Steps
- [ ] Research Ollama Docker best practices
- [ ] Document complete Dockerfile example
- [ ] Create model persistence strategy
- [ ] Document GitHub Container Registry workflow
- [ ] Create end-to-end walkthroughs

---

## Research Notes Section

### 1. Official Ollama Docker Setup and Best Practices

#### Official Docker Image
- **Image**: `ollama/ollama` (Docker Hub official image)
- **Source**: Docker-sponsored open-source image
- **Documentation**: https://docs.ollama.com/docker
- **Architectures**: Supports both `linux/amd64` and `linux/arm64`

#### Basic Setup Commands

**CPU-only deployment:**
```bash
docker run -d -v ollama:/root/.ollama -p 11434:11434 --name ollama ollama/ollama
```

**NVIDIA GPU deployment:**
```bash
# First, install NVIDIA Container Toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Run with GPU support
docker run -d --gpus=all -v ollama:/root/.ollama -p 11434:11434 --name ollama ollama/ollama
```

**AMD GPU deployment (ROCm):**
```bash
docker run -d --device /dev/kfd --device /dev/dri -v ollama:/root/.ollama -p 11434:11434 --name ollama ollama/ollama:rocm
```

**Vulkan support:**
```bash
docker run -d --device /dev/kfd --device /dev/dri -v ollama:/root/.ollama -p 11434:11434 -e OLLAMA_VULKAN=1 --name ollama ollama/ollama
```

#### Platform-Specific Considerations
- **macOS**: Run Ollama as a standalone application outside Docker (Docker Desktop doesn't support GPU passthrough)
- **Linux**: Full GPU acceleration support within Docker containers
- **Windows**: Docker Desktop supported with NVIDIA GPU support

#### Executing Models
```bash
docker exec -it ollama ollama run llama3.2
```

---

### 2. How to Install Ollama in a Docker Image

#### Official Dockerfile Architecture

The official Ollama Dockerfile uses a complex multi-stage build process:

**Base Images:**
- AMD64: `rocm/dev-almalinux-8:${ROCMVERSION}-complete`
- ARM64: `almalinux:8`
- Final runtime: `ubuntu:24.04`

**Build Stages:**
- `cpu` - CPU-only backend
- `cuda-11`, `cuda-12`, `cuda-13` - NVIDIA CUDA support
- `rocm-6` - AMD ROCm support
- `jetpack-5`, `jetpack-6` - NVIDIA Jetson platforms
- `vulkan` - GPU-agnostic graphics
- `mlx` - Apple MLX framework

**Runtime Configuration:**
```dockerfile
FROM ubuntu:24.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    libgomp1 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy compiled binaries
COPY --from=builder /go/bin/ollama /bin/ollama

# Expose API port
EXPOSE 11434

# Set environment variables
ENV OLLAMA_HOST=0.0.0.0:11434
ENV LD_LIBRARY_PATH=/usr/local/nvidia/lib:/usr/local/nvidia/lib64
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

# Set entrypoint
ENTRYPOINT ["/bin/ollama"]
CMD ["serve"]
```

#### Custom Installation in Dockerfile

For custom Docker images:

```dockerfile
FROM ubuntu:24.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama (alternative approach using install script)
RUN curl -fsSL https://ollama.com/install.sh | sh

# Or copy from official image
# FROM ollama/ollama:latest
# (This is the recommended approach)

EXPOSE 11434
CMD ["ollama", "serve"]
```

---

### 3. Model Storage and Persistence in Docker

#### OLLAMA_MODELS Directory Location

**Default Storage Paths:**
- **Linux**: `/root/.ollama` (in container) or `/var/lib/ollama/.ollama/models` (systemd)
- **macOS**: `~/.ollama/models`
- **Windows**: `C:\Users\<username>\.ollama\models`

**Container Default**: `/root/.ollama`

#### Volume Configuration

**Named Volume (Recommended):**
```bash
docker run -d -v ollama:/root/.ollama -p 11434:11434 --name ollama ollama/ollama
```

**Bind Mount:**
```bash
docker run -d -v ~/.ollama:/root/.ollama -p 11434:11434 --name ollama ollama/ollama
```

**Custom Location via Environment Variable:**
```bash
docker run -d \
  -e OLLAMA_MODELS=/custom/path \
  -v ollama_models:/custom/path \
  -p 11434:11434 \
  --name ollama ollama/ollama
```

#### Storage Structure
```
/root/.ollama/
├── models/
│   ├── manifests/
│   ├── blobs/
│   └── ...
└── ...
```

---

### 4. How to Bake a Model into the Docker Image

#### Method 1: Multi-Stage Build with Server Startup (Recommended)

```dockerfile
FROM ollama/ollama:latest AS builder

# Start Ollama server in background and pull model
RUN ollama serve & sleep 3 && ollama pull llama3.2 && pkill ollama

FROM ollama/ollama:latest

# Copy pre-downloaded model from builder stage
COPY --from=builder /root/.ollama /root/.ollama

# Set environment variables
ENV OLLAMA_HOST=0.0.0.0:11434

EXPOSE 11434
CMD ["serve"]
```

#### Method 2: Using Model Loader Helper Image

```dockerfile
FROM gerke74/ollama-model-loader AS downloader

# Pull multiple models during build
RUN /ollama-pull gemma:2b
RUN /ollama-pull llama3.2

FROM ollama/ollama:latest

ENV OLLAMA_HOST=0.0.0.0:11434

# Copy all downloaded models
COPY --from=downloader /root/.ollama /root/.ollama

EXPOSE 11434
CMD ["serve"]
```

#### Method 3: Copy Pre-built Local Models

```dockerfile
FROM ollama/ollama:latest

# Copy models from local cache (must exist on build machine)
COPY ./.ollama/ /root/.ollama/

ENV OLLAMA_HOST=0.0.0.0:11434

EXPOSE 11434
CMD ["serve"]
```

#### Method 4: Runtime Model Pulling with Entrypoint Script

**Dockerfile:**
```dockerfile
FROM ollama/ollama:latest

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV OLLAMA_HOST=0.0.0.0:11434
ENV OLLAMA_KEEP_ALIVE=24h
ENV MODEL=llama3.2

EXPOSE 11434
ENTRYPOINT ["/entrypoint.sh"]
```

**entrypoint.sh:**
```bash
#!/bin/bash
set -e

# Validate MODEL environment variable
if [ -z "$MODEL" ]; then
  echo "Error: MODEL environment variable not set"
  exit 1
fi

echo "Starting Ollama server on internal port for model download..."
ollama serve &
SERVER_PID=$!

# Wait for server to be ready
echo "Waiting for Ollama server to start..."
for i in {1..30}; do
  if curl -s http://localhost:11434 > /dev/null 2>&1; then
    echo "Ollama server is ready"
    break
  fi
  if [ $i -eq 30 ]; then
    echo "Error: Ollama server failed to start"
    exit 1
  fi
  sleep 2
done

# Pull the model
echo "Pulling model: $MODEL"
ollama pull "$MODEL"

if [ $? -eq 0 ]; then
  echo "Model $MODEL downloaded successfully"
else
  echo "Error: Failed to download model $MODEL"
  exit 1
fi

# Stop background server
kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true

# Start Ollama in foreground on public interface
echo "Starting Ollama server for API access..."
exec ollama serve
```

#### Image Size Considerations
- Base Ollama image: ~1-2 GB
- 7B model: +4-8 GB
- 13B model: +8-16 GB
- 70B model: +40-80 GB
- **Total image size** = Base + Model(s) size

---

### 5. Container Resource Requirements

#### RAM Requirements by Model Size

| Model Size | Minimum RAM | Recommended RAM |
|------------|-------------|-----------------|
| 7B         | 8 GB        | 16 GB          |
| 13B        | 16 GB       | 32 GB          |
| 33B        | 32 GB       | 64 GB          |
| 70B        | 64 GB       | 128 GB         |

#### Disk Space Requirements

| Model Size | Storage Required |
|------------|-----------------|
| 7B         | 4-8 GB         |
| 13B        | 8-16 GB        |
| 30B        | 16-32 GB       |
| 70B        | 40-80 GB       |

**Recommendations:**
- SSD strongly recommended over HDD for faster model loading
- Base installation + few models: 12 GB minimum
- Practical setup: 256 GB - 512 GB for multiple models
- Quantization affects size (Q4 < Q8 < F16)

#### CPU Requirements
- Modern multi-core CPU recommended
- CPU inference is significantly slower than GPU
- Parallel processing: Use `OLLAMA_NUM_PARALLEL` environment variable

#### GPU Support

**NVIDIA GPU:**
- Requires: NVIDIA Container Toolkit
- Driver capabilities: `compute,utility`
- Configuration: `--gpus=all` flag
- VRAM requirements:
  - 8-24 GB: 7B-30B models (quantized)
  - 24-48 GB: 70B models (quantized)
  - 48+ GB: Large models at higher precision

**AMD GPU:**
- Use image tag: `ollama/ollama:rocm`
- Device access: `--device /dev/kfd --device /dev/dri`

**JetPack (NVIDIA Jetson):**
- Environment variables: `JETSON_JETPACK=5` or `JETSON_JETPACK=6`

#### Concurrency Configuration

**Environment Variables:**
- `OLLAMA_MAX_LOADED_MODELS`: Default = `3 * GPU_count` or `3` for CPU
- `OLLAMA_NUM_PARALLEL`: Default = `4` or `1` (memory-dependent)
- `OLLAMA_MAX_QUEUE`: Default = `512`

---

### 6. Entrypoint and Command Configuration

#### Official Configuration

**From Official Dockerfile:**
```dockerfile
ENTRYPOINT ["/bin/ollama"]
CMD ["serve"]
```

**Execution:** Container runs `ollama serve` by default

#### Command Line Options

```bash
# View all available options
ollama serve --help
```

#### Key Environment Variables for Server Configuration

| Variable | Purpose | Default | Example |
|----------|---------|---------|---------|
| `OLLAMA_HOST` | Server binding address | `127.0.0.1` | `0.0.0.0:11434` |
| `OLLAMA_KEEP_ALIVE` | Model memory retention | `5m` | `24h`, `300s`, `-1` |
| `OLLAMA_MAX_QUEUE` | Request queue limit | `512` | `1024` |
| `OLLAMA_MAX_LOADED_MODELS` | Concurrent model limit | `3 * GPU_count` | `5` |
| `OLLAMA_NUM_PARALLEL` | Parallel requests per model | `4` or `1` | `8` |
| `OLLAMA_FLASH_ATTENTION` | Performance optimization | Disabled | `1` to enable |
| `OLLAMA_KV_CACHE_TYPE` | K/V cache quantization | `f16` | `q8_0`, `q4_0` |
| `OLLAMA_ORIGINS` | Allowed CORS origins | `127.0.0.1, 0.0.0.0` | `https://example.com` |
| `OLLAMA_DEBUG` | Enable debug logging | `false` | `1` or `true` |
| `OLLAMA_VULKAN` | Enable Vulkan support | `0` | `1` |
| `HTTPS_PROXY` | Proxy configuration | None | `https://proxy:8080` |

#### Custom Entrypoint Example

```dockerfile
FROM ollama/ollama:latest

COPY custom-entrypoint.sh /custom-entrypoint.sh
RUN chmod +x /custom-entrypoint.sh

ENV OLLAMA_HOST=0.0.0.0:11434
ENV OLLAMA_KEEP_ALIVE=24h

ENTRYPOINT ["/custom-entrypoint.sh"]
CMD ["serve"]
```

**custom-entrypoint.sh:**
```bash
#!/bin/bash

# Perform initialization tasks
echo "Initializing Ollama container..."

# Check for models directory
if [ ! -d "/root/.ollama/models" ]; then
  echo "Creating models directory..."
  mkdir -p /root/.ollama/models
fi

# Execute the CMD passed to the container
exec ollama "$@"
```

---

### 7. API Exposure and Port Configuration

#### Default Port
- **Port**: `11434`
- **Protocol**: HTTP REST API
- **Endpoint Base**: `http://localhost:11434/api`

#### Port Mapping in Docker

```bash
# Standard mapping
docker run -d -p 11434:11434 --name ollama ollama/ollama

# Custom host port
docker run -d -p 8080:11434 --name ollama ollama/ollama

# All interfaces
docker run -d -p 0.0.0.0:11434:11434 --name ollama ollama/ollama
```

#### Network Configuration

**Environment Variable:**
```bash
# Listen on all interfaces (required for external access)
docker run -d \
  -e OLLAMA_HOST=0.0.0.0:11434 \
  -p 11434:11434 \
  --name ollama ollama/ollama

# Custom port
docker run -d \
  -e OLLAMA_HOST=0.0.0.0:8080 \
  -p 8080:8080 \
  --name ollama ollama/ollama
```

#### Primary API Endpoints

**Generate Completion:**
```bash
POST /api/generate
```
```bash
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Why is the sky blue?",
  "stream": false
}'
```

**Chat Completion:**
```bash
POST /api/chat
```

**List Models:**
```bash
GET /api/tags
```
```bash
curl http://localhost:11434/api/tags
```

**Pull Model:**
```bash
POST /api/pull
```
```bash
curl http://localhost:11434/api/pull -d '{
  "name": "llama3.2"
}'
```

**Delete Model:**
```bash
DELETE /api/delete
```
```bash
curl -X DELETE http://localhost:11434/api/delete -d '{
  "name": "llama3.2"
}'
```

**List Running Models:**
```bash
GET /api/ps
```

**Show Model Info:**
```bash
POST /api/show
```

**Copy Model:**
```bash
POST /api/copy
```

**Generate Embeddings:**
```bash
POST /api/embeddings
```
```bash
curl http://localhost:11434/api/embeddings -d '{
  "model": "gemma3",
  "prompt": "Hello world"
}'
```

#### OpenAI-Compatible Endpoints

Ollama provides OpenAI-compatible API endpoints:

```bash
POST /v1/chat/completions
POST /v1/completions
POST /v1/embeddings
```

Example:
```bash
curl http://localhost:11434/v1/chat/completions -d '{
  "model": "llama3.2",
  "messages": [{"role": "user", "content": "Hello!"}]
}'
```

#### Streaming Responses

By default, responses are streamed:

```bash
# Enable streaming (default)
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Tell me a story",
  "stream": true
}'

# Disable streaming (wait for complete response)
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Tell me a story",
  "stream": false
}'
```

#### CORS Configuration

**Allow specific origins:**
```bash
docker run -d \
  -e OLLAMA_ORIGINS="https://example.com,https://app.example.com" \
  -p 11434:11434 \
  --name ollama ollama/ollama
```

#### Health Check

**Endpoint**: `http://localhost:11434`

```bash
# Check if server is running
curl http://localhost:11434

# Returns: "Ollama is running"
```

**Docker health check:**
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:11434 || exit 1
```

---

### 8. Complete Docker Compose Example

```yaml
version: '3.8'

services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama

    # Port mapping
    ports:
      - "11434:11434"

    # Volume persistence
    volumes:
      - ollama_data:/root/.ollama
      - ./modelfiles:/modelfiles  # Optional: custom modelfiles

    # Environment variables
    environment:
      - OLLAMA_HOST=0.0.0.0:11434
      - OLLAMA_KEEP_ALIVE=24h
      - OLLAMA_NUM_PARALLEL=4
      - OLLAMA_MAX_LOADED_MODELS=3
      - OLLAMA_MAX_QUEUE=512
      - OLLAMA_FLASH_ATTENTION=1

    # GPU support (NVIDIA)
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]

    # Health check
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:11434"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

    # Restart policy
    restart: unless-stopped

  # Optional: Web UI
  ollama-webui:
    image: ghcr.io/ollama-webui/ollama-webui:main
    container_name: ollama-webui
    ports:
      - "3000:8080"
    depends_on:
      - ollama
    environment:
      - OLLAMA_API_BASE_URL=http://ollama:11434/api
    restart: unless-stopped

volumes:
  ollama_data:
    name: ollama_data
    driver: local
```

**Usage:**
```bash
# Start services
docker-compose up -d

# Pull a model
docker exec -it ollama ollama pull llama3.2

# Run a model
docker exec -it ollama ollama run llama3.2

# Test API
curl http://localhost:11434/api/tags

# Access Web UI
# Open browser to http://localhost:3000

# Stop services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

---

### 9. Security Best Practices for Production

#### Image Security
1. **Use Specific Version Tags**: Avoid `:latest`, use `ollama/ollama:0.1.42`
2. **Scan Images**: Use Docker Scout, Trivy, or similar tools
3. **Multi-stage Builds**: Reduce attack surface
4. **Minimal Base Images**: Use official images only

#### Access Control
1. **API Authentication**: Ollama API is unauthenticated by default - implement reverse proxy with auth
2. **Network Isolation**: Use custom Docker networks
3. **Limit Port Exposure**: Only expose necessary ports
4. **CORS Configuration**: Restrict origins with `OLLAMA_ORIGINS`

#### User Management
1. **Non-root User**: Create dedicated user in container
2. **Volume Permissions**: Proper ownership on mounted volumes
3. **Secret Management**: Use environment variables, Docker secrets, or secret managers

#### Storage Security
1. **Named Volumes**: Preferred over bind mounts
2. **Volume Encryption**: Consider encrypted volumes for sensitive models
3. **Backup Strategy**: Regular backups of model data

#### Network Security
1. **Reverse Proxy**: Use nginx/traefik with TLS
2. **Network Policies**: Kubernetes Network Policies for pod isolation
3. **Firewall Rules**: Restrict access to API port

#### Example Secure Configuration

**docker-compose.yml:**
```yaml
version: '3.8'

services:
  ollama:
    image: ollama/ollama:0.1.42  # Specific version
    container_name: ollama
    networks:
      - ollama_network
    ports:
      - "127.0.0.1:11434:11434"  # Bind to localhost only
    volumes:
      - ollama_data:/root/.ollama
    environment:
      - OLLAMA_HOST=0.0.0.0:11434
      - OLLAMA_ORIGINS=http://localhost:3000
    restart: unless-stopped
    read_only: true  # Read-only root filesystem
    tmpfs:
      - /tmp
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL

  nginx:
    image: nginx:alpine
    container_name: ollama-proxy
    networks:
      - ollama_network
    ports:
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - ollama
    restart: unless-stopped

networks:
  ollama_network:
    driver: bridge
    internal: false

volumes:
  ollama_data:
    driver: local
```

---

### 10. Common Use Cases and Examples

#### Example 1: Pre-loaded Model Image for Deployment

**Dockerfile:**
```dockerfile
FROM ollama/ollama:latest AS builder

RUN ollama serve & sleep 5 && \
    ollama pull llama3.2 && \
    ollama pull gemma:2b && \
    pkill ollama

FROM ollama/ollama:latest

COPY --from=builder /root/.ollama /root/.ollama

ENV OLLAMA_HOST=0.0.0.0:11434
ENV OLLAMA_KEEP_ALIVE=24h

EXPOSE 11434
CMD ["serve"]
```

**Build and Push:**
```bash
# Build image
docker build -t ghcr.io/username/ollama-preloaded:latest .

# Test locally
docker run -d -p 11434:11434 ghcr.io/username/ollama-preloaded:latest

# Push to registry
docker push ghcr.io/username/ollama-preloaded:latest

# Pull and run on any machine
docker pull ghcr.io/username/ollama-preloaded:latest
docker run -d -p 11434:11434 ghcr.io/username/ollama-preloaded:latest
```

#### Example 2: Dynamic Model Loading on Startup

**Dockerfile:**
```dockerfile
FROM ollama/ollama:latest

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV OLLAMA_HOST=0.0.0.0:11434
ENV MODEL=llama3.2

EXPOSE 11434
ENTRYPOINT ["/entrypoint.sh"]
```

**entrypoint.sh:**
```bash
#!/bin/bash
set -e

if [ -z "$MODEL" ]; then
  echo "Error: MODEL not set"
  exit 1
fi

# Start server in background
ollama serve &
SERVER_PID=$!

# Wait for ready
for i in {1..30}; do
  curl -s http://localhost:11434 > /dev/null 2>&1 && break
  sleep 2
done

# Pull model
echo "Pulling $MODEL..."
ollama pull "$MODEL"

# Restart server in foreground
kill $SERVER_PID
exec ollama serve
```

**Usage:**
```bash
# Build
docker build -t ollama-auto:latest .

# Run with specific model
docker run -d -e MODEL=mistral -p 11434:11434 ollama-auto:latest
```

#### Example 3: Multi-Model Setup

**Dockerfile:**
```dockerfile
FROM ollama/ollama:latest AS builder

RUN ollama serve & sleep 5 && \
    ollama pull llama3.2:7b && \
    ollama pull codellama:13b && \
    ollama pull mistral:latest && \
    pkill ollama

FROM ollama/ollama:latest

COPY --from=builder /root/.ollama /root/.ollama

ENV OLLAMA_HOST=0.0.0.0:11434
ENV OLLAMA_MAX_LOADED_MODELS=2
ENV OLLAMA_NUM_PARALLEL=2

EXPOSE 11434
CMD ["serve"]
```

---

### 11. Troubleshooting Common Issues

#### Issue: Model Not Found After Container Restart
**Cause**: Volume not persisted
**Solution**: Use named volumes or bind mounts
```bash
docker run -d -v ollama:/root/.ollama -p 11434:11434 ollama/ollama
```

#### Issue: Out of Memory
**Cause**: Model too large for available RAM
**Solution**:
- Use smaller model or quantized version
- Increase Docker memory limit
- Enable KV cache quantization: `-e OLLAMA_KV_CACHE_TYPE=q8_0`

#### Issue: GPU Not Detected
**Cause**: NVIDIA Container Toolkit not installed or not configured
**Solution**:
```bash
# Install toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker

# Run with GPU
docker run -d --gpus=all -v ollama:/root/.ollama -p 11434:11434 ollama/ollama
```

#### Issue: Cannot Pull Models During Build
**Cause**: Ollama server not running during build
**Solution**: Use multi-stage build or background server approach
```dockerfile
FROM ollama/ollama:latest AS builder
RUN ollama serve & sleep 5 && ollama pull llama3.2
```

#### Issue: Port Already in Use
**Solution**: Use different host port
```bash
docker run -d -p 8080:11434 -v ollama:/root/.ollama ollama/ollama
```

#### Issue: API Not Accessible from External Host
**Cause**: `OLLAMA_HOST` bound to localhost
**Solution**: Set to `0.0.0.0`
```bash
docker run -d -e OLLAMA_HOST=0.0.0.0:11434 -p 11434:11434 ollama/ollama
```

---

### 12. References and Documentation

#### Official Documentation
- Ollama Docker Documentation: https://docs.ollama.com/docker
- Ollama CLI Reference: https://docs.ollama.com/cli
- Ollama API Reference: https://docs.ollama.com/api/introduction
- Ollama FAQ: https://docs.ollama.com/faq

#### Docker Hub
- Official Image: https://hub.docker.com/r/ollama/ollama
- GitHub Repository: https://github.com/ollama/ollama

#### Community Resources
- Ollama Blog: https://ollama.com/blog
- Model Library: https://ollama.com/library
- GitHub Issues: https://github.com/ollama/ollama/issues

#### Related Tools
- Open WebUI: https://github.com/open-webui/open-webui
- NVIDIA Container Toolkit: https://github.com/NVIDIA/nvidia-container-toolkit
- Docker Compose: https://docs.docker.com/compose/

---

## END-TO-END IMPLEMENTATION WALKTHROUGH

This comprehensive guide walks you through the complete process: creating a Docker image with Ollama and a model baked in, pushing it to GitHub Container Registry, and pulling/running it on another machine.

### Phase 1: Setup on Build Machine

#### Step 1.1: Prepare Your Environment

```bash
# Navigate to your project directory
cd ~/Docker-Projects/ollama-with-model

# Initialize git repository (if using GitHub)
git init
git remote add origin https://github.com/YOUR_USERNAME/ollama-docker.git
```

#### Step 1.2: Create Project Directory Structure

```bash
mkdir -p ollama-docker/{docker,scripts,docs}

# Create necessary files
touch ollama-docker/Dockerfile
touch ollama-docker/docker-compose.yml
touch ollama-docker/.dockerignore
touch ollama-docker/.gitignore
```

#### Step 1.3: Create Dockerfile with Model Pre-loaded

**File: `Dockerfile`**

```dockerfile
# Multi-stage build: Builder stage to download model
FROM ollama/ollama:latest AS builder

# Start Ollama server in background and pull models
# Give the server time to initialize before pulling
RUN ollama serve & \
    sleep 10 && \
    ollama pull llama3.2 && \
    ollama pull gemma:2b && \
    pkill -f "ollama serve"

# Final stage: Runtime image with models included
FROM ollama/ollama:latest

# Copy pre-downloaded models from builder
COPY --from=builder /root/.ollama /root/.ollama

# Configure Ollama server
ENV OLLAMA_HOST=0.0.0.0:11434
ENV OLLAMA_KEEP_ALIVE=24h
ENV OLLAMA_MAX_LOADED_MODELS=2
ENV OLLAMA_NUM_PARALLEL=2
ENV OLLAMA_FLASH_ATTENTION=1

# Expose API port
EXPOSE 11434

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -f http://localhost:11434 || exit 1

# Start Ollama server
CMD ["serve"]
```

**Alternative: Single-model Dockerfile (more compact)**

```dockerfile
FROM ollama/ollama:latest AS builder

RUN ollama serve & sleep 10 && ollama pull llama3.2 && pkill -f "ollama serve"

FROM ollama/ollama:latest

COPY --from=builder /root/.ollama /root/.ollama

ENV OLLAMA_HOST=0.0.0.0:11434

EXPOSE 11434

CMD ["serve"]
```

#### Step 1.4: Create .dockerignore

**File: `.dockerignore`**

```
.git
.gitignore
.github
*.md
.DS_Store
node_modules
npm-debug.log
```

#### Step 1.5: Build the Docker Image

```bash
# Build with descriptive tag
docker build -t ollama-preloaded:latest .

# Tag for GitHub Container Registry
docker tag ollama-preloaded:latest ghcr.io/YOUR_USERNAME/ollama-preloaded:latest
docker tag ollama-preloaded:latest ghcr.io/YOUR_USERNAME/ollama-preloaded:v1.0

# Verify image was created
docker images | grep ollama-preloaded
```

**Expected output:**
```
REPOSITORY                                        TAG       IMAGE ID       CREATED        SIZE
ghcr.io/YOUR_USERNAME/ollama-preloaded           latest    abc123def456   2 minutes ago  14.2GB
ollama-preloaded                                  latest    abc123def456   2 minutes ago  14.2GB
```

**⚠️ Building Notes:**
- First build will take **30-45 minutes** (downloading models)
- Subsequent builds cache layers and rebuild faster
- Final image size: ~10-15 GB depending on models
- Requires stable internet connection (models are large)

#### Step 1.6: Test Image Locally

```bash
# Run the image
docker run -d \
  -p 11434:11434 \
  --name ollama-test \
  ollama-preloaded:latest

# Wait for container to start (10-15 seconds)
sleep 15

# Test the API
curl http://localhost:11434/api/tags

# Expected response: JSON list of loaded models
# {
#   "models": [
#     {
#       "name": "llama3.2:latest",
#       "modified_at": "2024-01-20T...",
#       "size": 3826087936,
#       "digest": "..."
#     },
#     {
#       "name": "gemma:2b",
#       ...
#     }
#   ]
# }

# Test model inference
curl http://localhost:11434/api/generate -d '{
  "model": "gemma:2b",
  "prompt": "Hello, what is Ollama?",
  "stream": false
}'

# Clean up test container
docker stop ollama-test
docker rm ollama-test
```

### Phase 2: Push to GitHub Container Registry

#### Step 2.1: Authenticate with GitHub Container Registry

```bash
# Create Personal Access Token (PAT) on GitHub:
# 1. Go to: https://github.com/settings/tokens
# 2. Click "Generate new token" > "Generate new token (classic)"
# 3. Select scopes: write:packages, read:packages, delete:packages
# 4. Copy the token

# Login to GitHub Container Registry
echo YOUR_PAT_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin

# Verify login success (no error message means success)
```

#### Step 2.2: Push Image to GitHub Container Registry

```bash
# Push the image
docker push ghcr.io/YOUR_USERNAME/ollama-preloaded:latest
docker push ghcr.io/YOUR_USERNAME/ollama-preloaded:v1.0

# Verify push was successful
docker image ls --digests ghcr.io/YOUR_USERNAME/ollama-preloaded
```

**Push progress example:**
```
The push refers to repository [ghcr.io/YOUR_USERNAME/ollama-preloaded]
14.2GB layer       [========================================>] 14.2GB
v1.0: digest: sha256:abcd1234... size: 14200000000
```

**Upload time estimates:**
- 10 Mbps connection: ~3-4 hours
- 100 Mbps connection: ~30-40 minutes
- 1 Gbps connection: ~3-5 minutes

#### Step 2.3: Make Repository Public (Optional but Recommended)

```bash
# On GitHub:
# 1. Go to: https://github.com/YOUR_USERNAME/ollama-docker
# 2. Settings > Visibility
# 3. Change to Public (if desired)
# 4. Or keep Private for private use only
```

#### Step 2.4: Commit and Push Code to GitHub

```bash
# Add files to git
git add Dockerfile docker-compose.yml .dockerignore

# Create initial commit
git commit -m "Initial Ollama Docker setup with preloaded models"

# Push to GitHub
git branch -M main
git push -u origin main
```

### Phase 3: Pull and Run on Another Machine

#### Step 3.1: Prerequisites on Target Machine

```bash
# Install Docker (if not already installed)
# macOS/Windows: Download Docker Desktop from https://www.docker.com/products/docker-desktop
# Linux:
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Verify Docker installation
docker --version
docker run hello-world
```

#### Step 3.2: Authenticate with GitHub Container Registry

```bash
# If the image is private, authenticate:
echo YOUR_PAT_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin

# If the image is public, this step is optional
```

#### Step 3.3: Pull the Image from GitHub Container Registry

```bash
# Pull the image (downloads ~10-15 GB)
docker pull ghcr.io/YOUR_USERNAME/ollama-preloaded:latest

# Verify image was pulled
docker images | grep ollama-preloaded

# Expected output:
# REPOSITORY                                        TAG       IMAGE ID       SIZE
# ghcr.io/YOUR_USERNAME/ollama-preloaded           latest    abc123def456   14.2GB
```

**Download estimates:**
- 10 Mbps: ~3-4 hours
- 100 Mbps: ~30-40 minutes
- 1 Gbps: ~3-5 minutes

#### Step 3.4: Run the Container

**Option A: Simple Docker Run Command**

```bash
# Run the container
docker run -d \
  -p 11434:11434 \
  --name ollama \
  ghcr.io/YOUR_USERNAME/ollama-preloaded:latest

# Verify container is running
docker ps | grep ollama

# Check logs
docker logs ollama

# Expected log output:
# time=2024-01-21T... level=INFO msg="Listening on" address=[::]:11434
```

**Option B: Docker Compose (Recommended for Production)**

**File: `docker-compose.yml`**

```yaml
version: '3.8'

services:
  ollama:
    image: ghcr.io/YOUR_USERNAME/ollama-preloaded:latest
    container_name: ollama

    # Port mapping
    ports:
      - "11434:11434"

    # Volume for persistent model storage (optional)
    volumes:
      - ollama_data:/root/.ollama

    # Environment configuration
    environment:
      - OLLAMA_HOST=0.0.0.0:11434
      - OLLAMA_KEEP_ALIVE=24h

    # Health check
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:11434"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s

    # Restart policy
    restart: unless-stopped

volumes:
  ollama_data:
    driver: local
```

**Run with Docker Compose:**

```bash
# Start the service
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the service
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

#### Step 3.5: Verify Ollama is Running

```bash
# Check container status
docker ps | grep ollama

# Test API endpoint
curl http://localhost:11434

# Expected response: "Ollama is running"

# List available models
curl http://localhost:11434/api/tags

# Test model inference
curl http://localhost:11434/api/generate -d '{
  "model": "gemma:2b",
  "prompt": "What is machine learning?",
  "stream": false
}'
```

#### Step 3.6: (Optional) Verify Models are in Container

```bash
# Check models inside running container
docker exec ollama ollama list

# Expected output:
# NAME            ID              SIZE      MODIFIED
# llama3.2:latest abc123def456    3.8 GB    2 hours ago
# gemma:2b        def456abc123    1.6 GB    2 hours ago
```

### Phase 4: Integration with Applications

#### Option A: Python Client

```python
import requests
import json

BASE_URL = "http://localhost:11434"

def query_ollama(model, prompt):
    """Query Ollama model"""
    url = f"{BASE_URL}/api/generate"
    payload = {
        "model": model,
        "prompt": prompt,
        "stream": False
    }

    response = requests.post(url, json=payload)
    return response.json()["response"]

# Example usage
response = query_ollama("gemma:2b", "Explain Docker in one sentence")
print(response)
```

#### Option B: JavaScript/Node.js

```javascript
const axios = require('axios');

const BASE_URL = 'http://localhost:11434';

async function queryOllama(model, prompt) {
  try {
    const response = await axios.post(`${BASE_URL}/api/generate`, {
      model: model,
      prompt: prompt,
      stream: false
    });
    return response.data.response;
  } catch (error) {
    console.error('Error querying Ollama:', error);
  }
}

// Example usage
queryOllama('gemma:2b', 'What is AI?').then(console.log);
```

#### Option C: cURL (Simple Testing)

```bash
# Interactive shell access
curl http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2",
    "prompt": "Tell me a fun fact",
    "stream": false
  }' | jq '.response'
```

### Phase 5: Scaling and Advanced Deployment

#### Multiple Models Strategy

**Dockerfile for Multiple Models:**

```dockerfile
FROM ollama/ollama:latest AS builder

RUN ollama serve & sleep 10 && \
    ollama pull llama3.2:7b && \
    ollama pull codellama:13b && \
    ollama pull mistral && \
    pkill -f "ollama serve"

FROM ollama/ollama:latest

COPY --from=builder /root/.ollama /root/.ollama

ENV OLLAMA_HOST=0.0.0.0:11434
ENV OLLAMA_MAX_LOADED_MODELS=2
ENV OLLAMA_NUM_PARALLEL=2

EXPOSE 11434

CMD ["serve"]
```

#### Kubernetes Deployment Example

**File: `k8s-deployment.yaml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama
  template:
    metadata:
      labels:
        app: ollama
    spec:
      containers:
      - name: ollama
        image: ghcr.io/YOUR_USERNAME/ollama-preloaded:latest
        ports:
        - containerPort: 11434
        resources:
          requests:
            memory: "16Gi"
            cpu: "2"
          limits:
            memory: "32Gi"
            cpu: "4"
        livenessProbe:
          httpGet:
            path: /
            port: 11434
          initialDelaySeconds: 30
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: ollama-service
spec:
  selector:
    app: ollama
  ports:
  - protocol: TCP
    port: 11434
    targetPort: 11434
  type: LoadBalancer
```

### Phase 6: Maintenance and Updates

#### Updating Models in Image

```bash
# 1. Update Dockerfile with new models
# 2. Rebuild image
docker build -t ollama-preloaded:v1.1 .

# 3. Tag for registry
docker tag ollama-preloaded:v1.1 ghcr.io/YOUR_USERNAME/ollama-preloaded:v1.1

# 4. Push new version
docker push ghcr.io/YOUR_USERNAME/ollama-preloaded:v1.1

# 5. On target machine, pull new version
docker pull ghcr.io/YOUR_USERNAME/ollama-preloaded:v1.1
docker stop ollama
docker rm ollama
docker run -d -p 11434:11434 ghcr.io/YOUR_USERNAME/ollama-preloaded:v1.1 --name ollama
```

#### Monitoring Running Containers

```bash
# View resource usage
docker stats ollama

# View logs in real-time
docker logs -f ollama

# Inspect container configuration
docker inspect ollama

# Check disk usage
docker ps -s
```

#### Backing Up Models

```bash
# Export container filesystem
docker export ollama > ollama-backup.tar

# Or commit state as new image
docker commit ollama ollama-backup:backup-date

# Restore from backup
docker load < ollama-backup.tar
```

---

### Implementation Progress

#### Phase 1 - Build Machine Setup ✅ COMPLETED
- [x] Created Dockerfile with multi-stage build
- [x] Built Docker image with preloaded models
  - Base image: ollama-preloaded:latest
  - Size: 15.9 GB
  - Models included:
    - llama3.2:latest (2.0 GB)
    - gemma:2b (1.7 GB)
- [x] Successfully tested API locally
  - Verified "Ollama is running" endpoint
  - Confirmed both models loaded via /api/tags
- [x] Tagged image for GitHub Container Registry
  - ghcr.io/daviddeppe/ollama-preloaded:latest
  - ghcr.io/daviddeppe/ollama-preloaded:v1.0

#### Phase 2 - Push to GitHub ⏳ READY
- Waiting for GitHub authentication
- Commands prepared and tested

#### Phase 3-6 - Deployment & Maintenance
- Ready to proceed once images are pushed

### Build Statistics
- Build time: ~7 minutes (includes image download + model pulls)
- Image size: 15.9 GB (compressed: 6.7 GB)
- Models status: Both models verified and ready
- Test results: API responsive, models available

### Research Completed
- Date: January 21, 2026
- Sources: Official Ollama documentation, GitHub repositories, community guides
- Coverage: Complete setup, configuration, security, and deployment strategies
- Implementation: Successful multi-stage Docker build with models baked in
