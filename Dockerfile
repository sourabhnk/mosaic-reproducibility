# Mosaic reproducibility package — slim image
#
# Contains only the slim query layer (src/db/) and the run_repro driver
# (scripts/run_repro.py). The full production source (ingestion, MCP
# server, agent, billing) is held in a separate private repository.

FROM python:3.11-slim

WORKDIR /app

# psycopg native binding needs libpq + a build toolchain for psycopg-binary
# fallback. python-dotenv is pure Python.
RUN apt-get update && apt-get install -y --no-install-recommends \
        libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Install the two runtime deps directly — keeping the image lean.
RUN pip install --no-cache-dir \
        "psycopg[binary]>=3.1,<4" \
        "python-dotenv>=1.0"

ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

COPY src/      ./src/
COPY scripts/  ./scripts/
COPY fixtures/ ./fixtures/

# Default command runs the reproducibility driver against whatever
# DATABASE_URL is set in the environment, writing artifacts to /output.
CMD ["python", "-m", "scripts.run_repro", "--output", "/output"]
