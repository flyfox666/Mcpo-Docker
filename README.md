# mcpo_docker_use
An example Docker image for [mcpo](https://github.com/open-webui/mcpo)（with api-key environment set; npm,curl,nodejs,uv Pre-Built;Pre-Built MCP:amap;baidumap;server-brave-search; tavily;fetch）, a tool that exposes MCP (Model Context Protocol) servers as OpenAPI-compatible HTTP endpoints for [OpenWebUI](https://github.com/open-webui/open-webui).

> Still waiting for the official mcpo docker!

## Quick start

```shell
# Pull the repo
git clone https://github.com/flyfox666/mcpo_docker_use.git
cd mcpo_docker_use

# Copy sample files and edit them as you like.
cp config.example.json config.json    #remember to update the apikey for the mcp if need
cp docker-compose.example.yml docker-compose.yml  #remember to update the environment parameter

# Create a container and wait for the servers to start.
# It may take time if you have many servers enabled.
docker compose up -d
```

you can use docker run as follow:
```shell
docker run -d \
  --name mcpo \
  --restart unless-stopped \
  -p 8000:8000 \
  -v "$(pwd)/config.json:/app/config/config.json" \
  -v "$(pwd)/logs:/app/logs" \
  -e MCPO_API_KEY=xxx \
  --health-cmd 'curl -f http://localhost:8000/docs' \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  --health-start-period=40s \
  ghcr.io/flyfox666/mcpo_docker_use

```

Or you can build the docker from source.

```shell
docker build -t mcpo .
```
## docker volumes & environment setting

Update the setting as your set in docker-compose.yml

    volumes:
      - ./config.json:/app/config/config.json
      - ./logs:/app/logs
    environment:
      - MCPO_API_KEY=xxxx  # set the API key for openwebui here
      
      # if needed ,update for your own parameter
      # - MCPO_HOST=0.0.0.0
      # - MCPO_PORT=8000
      # - MCPO_CONFIG=/app/config.json


### Connect OpenWebUI to your servers

> [OpenAPI Tool Servers details](https://docs.openwebui.com/openapi-servers/mcp)
>
> 
> [OpenAPI Tool Servers FAQ](https://docs.openwebui.com/openapi-servers/faq)

1. Open OpenWebUI > Settings > Tools
2. Add a connection `http://localhost:8000/fetch`
3. Add the apikey if you set in docker-compose.yml
4. Check available tools on the chat page


get the API key firstly for mcp like amap-maps；brave-search;tavily from their website.

get the example and guide from [mcpo.so](https://mcp.so/)

With mcpo, each MCP server gets a separate endpoint. For example:

- `http://localhost:8000/fetch`
- `http://localhost:8000/amap-maps`
- `http://localhost:8000/brave-search`
- `http://localhost:8000/tavily-mcp`
- 
## MCP configuration

Standard MCP configuration file, see [config.example.json](./config.example.json).

## License

MIT
