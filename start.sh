#!/bin/bash
set -e

# 设置所有缓存和 HOME 目录到 /app，防止权限问题
export HOME=/app
export UV_CACHE_DIR=/app/.cache/uv
export NPM_CONFIG_CACHE=/app/.npm

date_str=$(date +"%Y%m%d_%H%M%S")
log_file="/app/logs/mcpo_${date_str}.log"

# 确保持久化目录存在（全部在 /app 下）
mkdir -p /app/data /app/node_modules /app/.npm /app/.cache/uv

# 动态安装 config.json 中声明的 mcp 工具
if [ -f /app/config/config.json ]; then
  echo "检测到 /app/config/config.json，准备动态安装 MCP 工具..."
  jq -r '.mcpServers | keys[]' /app/config/config.json | while read -r key; do
    (
      command=$(jq -r ".mcpServers[\"$key\"].command" /app/config/config.json)
      args=$(jq -r ".mcpServers[\"$key\"].args | @sh" /app/config/config.json)
      envs=$(jq -r ".mcpServers[\"$key\"].env // {} | to_entries[]? | \"export \(.key)=\\\"\(.value)\\\"\"" /app/config/config.json)
      # 设置环境变量
      if [ -n "$envs" ]; then
        eval "$envs"
      fi
      # 动态安装
      if [ "$command" = "uvx" ]; then
        echo "使用 uvx 安装: $args"
        eval uvx $args
      elif [ "$command" = "npx" ]; then
        echo "使用 npx 安装: $args"
        eval npx $args
      else
        echo "未知 command: $command，跳过 $key"
      fi
    )
  done
else
  echo "未检测到 /app/config/config.json，跳过 MCP 工具动态安装。"
fi

# 启动主服务
if [ ! -z "$MCPO_API_KEY" ]; then
  uvx mcpo --host 0.0.0.0 --port 8000 --config /app/config/config.json --api-key "$MCPO_API_KEY" 2>&1 | tee -a "$log_file"
else
  uvx mcpo --host 0.0.0.0 --port 8000 --config /app/config/config.json 2>&1 | tee -a "$log_file"
fi