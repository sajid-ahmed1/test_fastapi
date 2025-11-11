FROM python:3.12-slim AS base

# Avoid Python writing .pyc files and buffer stdout/err
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# System deps needed for numpy/scipy wheels
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        libopenblas-dev && \
    rm -rf /var/lib/apt/lists/*

FROM base AS builder
COPY requirements.txt /tmp/requirements.txt
RUN pip install --upgrade pip && \
    pip install --prefix=/install -r /tmp/requirements.txt

FROM base AS development
COPY --from=builder /install /usr/local
COPY . /app
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]

FROM base AS production
ENV UVICORN_WORKERS=2
COPY --from=builder /install /usr/local
COPY . /app
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
