FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HIKARI_API_CONFIG=/app/config.yaml

WORKDIR /app

COPY pyproject.toml README.md ./
COPY hikari_api ./hikari_api

RUN pip install --no-cache-dir .

COPY config.example.yaml ./config.yaml

RUN mkdir -p /app/data

EXPOSE 8000

CMD ["hikari-api"]
