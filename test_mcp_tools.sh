#!/bin/bash

# MCP 服务基础地址
BASE_URL="http://localhost:8000"

# 工具列表（根据 config.json）
TOOLS=("fetch" "amap-maps" "baidu-map" "brave-search" "tavily-mcp")

echo "==== MCP 工具基础功能自动化测试 ===="
echo "服务基础地址: $BASE_URL"
echo

for tool in "${TOOLS[@]}"; do
  echo "---- 测试 $tool ----"
  # 1. OpenAPI 文档可访问性
  echo -n "  [1] /$tool/docs 可访问性: "
  if curl -s -f "$BASE_URL/$tool/docs" > /dev/null; then
    echo "✅"
  else
    echo "❌ (无法访问 OpenAPI 文档)"
  fi

  # 2. 典型接口功能性（以 POST /query 或 /search 为例，参数需根据实际 API 调整）
  if [[ "$tool" == "amap-maps" || "$tool" == "baidu-map" || "$tool" == "brave-search" || "$tool" == "tavily-mcp" ]]; then
    echo -n "  [2] /$tool/query 或 /$tool/search 功能性: "
    # 尝试 POST /query
    if curl -s -f -X POST "$BASE_URL/$tool/query" -H "Content-Type: application/json" -d '{"q":"test"}' > /dev/null; then
      echo "✅ (POST /query)"
    elif curl -s -f -X POST "$BASE_URL/$tool/search" -H "Content-Type: application/json" -d '{"q":"test"}' > /dev/null; then
      echo "✅ (POST /search)"
    else
      echo "❌ (接口无响应或出错)"
    fi
  elif [[ "$tool" == "fetch" ]]; then
    echo -n "  [2] /$tool/fetch 功能性: "
    if curl -s -f -X POST "$BASE_URL/$tool/fetch" -H "Content-Type: application/json" -d '{"url":"https://www.example.com"}' > /dev/null; then
      echo "✅"
    else
      echo "❌ (接口无响应或出错)"
    fi
  else
    echo "  [2] 未定义典型接口测试"
  fi

  # 3. 错误处理测试
  echo -n "  [3] 错误参数处理: "
  if curl -s -f -X POST "$BASE_URL/$tool/query" -H "Content-Type: application/json" -d '{"bad":"param"}' | grep -q "error"; then
    echo "✅ (有错误提示)"
  else
    echo "⚠️ (未检测到错误提示，需人工检查)"
  fi

  echo
done

echo "==== 测试完成 ===="
echo "如有 ❌ 或 ⚠️ 项，请检查服务日志并根据 readme-docker.md 进行排查。"