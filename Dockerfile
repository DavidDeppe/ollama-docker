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
