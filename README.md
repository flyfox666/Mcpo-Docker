# Docker 构建与部署指南（mcpo 项目）

感谢 @BigUncle 的更新

本指南系统整理了 mcpo 项目在 Docker 容器环境下的构建、部署、常见问题排查与最佳实践，反映了项目当前的最新状态。

---

## 一、项目概述与架构

本项目使用 Docker 和 Docker Compose 对 `mcpo` (Model Context Protocol OpenAPI Proxy) 进行容器化部署。核心设计思路包括：

- **动态依赖安装**：容器启动时，`start.sh` 脚本会读取 `config.json`，并根据其中定义的 `mcpServers` 动态安装所需的 Python (`uvx`) 和 Node.js (`npx`) 工具。
- **非 Root 用户运行**：容器最终以非 root 用户 `appuser` 运行，增强安全性。
- **依赖与数据持久化**：通过 Docker Compose 挂载卷，将配置、日志、数据以及 `uv`、`npm` 的缓存目录持久化到宿主机。
- **灵活的源配置**：支持通过构建参数 (`PIP_SOURCE`) 动态配置 `pip` 源，并默认使用阿里云镜像加速 `apt`。
- **环境隔离**：`start.sh` 中每个 MCP 工具的安装都在子 shell 中进行，避免环境变量冲突。

---

## 二、构建与部署流程

### 1. 环境准备

- **Docker & Docker Compose**: 推荐 Docker 24+ 和 Docker Compose 2.x。
- **`.env` 文件**: 在项目根目录创建 `.env` 文件，用于存放敏感信息和配置。包含 `MCPO_API_KEY`。可以参考 `.env.example`。

  ```dotenv
  # .env 文件示例
  # Docker 构建时使用的 pip 源 (可选, 留空则使用默认源)
  PIP_SOURCE=https://mirrors.aliyun.com/pypi/simple/

  # mcpo 运行时需要的 API Key (必需)
  MCPO_API_KEY=your_mcpo_api_key_here

  # 其他 mcp server 可能需要的 API Keys (根据 config.json 配置)
  # AMAP_MAPS_API_KEY=your_amap_key
  # ... 其他需要的环境变量
  ```

- **`config.json`**: 配置需要启动的 MCP 服务器。参考 `config.example.json`。
- **网络**: 确保可以访问 Debian (Aliyun mirror), NodeSource, PyPI (或指定的 `PIP_SOURCE`)。

### 2. 目录结构与关键文件

- `Dockerfile`: 定义镜像构建过程。
  - 基础镜像: `python:3.13-slim`
  - 安装: `bash`, `curl`, `jq`, `nodejs` (v22.x), `git`, `uv` (via pip)
  - 用户: 创建 `appuser` 并在其下运行。
  - 配置: 支持 `PIP_SOURCE` 构建参数。
- `start.sh`: 容器入口点脚本。
  - 设置 `HOME`, `UV_CACHE_DIR`, `NPM_CONFIG_CACHE`。
  - 创建持久化目录。
  - 读取 `config.json` 并动态安装 MCP 工具 (使用 `uvx` 或 `npx`)。
  - 启动 `mcpo` 主服务。
- `docker-compose.yml`: 定义服务、构建参数、卷挂载、环境变量。
  - 传递 `PIP_SOURCE` 给 Dockerfile。
  - 挂载 `./config.json`, `./logs`, `./data`, `./node_modules`, `./.npm`, `./.uv_cache`。
  - 通过 `env_file` 加载 `.env` 作为运行时环境变量。
- `readme-docker.md`: 本文档。
- `test_mcp_tools.sh`: 基础功能测试脚本。

### 3. 构建镜像

```bash
# 传递 PIP_SOURCE (如果 .env 中已定义, compose 会自动读取)
docker-compose build [--no-cache]
```

- `--no-cache`: 强制重新构建所有层，用于确保最新更改生效。
- 构建过程会使用 `.env` 文件中的 `PIP_SOURCE` (如果有效) 配置 `pip` 源。

### 4. 启动服务

```bash
# 启动服务 (后台运行)
docker-compose up -d
```

- `docker-compose.yml` 会加载 `.env` 文件中的变量作为容器的运行时环境变量。
- `start.sh` 会执行，动态安装 `config.json` 中定义的 MCP 工具。
- `mcpo` 主服务启动。

---

## 三、常见问题排查与解决

### 1. `npx: command not found` / `git: command not found`

- **原因**: `npx` (随 `nodejs` 安装) 或 `git` 未安装或其路径不在 `appuser` 的 `PATH` 环境变量中。
- **解决**:
  - 确认 `Dockerfile` 中 `apt-get install` 包含了 `nodejs` 和 `git`。
  - 确认 `ENV PATH` 指令包含了 `/usr/bin` (通常 `apt` 安装的 `nodejs` 和 `git` 在此)。Dockerfile 已包含 `/app/.local/bin:/usr/bin:/usr/local/bin:$PATH`。
  - 使用 `docker-compose build --no-cache` 重新构建。

### 2. `mkdir: cannot create directory '/root': Permission denied`

- **原因**: 容器以非 root 用户 `appuser` 运行，但脚本或依赖尝试写入 `/root` 目录 (如默认缓存路径)。
- **解决**:
  - 已将所有缓存目录 (`uv`, `npm`) 通过 `ENV` 指令 (`UV_CACHE_DIR`, `NPM_CONFIG_CACHE`, `HOME`) 重定向到 `/app` 下。
  - `start.sh` 中 `mkdir -p` 也只操作 `/app` 下的目录。
  - `docker-compose.yml` 中对应的卷挂载路径也已更新为 `/app/...`。

### 3. `pip` 未使用自定义源 (`PIP_SOURCE`)

- **原因**: 构建时未正确将 `PIP_SOURCE` 传递给 Dockerfile。
- **解决**:
  - 确保 `.env` 文件中有 `PIP_SOURCE=https://...`。
  - 确保 `docker-compose.yml` 的 `build.args` 部分包含 `- PIP_SOURCE=${PIP_SOURCE:-}`。
  - Dockerfile 使用 `ARG PIP_SOURCE` 接收，并通过 `export PIP_INDEX_URL` 在 `RUN` 层中使用。

### 4. 网络与依赖安装慢/失败

- **原因**: 网络连接不佳，访问官方源缓慢或超时。
- **解决**:
  - Dockerfile 已配置使用阿里云镜像加速 `apt`。
  - `pip` 可通过 `.env` 中的 `PIP_SOURCE` 配置国内镜像。
  - Node.js (NodeSource) 和 uv (PyPI/Mirror) 仍依赖网络，极端情况需考虑其他方案。

---

## 四、关键注意事项与最佳实践

- **非 Root 用户**: 始终以 `appuser` 运行容器。
- **持久化**: 明确挂载 `config.json`, `logs`, `data`, `node_modules`, `.npm`, `.uv_cache` 以保留状态和依赖。
- **Secrets**: 使用 `.env` 文件管理 API Key 等敏感信息，并通过 `env_file` 注入，**切勿**将 `.env` 文件 `COPY` 到镜像中或硬编码密钥。`.env` 文件应加入 `.gitignore`。
- **动态安装**: `start.sh` 的动态安装机制提供了灵活性，但也意味着首次启动或 `config.json` 变更后，启动时间会稍长。
- **版本固定**: 为提高可复现性，建议在 `Dockerfile` 中固定 `uv` 的版本 (`pip install --user uv==X.Y.Z`)，并在 `config.json` 中固定 `npx` 包的版本 (`@amap/amap-maps-mcp-server@X.Y.Z`)。
- **资源限制**: 在生产环境中，考虑在 `docker-compose.yml` 中为服务设置内存和 CPU 限制。
- **日志**: 日志输出到挂载的 `./logs` 目录，便于查看和管理。
- **测试**: 使用 `test_mcp_tools.sh` 脚本进行基础功能验证。

---

## 五、参考命令速查

- 构建镜像: `docker-compose build [--no-cache]`
- 启动服务 (后台): `docker-compose up -d`
