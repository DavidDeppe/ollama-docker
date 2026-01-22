# Ollama Docker - Quick Start Guide

## 🚀 One-Command Setup

```bash
# Pull the image
docker pull ghcr.io/daviddeppe/ollama-preloaded:latest

# Run the container
docker run -d \
  -p 11434:11434 \
  --name ollama \
  ghcr.io/daviddeppe/ollama-preloaded:latest

# Wait 15 seconds, then verify
sleep 15 && curl http://localhost:11434
```

## 📱 Testing the Models

### Using cURL

```bash
# List available models
curl http://localhost:11434/api/tags

# Test Gemma 2B
curl http://localhost:11434/api/generate -d '{
  "model": "gemma:2b",
  "prompt": "Hello, how are you?",
  "stream": false
}' | jq '.response'

# Test Llama 3.2
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "What is the capital of France?",
  "stream": false
}' | jq '.response'
```

### Using Docker Exec (Interactive)

```bash
# Interactive chat with Llama 3.2
docker exec -it ollama ollama run llama3.2

# List models in container
docker exec ollama ollama list

# Show model info
docker exec ollama ollama show gemma:2b
```

### Using Python

```python
import requests

BASE_URL = "http://localhost:11434"

# Simple generation
response = requests.post(f"{BASE_URL}/api/generate", json={
    "model": "gemma:2b",
    "prompt": "Hello",
    "stream": False
})

print(response.json()["response"])
```

### Using Node.js

```javascript
const axios = require('axios');

const response = await axios.post('http://localhost:11434/api/generate', {
  model: 'gemma:2b',
  prompt: 'Hello',
  stream: false
});

console.log(response.data.response);
```

## 🛑 Stopping & Cleanup

```bash
# Stop container
docker stop ollama

# Remove container
docker rm ollama

# Remove image (optional)
docker rmi ghcr.io/daviddeppe/ollama-preloaded:latest
```

## 🐳 Using Docker Compose

Create a `docker-compose.yml`:

```yaml
version: '3.8'

services:
  ollama:
    image: ghcr.io/daviddeppe/ollama-preloaded:latest
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    restart: unless-stopped

volumes:
  ollama_data:
```

Then run:

```bash
docker-compose up -d
docker-compose logs -f
docker-compose down
```

## 📊 Monitoring

```bash
# View container logs
docker logs -f ollama

# Monitor resource usage
docker stats ollama

# Get container info
docker inspect ollama

# Check API status
curl http://localhost:11434/api/ps
```

## 🔗 Available API Endpoints

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

## 🎛️ Environment Variables

```bash
# Set different configuration
docker run -d \
  -p 11434:11434 \
  -e OLLAMA_HOST=0.0.0.0:11434 \
  -e OLLAMA_KEEP_ALIVE=24h \
  -e OLLAMA_NUM_PARALLEL=4 \
  ghcr.io/daviddeppe/ollama-preloaded:latest
```

## 📚 Resources

- **GitHub**: https://github.com/DavidDeppe/ollama-docker
- **Full Documentation**: See `ollama_docker.md`
- **Official Docs**: https://docs.ollama.com
- **API Reference**: https://docs.ollama.com/api

## ⚠️ Troubleshooting

**Port already in use?**
```bash
docker run -d -p 8080:11434 ghcr.io/daviddeppe/ollama-preloaded:latest
curl http://localhost:8080
```

**Container not responding?**
```bash
docker logs ollama
docker exec ollama ps aux | grep ollama
```

**Models not loading?**
```bash
docker exec ollama ollama list
docker exec ollama ollama show gemma:2b
```

**Out of memory?**
```bash
# Check Docker memory limit
docker stats

# Increase if needed (Docker Desktop settings)
```

---

**Created**: January 21, 2026  
**Status**: ✅ Production Ready
