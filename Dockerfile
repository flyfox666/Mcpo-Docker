FROM python:3.11-slim
LABEL org.opencontainers.image.title="mcpo"
LABEL org.opencontainers.image.description="Docker image for mcpo (Model Context Protocol OpenAPI Proxy)"
LABEL org.opencontainers.image.licenses="MIT"

# 安装基本依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    nodejs \
    npm \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
	
# 安装uv
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="/usr/local/bin" sh

# 安装mcpo和相关工具
RUN uv pip install --system mcpo mcp-server-fetch

# 安装Node.js MCP服务器包,根据你自己的需要增加相应的mcp
RUN npm install -g \
    @amap/amap-maps-mcp-server \
    @baidumap/mcp-server-baidu-map \
    @modelcontextprotocol/server-brave-search \
    tavily-mcp@0.1.4
	
# 创建配置目录和日志目录 - 这是一个单独的RUN命令
RUN mkdir -p /app/config /app/logs
WORKDIR /app
EXPOSE 8000

# 环境变量，用于API密钥
ENV MCPO_API_KEY=""

# 设置日志输出目录
ENV MCPO_LOG_DIR="/app/logs"

# 测试uvx命令是否工作
RUN uvx --help

# 使用带日志输出的启动脚本
RUN echo '#!/bin/bash\n\
date_str=$(date +"%Y%m%d_%H%M%S")\n\
log_file="/app/logs/mcpo_${date_str}.log"\n\
if [ ! -z "$MCPO_API_KEY" ]; then\n\
RUN echo '#!/bin/bash\n\
date_str=$(date +"%Y%m%d_%H%M%S")\n\
log_file="/app/logs/mcpo_${date_str}.log"\n\
if [ ! -z "$MCPO_API_KEY" ]; then\n\
  uvx mcpo --host 0.0.0.0 --port 8000 --config /app/config/config.json --api-key $MCPO_API_KEY --timeout 600 2>&1 | tee -a "$log_file"\n\
else\n\
  uvx mcpo --host 0.0.0.0 --port 8000 --config /app/config/config.json --timeout 600 2>&1 | tee -a "$log_file"\n\
fi' > /app/start.sh && chmod +x /app/start.sh

ENTRYPOINT ["/app/start.sh"]
