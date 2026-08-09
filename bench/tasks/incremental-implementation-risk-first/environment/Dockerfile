FROM python:3.12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN git config --system user.email bench@example.com \
    && git config --system user.name Bench \
    && git config --system init.defaultBranch main \
    && git config --system --add safe.directory '*'

COPY app /app

RUN cd /app \
    && pip install --no-cache-dir -r requirements.txt \
    && git init \
    && git add -A \
    && git commit -q -m initial

WORKDIR /app
