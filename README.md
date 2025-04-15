I'd be happy to translate your README.md file to English for your GitHub project. Here's the professional translation:

# Docker Build and Deployment Guide (mcpo project)

Thanks to @BigUncle for the pull request

This guide systematically outlines the build, deployment, troubleshooting, and best practices for the mcpo project in Docker container environments, reflecting the project's current state.

---

## I. Project Overview and Architecture

This project uses Docker and Docker Compose for containerized deployment of `mcpo` (Model Context Protocol OpenAPI Proxy). Core design principles include:

- **Dynamic Dependency Installation**: At container startup, the `start.sh` script reads `config.json` and dynamically installs required Python (`uvx`) and Node.js (`npx`) tools based on defined `mcpServers`.
- **Non-Root User Execution**: The container ultimately runs as non-root user `appuser` to enhance security.
- **Dependency and Data Persistence**: Through Docker Compose volume mounts, configuration, logs, data, and cache directories for `uv` and `npm` are persisted to the host machine.
- **Flexible Source Configuration**: Supports dynamic configuration of `pip` sources via build argument (`PIP_SOURCE`), and uses Aliyun mirror by default to accelerate `apt`.
- **Environment Isolation**: In `start.sh`, each MCP tool installation occurs in a sub-shell to avoid environment variable conflicts.

---

## II. Build and Deployment Process

### 1. Environment Preparation

- **Docker & Docker Compose**: Docker 24+ and Docker Compose 2.x recommended.
- **`.env` File**: Create an `.env` file in the project root directory for sensitive information and configuration. Include `MCPO_API_KEY`. Refer to `.env.example`.

  ```dotenv
  # .env file example
  # pip source used during Docker build (optional, uses default source if empty)
  PIP_SOURCE=https://mirrors.aliyun.com/pypi/simple/

  # API Key required for mcpo runtime (required)
  MCPO_API_KEY=your_mcpo_api_key_here

  # Other API Keys that may be needed for mcp servers (according to config.json)
  # AMAP_MAPS_API_KEY=your_amap_key
  # ... other required environment variables
  ```

- **`config.json`**: Configure MCP servers to start. Refer to `config.example.json`.
- **Network**: Ensure access to Debian (Aliyun mirror), NodeSource, PyPI (or specified `PIP_SOURCE`).

### 2. Directory Structure and Key Files

- `Dockerfile`: Defines image build process.
  - Base image: `python:3.13-slim`
  - Installs: `bash`, `curl`, `jq`, `nodejs` (v22.x), `git`, `uv` (via pip)
  - User: Creates and runs as `appuser`.
  - Configuration: Supports `PIP_SOURCE` build argument.
- `start.sh`: Container entrypoint script.
  - Sets `HOME`, `UV_CACHE_DIR`, `NPM_CONFIG_CACHE`.
  - Creates persistence directories.
  - Reads `config.json` and dynamically installs MCP tools (using `uvx` or `npx`).
  - Starts `mcpo` main service.
- `docker-compose.yml`: Defines services, build parameters, volume mounts, environment variables.
  - Passes `PIP_SOURCE` to Dockerfile.
  - Mounts `./config.json`, `./logs`, `./data`, `./node_modules`, `./.npm`, `./.uv_cache`.
  - Loads `.env` as runtime environment variables via `env_file`.
- `readme-docker.md`: This document.
- `test_mcp_tools.sh`: Basic functionality test script.

### 3. Building the Image

```bash
# Pass PIP_SOURCE (compose will automatically read from .env if defined)
docker-compose build [--no-cache]
```

- `--no-cache`: Forces rebuild of all layers to ensure latest changes take effect.
- Build process uses `PIP_SOURCE` from `.env` file (if valid) to configure `pip` source.

### 4. Starting the Service

```bash
# Start service (run in background)
docker-compose up -d
```

- `docker-compose.yml` loads variables from `.env` as container runtime environment variables.
- `start.sh` executes, dynamically installing MCP tools defined in `config.json`.
- `mcpo` main service starts.

---

## III. Common Issues and Solutions

### 1. `npx: command not found` / `git: command not found`

- **Cause**: `npx` (installed with `nodejs`) or `git` not installed or their paths not in `appuser`'s `PATH` environment variable.
- **Solution**:
  - Confirm `Dockerfile`'s `apt-get install` includes `nodejs` and `git`.
  - Confirm `ENV PATH` directive includes `/usr/bin` (where `apt`-installed `nodejs` and `git` typically reside). Dockerfile already includes `/app/.local/bin:/usr/bin:/usr/local/bin:$PATH`.
  - Use `docker-compose build --no-cache` to rebuild.

### 2. `mkdir: cannot create directory '/root': Permission denied`

- **Cause**: Container runs as non-root user `appuser`, but scripts or dependencies attempt to write to `/root` directory (e.g., default cache paths).
- **Solution**:
  - All cache directories (`uv`, `npm`) redirected to `/app` via `ENV` directives (`UV_CACHE_DIR`, `NPM_CONFIG_CACHE`, `HOME`).
  - `mkdir -p` in `start.sh` only operates on directories under `/app`.
  - Corresponding volume mount paths in `docker-compose.yml` updated to `/app/...`.

### 3. `pip` not using custom source (`PIP_SOURCE`)

- **Cause**: `PIP_SOURCE` not correctly passed to Dockerfile during build.
- **Solution**:
  - Ensure `.env` file contains `PIP_SOURCE=https://...`.
  - Ensure `docker-compose.yml`'s `build.args` section includes `- PIP_SOURCE=${PIP_SOURCE:-}`.
  - Dockerfile receives with `ARG PIP_SOURCE` and uses via `export PIP_INDEX_URL` in `RUN` layers.

### 4. Slow/Failed Network and Dependency Installation

- **Cause**: Poor network connection, slow or timeout accessing official sources.
- **Solution**:
  - Dockerfile configured to use Aliyun mirror to accelerate `apt`.
  - `pip` can be configured with domestic mirrors via `PIP_SOURCE` in `.env`.
  - Node.js (NodeSource) and uv (PyPI/Mirror) still depend on network; consider alternative solutions in extreme cases.

---

## IV. Key Considerations and Best Practices

- **Non-Root User**: Always run containers as `appuser`.
- **Persistence**: Explicitly mount `config.json`, `logs`, `data`, `node_modules`, `.npm`, `.uv_cache` to preserve state and dependencies.
- **Secrets**: Manage API Keys and sensitive information with `.env` file, inject via `env_file`, **never** `COPY` `.env` into the image or hardcode keys. `.env` file should be in `.gitignore`.
- **Dynamic Installation**: `start.sh`'s dynamic installation mechanism provides flexibility, but means longer startup time on first launch or after `config.json` changes.
- **Version Pinning**: For reproducibility, recommend pinning `uv` version in `Dockerfile` (`pip install --user uv==X.Y.Z`) and `npx` package versions in `config.json` (`@amap/amap-maps-mcp-server@X.Y.Z`).
- **Resource Limits**: In production environments, consider setting memory and CPU limits for services in `docker-compose.yml`.
- **Logs**: Logs output to mounted `./logs` directory for easy viewing and management.
- **Testing**: Use `test_mcp_tools.sh` script for basic functionality verification.

---

## V. Quick Reference Commands

- Build image: `docker-compose build [--no-cache]`
- Start service (background): `docker-compose up -d`
