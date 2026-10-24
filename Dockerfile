FROM python:3.14.9-slim-trixie

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HIKARI_API_CONFIG=/app/config.yaml

WORKDIR /app

COPY pyproject.toml README.md LICENSE ./
COPY hikari_api ./hikari_api

RUN pip install --no-cache-dir .

COPY config.example.yaml ./config.yaml

EXPOSE 1210

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["python", "-c", "import urllib.request; from hikari_api.config import load_config; config = load_config(); urllib.request.build_opener(urllib.request.ProxyHandler({})).open(f'http://127.0.0.1:{config.server.port}{config.routes.health}', timeout=3).close()"]

CMD ["hikari-api"]
