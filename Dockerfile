FROM python:3.13-slim

LABEL org.opencontainers.image.title="mcpo"
LABEL org.opencontainers.image.description="Docker image for mcpo (Model Context Protocol OpenAPI Proxy)"
LABEL org.opencontainers.image.licenses="MIT"
LABEL maintainer="flyfox666@gmail.com, biguncle2017@gmail.com"

# Install base dependencies, Node.js, and Git in a single layer (as root)
RUN set -eux; \
    # Configure apt sources (use Aliyun mirror)
    for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/debian.sources; do \
      [ -f "$f" ] && sed -i 's|deb.debian.org|mirrors.aliyun.com|g; s|security.debian.org|mirrors.aliyun.com|g' "$f" || true; \
    done && \
    # Install curl and ca-certificates first for NodeSource script
    apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && \
    # Add NodeSource repo for Node.js 22.x
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    # Update again after adding new source and install remaining packages, including git
    && apt-get update && apt-get install -y --no-install-recommends \
    bash \
    jq \
    nodejs \
    git \
    # Clean up apt cache
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    # Verify npm/npx and git installation path
    && echo "--- Debug: Verifying npm/npx/git path ---" \
    && which npm \
    && which npx \
    && which git || echo "npm, npx, or git not found immediately after install"

# Create application directories (as root)
RUN mkdir -p /app/config /app/logs /app/data /app/node_modules /app/.npm /app/.cache/uv

# Copy start script (as root)
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Create non-root user and grant ownership (as root)
RUN useradd -m -d /app -s /bin/bash appuser && chown -R appuser:appuser /app

# Switch to non-root user
USER appuser
WORKDIR /app

# Set environment variables for the non-root user
# Ensure user's local bin and Node's/Git's global bin are in PATH
ENV HOME=/app \
    PATH=/app/.local/bin:/usr/bin:/usr/local/bin:$PATH \
    UV_CACHE_DIR=/app/.cache/uv \
    NPM_CONFIG_CACHE=/app/.npm \
    MCPO_LOG_DIR="/app/logs"

# Accept PIP_SOURCE build argument
ARG PIP_SOURCE=""
# Make PIP_SOURCE available as an environment variable for the RUN layer below
ENV PIP_SOURCE=${PIP_SOURCE}

# Install uv using pip, respecting PIP_SOURCE via environment variable (as non-root user)
RUN set -eux; \
    echo "--- Debug: Checking PIP_SOURCE value ---"; \
    echo "PIP_SOURCE Env Var: ${PIP_SOURCE:-<not set or empty>}"; \
    # Set PIP_INDEX_URL environment variable if PIP_SOURCE is valid
    if [ -n "$PIP_SOURCE" ] && echo "$PIP_SOURCE" | grep -q '^https://'; then \
      export PIP_INDEX_URL="$PIP_SOURCE"; \
      echo "已设置 PIP_INDEX_URL 环境变量为: $PIP_INDEX_URL"; \
    else \
      echo "未设置自定义 pip 源，将使用默认源"; \
      # Unset PIP_INDEX_URL just in case it was inherited
      unset PIP_INDEX_URL; \
    fi; \
    # Install/upgrade pip and install uv for the user (pin version for reproducibility)
    echo "--- Debug: Upgrading pip ---"; \
    python -m pip install --upgrade pip --user; \
    echo "--- Debug: Installing uv (using source: ${PIP_INDEX_URL:-<default>}) ---"; \
    python -m pip install --user uv==0.6.14; \
    # Verify uv installation
    echo "--- Debug: Verifying uv installation ---"; \
    uv --version

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8000/docs || exit 1

ENTRYPOINT ["/app/start.sh"]
