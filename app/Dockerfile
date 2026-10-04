# Built for linux/amd64 only. Azure Container Apps runs amd64 and nothing
# else, and the same image digest has to run in all three estates, so that
# decides the architecture for Cloud Run and Fargate too. On an Apple Silicon
# Mac this means building with --platform linux/amd64.

FROM python:3.12-slim AS builder

WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim

# Picks up Debian security fixes the upstream python image has not been
# rebuilt with yet. Two builds on different days can differ as a result,
# which is one more reason every estate runs the same pushed digest rather
# than its own build.
RUN apt-get update \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 1001 appuser

WORKDIR /app
COPY --from=builder /install /usr/local

# --chown so appuser can read the file whatever mode it had on the build host.
COPY --chown=appuser:appuser main.py .

USER appuser

ENV PORT=8080
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT}"]
