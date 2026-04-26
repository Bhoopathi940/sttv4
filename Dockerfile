# Stage 1: Builder stage
FROM python:3.10.7-slim AS builder

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git build-essential ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY ./requirements.txt .

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

# Install Python dependencies (CPU only)
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir torch==2.7.0+cpu torchaudio==2.7.0+cpu \
        --index-url https://download.pytorch.org/whl/cpu && \
    pip install --no-cache-dir nemo_toolkit["asr"] && \
    pip install --no-cache-dir 'uvicorn[standard]' && \
    pip install --no-cache-dir -r requirements.txt && \
    pip cache purge

# Stage 2: Runtime stage
FROM python:3.10.7-slim

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy app code
COPY ./parakeet_service ./parakeet_service
COPY .env.example .env

# Copy virtual environment
COPY --from=builder /opt/venv /opt/venv

# Set environment variables
ENV PATH="/opt/venv/bin:${PATH}" \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    # Audio processing
    TARGET_SAMPLE_RATE=16000 \
    # Performance settings
    MODEL_PRECISION=int8 \
    DEVICE=cpu \
    BATCH_SIZE=4 \
    MAX_AUDIO_DURATION=30 \
    VAD_THRESHOLD=0.5 \
    PROCESSING_TIMEOUT=60 \
    # Logging
    LOG_LEVEL=INFO

EXPOSE 8000

CMD ["uvicorn", "parakeet_service.main:app", \
     "--host", "0.0.0.0", "--port", "8000"]