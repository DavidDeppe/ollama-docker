# Ollama Docker - Complete Setup Guide

Pre-configured Docker image with Ollama and multiple language models for offline deployment.

## 🚀 Quick Start

### Option 1: Pull from GitHub Container Registry

```bash
# Pull the pre-built image
docker pull ghcr.io/daviddeppe/ollama-preloaded:latest

# Run the container
docker run -d \
  -p 11434:11434 \
  --name ollama \
  ghcr.io/daviddeppe/ollama-preloaded:latest

# Wait a moment for startup
sleep 15

# Verify it's working
curl http://localhost:11434
```

### Option 2: Build Locally

```bash
# Clone the repository
git clone https://github.com/DavidDeppe/ollama-docker.git
cd ollama-docker

# Build the image (pulls 4 models: ~20-30 minutes)
docker build -t ollama-preloaded:local .

# Run it
docker run -d -p 11434:11434 --name ollama ollama-preloaded:local
```

## 📦 Models Included

- **llama2** (7B) - General purpose language model
- **llama3.2** (11B) - Latest general purpose model
- **codellama** (7B) - Best for coding assistance
- **orca-mini** (3B) - Lightweight for quick tasks

## 🔌 API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/` | GET | Health check |
| `/api/tags` | GET | List all models |
| `/api/generate` | POST | Generate text |
| `/api/chat` | POST | Chat completion |
| `/api/pull` | POST | Pull a model |
| `/api/delete` | DELETE | Delete a model |
| `/api/show` | POST | Show model info |
| `/api/ps` | GET | List running models |
| `/api/embeddings` | POST | Generate embeddings |
| `/v1/chat/completions` | POST | OpenAI-compatible endpoint |

## 📝 Example Usage

### List Available Models

```bash
curl http://localhost:11434/api/tags
```

### Generate Text

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "What is Docker?",
  "stream": false
}' | jq '.response'
```

### Interactive Chat

```bash
# Using docker exec
docker exec -it ollama ollama run llama3.2

# Or via API
curl http://localhost:11434/api/chat -d '{
  "model": "llama3.2",
  "messages": [
    {"role": "user", "content": "Hello"}
  ],
  "stream": false
}' | jq '.message.content'
```

### Python Example

```python
import requests
import json

BASE_URL = "http://localhost:11434"

response = requests.post(f"{BASE_URL}/api/generate", json={
    "model": "llama3.2",
    "prompt": "What is AI?",
    "stream": False
})

print(response.json()["response"])
```

### Node.js Example

```javascript
const axios = require('axios');

const response = await axios.post('http://localhost:11434/api/generate', {
  model: 'llama3.2',
  prompt: 'What is AI?',
  stream: false
});

console.log(response.data.response);
```

## 🌐 Offline Deployment

For air-gapped environments, use the offline build process:

### Generate Offline Package (On Machine with Internet)

```bash
# Clone and run the preparation script
git clone https://github.com/DavidDeppe/ollama-docker.git
cd ollama-docker
bash prepare-offline-build.sh
```

This creates an `offline-build-package.tar.gz` with all models and Dockerfile.

### Deploy on Offline Machine

```bash
# Extract the package
tar -xzf offline-build-package.tar.gz
cd offline-build-package

# Load the base image
docker load -i ollama-base.tar

# Build with pre-downloaded models (no network needed)
docker build -f Dockerfile.models -t ollama-preloaded:local .

# Run the container
docker run -d -p 11434:11434 --name ollama ollama-preloaded:local

# Verify
curl http://localhost:11434
```

## 📄 Generate ollama-complete.tar

To create the pre-built image tar file:

```bash
# Build the Docker image (requires network access for first build)
docker build -t ollama-preloaded:latest .

# Wait for build to complete (30+ minutes with all models)

# Save the image as tar file
docker save ollama-preloaded:latest -o ollama-complete.tar

# File will be ~13GB (compressed from 31GB uncompressed)
ls -lh ollama-complete.tar
```

### Using ollama-complete.tar

```bash
# On another machine, load the pre-built image
docker load -i ollama-complete.tar

# Run it directly
docker run -d -p 11434:11434 ollama-preloaded:latest
```

## 🐳 Docker Compose

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  ollama:
    image: ghcr.io/daviddeppe/ollama-preloaded:latest
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    environment:
      - OLLAMA_HOST=0.0.0.0:11434
      - OLLAMA_KEEP_ALIVE=24h
      - OLLAMA_MAX_LOADED_MODELS=4
      - OLLAMA_NUM_PARALLEL=4
    restart: unless-stopped

volumes:
  ollama_data:
```

Run with:
```bash
docker-compose up -d
docker-compose logs -f
docker-compose down
```

## 📊 Monitoring

```bash
# View logs
docker logs -f ollama

# Monitor resources
docker stats ollama

# Check running models
docker exec ollama ollama ps

# List all models
docker exec ollama ollama list

# Get model info
docker exec ollama ollama show llama3.2
```

## 🛑 Cleanup

```bash
# Stop container
docker stop ollama

# Remove container
docker rm ollama

# Remove image (optional)
docker rmi ollama-preloaded:latest
```

## 🔧 Configuration

Environment variables for fine-tuning:

```bash
docker run -d \
  -p 11434:11434 \
  -e OLLAMA_HOST=0.0.0.0:11434 \
  -e OLLAMA_KEEP_ALIVE=24h \
  -e OLLAMA_MAX_LOADED_MODELS=4 \
  -e OLLAMA_NUM_PARALLEL=4 \
  -e OLLAMA_FLASH_ATTENTION=1 \
  ollama-preloaded:latest
```

## 📚 Documentation Files

- **QUICK_START.md** - Copy-paste commands for common tasks
- **OFFLINE_DEPLOYMENT.md** - Detailed offline deployment guide (8,000+ words)
- **ollama_docker.md** - Complete technical documentation (1,600+ lines)

## 🔗 Resources

- **GitHub**: https://github.com/DavidDeppe/ollama-docker
- **Official Ollama**: https://ollama.ai
- **API Docs**: https://docs.ollama.com/api

## ⚠️ Troubleshooting

**Port already in use?**
```bash
docker run -d -p 8080:11434 ollama-preloaded:latest
curl http://localhost:8080
```

**Container not responding?**
```bash
docker logs ollama
docker exec ollama ps aux | grep ollama
```

**Models not loaded?**
```bash
docker exec ollama ollama list
docker exec ollama ollama show llama3.2
```

**Out of memory?**
```bash
# Increase Docker Desktop memory limit in settings
# Or reduce concurrent models: -e OLLAMA_MAX_LOADED_MODELS=2
```

---

**Status**: ✅ Production Ready
**Last Updated**: January 2026
**Image Size**: ~31GB (uncompressed) | ~13GB (tar compressed)
**Models**: 4 (llama2, llama3.2, codellama, orca-mini)
