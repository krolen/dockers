# Aegra (https://github.com/aegra/aegra) - self-hosted LangSmith Deployments alternative.
# Source is fetched from GitHub at build time and pinned to an Aegra release tag.
ARG AEGRA_REF=v0.11.0
ARG PY_VERSION=3.12

FROM python:${PY_VERSION}-slim-bookworm AS base

ARG PY_VERSION

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100

WORKDIR /app

# Create non-root user for runtime
RUN addgroup --system app && adduser --system --ingroup app app

# -----------------------------
# Source stage: fetch pinned agra release from GitHub
# -----------------------------
FROM base AS source

ARG AEGRA_REF
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl \
    && mkdir -p /aegra \
    && curl -fsSL "https://github.com/aegra/aegra/archive/${AEGRA_REF}.tar.gz" -o /tmp/aegra.tgz \
    && tar -xzf /tmp/aegra.tgz --strip-components=1 -C /aegra \
    && rm /tmp/aegra.tgz \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------
# Builder stage
# -----------------------------
FROM base AS builder

# Retrieve the uv binary directly from the official image.
COPY --from=ghcr.io/astral-sh/uv:0.10.0 /uv /bin/uv

# Install system build dependencies required for compiling Python extensions.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy agra-api package files and workspace lockfile from the pinned source
COPY --from=source /aegra/libs/aegra-api/pyproject.toml /aegra/libs/aegra-api/README.md ./
COPY --from=source /aegra/uv.lock ./

# Install dependencies from lockfile (includes dev deps for example agents).
RUN uv export --frozen --no-emit-project --format=requirements-txt > requirements.txt && \
    uv pip install --system --compile-bytecode -r requirements.txt && \
    rm requirements.txt

# Copy the actual project source code and forced includes (alembic).
COPY --from=source /aegra/libs/aegra-api/src/ ./src/
COPY --from=source /aegra/libs/aegra-api/alembic.ini ./alembic.ini
COPY --from=source /aegra/libs/aegra-api/alembic/ ./alembic/

# Install the project package itself.
RUN uv pip install --system --compile-bytecode --no-deps .

# -----------------------------
# Final, minimal runtime image
# -----------------------------
FROM base AS final

# Install only minimal runtime libs
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Copy installed Python packages from the builder stage.
COPY --from=builder /usr/local/lib/python${PY_VERSION}/site-packages/ /usr/local/lib/python${PY_VERSION}/site-packages/
COPY --from=builder /usr/local/bin/ /usr/local/bin/

# Copy runtime assets required by the app and alembic
COPY --from=source /aegra/libs/aegra-api/alembic.ini ./alembic.ini
COPY --from=source /aegra/libs/aegra-api/alembic/ ./alembic/
COPY --from=source /aegra/aegra.json ./aegra.json
COPY --from=source /aegra/examples/ ./examples/

EXPOSE 2026

# Run as non-root
USER app

# Default command - can be overridden by docker-compose
CMD ["aegra", "serve"]
