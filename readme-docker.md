# Docker 构建与部署指南（mcpo 项目）

本指南系统整理了 mcpo 项目在 Docker 容器环境下的构建、部署、常见问题排查与最佳实践，适用于开发、测试与生产环境的高效复现。

---

## 一、构建与部署流程

### 1. 环境准备

- 推荐使用 Docker 24+ 和 Docker Compose 2.x。
- 保证主机网络可访问官方 Debian、Node.js、uv、PyPI 源，或已配置国内镜像加速。

### 2. 目录结构与关键文件

- `Dockerfile`：容器构建脚本，已适配国内源、Node.js 22、uv、非 root 用户、最佳安全实践。
- `start.sh`：容器启动脚本，动态安装 MCP 工具，自动设置缓存目录，启动主服务。
- `docker-compose.yml`：编排文件，挂载配置、日志、数据、依赖缓存等目录，便于持久化和调试。
- `config.json`：MCP 工具配置，支持多种 command/args/env 组合，自动被 mcpo 识别。

### 3. 构建镜像

```bash
docker-compose build
```

- 自动替换 Debian 官方源为阿里云镜像，加速依赖安装。
- Node.js 22 通过官方 nodesource.com 源安装。
- uv 通过官方脚本安装。
- 所有缓存和数据目录均在 /app 下，避免权限问题。

### 4. 启动服务

```bash
docker-compose up -d
```

- 服务启动后，start.sh 会自动读取 config.json，动态安装所有 MCP 工具，并启动 mcpo 主服务。
- 日志可通过 `docker-compose logs -f` 实时查看。

---

## 二、常见问题排查与解决

### 1. 权限问题

**报错：**

```plaintext
mkdir: cannot create directory '/root': Permission denied
```

**原因：**

- 容器以非 root 用户运行，依赖工具默认写入 /root 目录，导致无权限。

**解决：**

- 所有缓存、数据、日志目录均迁移到 /app 下，并通过环境变量（HOME、UV_CACHE_DIR、NPM_CONFIG_CACHE）强制指定。
- Dockerfile 和 start.sh 已做相应处理，确保无权限冲突。

### 2. 网络与依赖安装慢/失败

**表现：**

- apt-get update、pip、npm、uv 安装缓慢或超时。

**解决：**

- Dockerfile 自动将 Debian 官方源替换为阿里云镜像，加速系统依赖安装。
- Node.js 22 仍用官方 nodesource.com 源，国内一般可访问。
- 如遇极端网络问题，可考虑自建代理或提前下载依赖。

### 3. Node.js 源 404

**表现：**

- 替换 Node.js 源为阿里云后 404。

**解决：**

- 只替换 Debian 源为阿里云，Node.js 22 保持官方 nodesource.com 源，避免 404。

### 4. 配置文件自动识别

- mcpo 支持通过 --config 传递 config.json，自动识别 mcpServers 下所有工具，无需手动处理每个 key。
- start.sh 只需保证依赖已安装，主服务启动时直接传递 config.json 即可。

---

## 三、关键注意事项

- **非 root 用户运行**：容器内所有操作均以 appuser 进行，提升安全性。
- **缓存与数据目录**：所有依赖缓存、数据、日志均在 /app 下，便于挂载和备份。
- **环境变量注入**：敏感信息通过 .env 文件和 docker-compose.yml 注入，避免硬编码。
- **健康检查**：Dockerfile 已内置健康检查，便于编排平台自动监控服务状态。
- **持久化挂载**：docker-compose.yml 建议挂载 config.json、logs、data、node_modules、.npm、.cache/uv 等目录，确保依赖和数据可持久化。

---

## 四、最佳实践建议

1. **目录规范**：所有持久化目录统一放在 /app 下，便于授权和挂载。
2. **环境变量管理**：敏感信息（如 API KEY）通过 .env 文件管理，切勿写入镜像或代码。
3. **依赖加速**：优先使用国内镜像源加速系统依赖安装，Node.js 22 用官方源。
4. **动态依赖安装**：start.sh 动态读取 config.json，自动安装所有 MCP 工具，便于扩展和维护。
5. **安全最小化**：只安装必要依赖，移除所有编译型和未用包，镜像体积小、安全性高。
6. **日志与监控**：日志持久化到 /app/logs，便于排查和监控。
7. **CI/CD 集成**：可在 CI/CD 流水线中直接复用本 Dockerfile 和 compose 配置，自动化构建与部署。

---

## 五、参考命令速查

- 构建镜像：`docker-compose build`
- 启动服务：`docker-compose up -d`
- 查看日志：`docker-compose logs -f`
- 进入容器：`docker-compose exec mcpo bash`
- 停止服务：`docker-compose down`

---

## 六、附录：常见问题与解决方案速查

| 问题描述                                                  | 解决方法                                            |
| --------------------------------------------------------- | --------------------------------------------------- |
| mkdir: cannot create directory '/root': Permission denied | 迁移所有缓存目录到 /app，并用 ENV/EXPORT 强制指定   |
| Node.js 源 404                                            | 只替换 Debian 源为阿里云，Node.js 用官方源          |
| 依赖安装慢                                                | 使用阿里云镜像加速系统依赖                          |
| 配置未生效                                                | 检查 config.json 路径和格式，确保 --config 正确传递 |

---

如有更多问题，建议查阅官方文档或联系维护者。
