FROM python:3.12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN pip install --no-cache-dir pytest==8.3.3 pytest-randomly==3.16.0

COPY app /app

WORKDIR /app
