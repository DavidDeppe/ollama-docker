# Offline Docker Build Guide

## Overview

This guide covers building and deploying Ollama Docker images in completely offline environments with no Docker Hub or network access.

## The Challenge

Normal Docker builds require:
1. Pulling the base image (FROM ollama/ollama:latest)
2. Downloading and executing packages (RUN apt-get, curl, etc.)
3. Running network commands (ollama pull llama3.2)

**In offline environments, none of this works.**

## Solutions

### Strategy 1: Pre-Loaded Base Image (Recommended for Most Cases)

**When to use:** You have access to Docker Hub on ONE machine, then need to build offline elsewhere.

#### Step 1: On a Machine WITH Network Access

```bash
# Pull the base image
docker pull ollama/ollama:latest

# Save it as a tar file
docker save ollama/ollama:latest -o ollama-base.tar

# Compress for transfer (optional, saves 50% space)
gzip ollama-base.tar
```

#### Step 2: Transfer Files to Offline Machine

Transfer these files:
- `ollama-base.tar` (or `.tar.gz`)
- `Dockerfile.offline`
- `.dockerignore`

#### Step 3: On Offline Machine

```bash
# Load the base image
docker load -i ollama-base.tar

# Build (but this will fail on model pulls - see below)
docker build -f Dockerfile.offline -t ollama-preloaded:offline .
```

**Issue:** Models still can't be pulled without network!

### Strategy 2: Pre-Downloaded Models (Complete Offline Build)

**When to use:** You have the models available as files.

#### Step 1: On Machine WITH Network Access

```bash
# Pull and run ollama to cache models
docker run -d -v ollama:/root/.ollama ollama/ollama:latest
docker exec -it ollama ollama pull llama3.2
docker exec -it ollama ollama pull gemma:2b
docker stop ollama

# Extract the model cache
docker cp ollama:/root/.ollama/models ./models

# Save base image
docker save ollama/ollama:latest -o ollama-base.tar
```

This creates:
```
models/
├── llama3.2/
├── gemma:2b/
└── ...
ollama-base.tar
```

#### Step 2: Transfer to Offline Machine

Transfer:
- `ollama-base.tar`
- `models/` directory
- `Dockerfile.models`

#### Step 3: On Offline Machine

```bash
# Load base image
docker load -i ollama-base.tar

# Build with pre-copied models
docker build -f Dockerfile.models -t ollama-preloaded:offline .
```

**Dockerfile.models:**
```dockerfile
FROM ollama/ollama:latest AS builder

# Copy pre-downloaded models
COPY ./models /root/.ollama/models

FROM ollama/ollama:latest

COPY --from=builder /root/.ollama /root/.ollama

ENV OLLAMA_HOST=0.0.0.0:11434
ENV OLLAMA_KEEP_ALIVE=24h

EXPOSE 11434

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -f http://localhost:11434 || exit 1

CMD ["serve"]
```

### Strategy 3: Use Pre-Built Complete Image (Fastest)

**When to use:** You already have the complete image built locally.

Since you already have `ollama-preloaded:latest` built, you can:

```bash
# Save the complete image
docker save ollama-preloaded:latest -o ollama-complete.tar

# Transfer to another machine, then:
docker load -i ollama-complete.tar

# Run immediately - no build needed!
docker run -d -p 11434:11434 ollama-preloaded:latest
```

**This is fastest because:**
- ✓ No build process
- ✓ No network calls
- ✓ Models already included
- ✓ Guaranteed to work

---

## Comparison Table

| Strategy | Network Needed | Build Time | Model Download | Setup Complexity |
|----------|---|---|---|---|
| Strategy 1 | On source only | ~40 min | Won't work offline | Low |
| Strategy 2 | On source only | ~5 min | Pre-downloaded | Medium |
| Strategy 3 | Only for initial | 0 min | Included | Lowest |

---

## Step-by-Step: Strategy 2 (Most Practical for Offline)

### Part A: Preparation (Machine WITH Network)

```bash
# 1. Pull and cache models
docker pull ollama/ollama:latest
docker run -d -v ollama_cache:/root/.ollama ollama/ollama:latest --name prep
docker exec prep ollama pull llama3.2
docker exec prep ollama pull gemma:2b
docker stop prep
docker rm prep

# 2. Extract models to directory
mkdir models
docker run --rm -v ollama_cache:/root/.ollama -v $(pwd)/models:/output \
  alpine:latest \
  cp -r /root/.ollama/models/* /output/

# 3. Save base image
docker save ollama/ollama:latest -o ollama-base.tar

# 4. Create directory structure
mkdir offline-build
cp ollama-base.tar offline-build/
cp -r models offline-build/
cp Dockerfile.models offline-build/
cp .dockerignore offline-build/

# 5. Compress for transfer (optional)
tar -czf offline-build.tar.gz offline-build/
```

### Part B: Deployment (Offline Machine)

```bash
# 1. Extract transferred files
tar -xzf offline-build.tar.gz
cd offline-build

# 2. Load base image
docker load -i ollama-base.tar

# 3. Build
docker build -f Dockerfile.models -t ollama-preloaded:local .

# 4. Run
docker run -d -p 11434:11434 --name ollama ollama-preloaded:local

# 5. Test
curl http://localhost:11434
curl http://localhost:11434/api/tags
```

---

## File Sizes Reference

When planning transfer:
- `ollama/ollama:latest` base image: ~3 GB
- `llama3.2:latest` model: ~2 GB
- `gemma:2b` model: ~1.7 GB
- **Total for all**: ~6.7 GB (compressed)

---

## Docker Image Cache Internals

Understanding how Docker caches work helps offline builds:

```
# Models are stored in:
/root/.ollama/
├── models/
│   ├── manifests/      # Image descriptions
│   ├── blobs/          # Actual model weights
│   └── ollama-lock
└── id_ed25519

# When you COPY models, you're copying these files
# The ollama binary can read them without network
```

---

## Troubleshooting Offline Builds

### Issue: "image not found" on offline machine

**Cause:** Base image not loaded before build

**Solution:**
```bash
docker load -i ollama-base.tar
docker build -f Dockerfile.models ...
```

### Issue: Models not found in offline build

**Cause:** Models directory not properly copied

**Solution:**
```bash
# Verify directory exists
ls -la models/
ls -la models/llama3.2/
ls -la models/gemma:2b/

# Check Dockerfile COPY path is correct
cat Dockerfile.models | grep COPY
```

### Issue: Build still trying to download models

**Cause:** Using wrong Dockerfile (one with ollama pull commands)

**Solution:**
```bash
# Use Dockerfile that COPYs models instead:
docker build -f Dockerfile.models ...  # Correct
# NOT:
docker build -f Dockerfile ...         # Wrong - tries to pull
```

---

## Creating Dockerfile.models

Here's the complete, tested version:

```dockerfile
# Stage 1: Builder (not really needed for offline, but kept for consistency)
FROM ollama/ollama:latest AS builder

# Models MUST be copied, not pulled
COPY ./models /root/.ollama/models

# Stage 2: Runtime
FROM ollama/ollama:latest

# Copy model cache
COPY --from=builder /root/.ollama /root/.ollama

# Configuration
ENV OLLAMA_HOST=0.0.0.0:11434
ENV OLLAMA_KEEP_ALIVE=24h
ENV OLLAMA_MAX_LOADED_MODELS=2
ENV OLLAMA_NUM_PARALLEL=2
ENV OLLAMA_FLASH_ATTENTION=1

EXPOSE 11434

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -f http://localhost:11434 || exit 1

CMD ["serve"]
```

---

## Best Practices for Offline

1. **Always test on the source machine first**
   ```bash
   docker build -f Dockerfile.models -t test:offline .
   docker run -d -p 11435:11434 test:offline
   curl http://localhost:11435
   ```

2. **Compress before transfer**
   ```bash
   tar -czf models.tar.gz models/
   # Then on offline machine:
   tar -xzf models.tar.gz
   ```

3. **Document model structure**
   ```bash
   # Include a file listing what's included
   echo "Models included:" > MODELS.txt
   du -sh models/* >> MODELS.txt
   ```

4. **Keep base image separate from models**
   - `ollama-base.tar` (~3 GB)
   - `models.tar.gz` (~3.5 GB)
   - Can update models without re-transferring base

5. **Verify checksums after transfer**
   ```bash
   # On source machine:
   sha256sum ollama-base.tar > checksums.txt
   
   # On offline machine:
   sha256sum -c checksums.txt
   ```

---

## Summary

**For your offline scenario:**

1. ✅ Save ollama base image: `docker save ollama/ollama:latest -o base.tar`
2. ✅ Copy local models directory
3. ✅ Use Dockerfile.models (COPY models, no RUN ollama pull)
4. ✅ Build offline: `docker build -f Dockerfile.models ...`
5. ✅ No network access needed!

This approach is bulletproof for offline environments.

