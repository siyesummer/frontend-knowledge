# Nginx + music-api 共享网络 Docker Compose 演练

## 一、演练目标

这是第五套 Docker 演练，目标是把 Nginx 和 music-api 放进同一份 Compose、同一张 Docker 网络，通过服务名直接通信。

请求链路：

```text
浏览器或 curl
  -> 宿主机 8086
  -> lab5-nginx 容器 80
  -> app-net 网络中的 music-api:3000
  -> lab5-music-api 容器 3000
```

与第四套的区别：

```text
第四套：Nginx -> host.docker.internal:3002 -> 宿主机端口 -> music-api
第五套：Nginx -> music-api:3000 -> Docker 内部网络 -> music-api
```

第五套中的 music-api 不使用 `ports`，不会暴露新的宿主机端口。外部只能通过 Nginx 的 `8086` 访问它。

## 二、为什么使用服务名 music-api

Compose 会为同一项目中的服务提供内部 DNS。下面的服务名：

```yaml
services:
  music-api:
```

会在 `app-net` 网络中自动成为可解析的主机名 `music-api`，所以 Nginx 可以配置：

```nginx
proxy_pass http://music-api:3000;
```

这里使用的是 Compose 服务名，不是宿主机 IP，也不依赖 `container_name`。即使以后容器重新创建、容器 IP 变化，服务名仍然保持不变。

## 三、ports 和 expose 的区别

Nginx 使用：

```yaml
ports:
  - "8086:80"
```

表示宿主机和公网可以通过 `8086` 进入容器 `80`。

music-api 使用：

```yaml
expose:
  - "3000"
```

表示这个端口用于说明容器内部服务端口，不会建立宿主机端口映射。实际通信权限主要由两个服务是否处于同一 Docker 网络决定。

## 四、目录结构

```text
nginx-music-api-network/
├── .env.example
├── .gitignore
├── docker-compose.yml
├── music-api.Dockerfile
├── DOCKER_LAB_STEPS.md
├── NeteaseCloudMusicApi-4.13.8/
└── nginx/
    ├── Dockerfile
    └── default.conf
```

仓库中不保存完整 NeteaseCloudMusicApi 源码，只保留空目录标记。进行本地或服务器构建时，需要把本地完整源码放入 `NeteaseCloudMusicApi-4.13.8/`。

## 五、Compose 启动顺序

music-api 配置了 TCP 健康检查。Nginx 配置：

```yaml
depends_on:
  music-api:
    condition: service_healthy
```

因此 Compose 会先启动 music-api，等它的容器内 `3000` 端口健康后，再启动 Nginx。这比只使用 `service_started` 更严格，因为“进程已经创建”不等于“接口已经可以接收请求”。

## 六、本地准备临时运行目录

不要把完整业务源码复制进知识仓库。使用 Windows 临时目录准备一份可运行副本。

本地 PowerShell：

```powershell
$labSource = "E:\github项目\frontend-knowledge\Docker专题\docker-labs\nginx-music-api-network"
$labRuntime = "$env:TEMP\nginx-music-api-network-runtime"

if (Test-Path $labRuntime) {
  Remove-Item -LiteralPath $labRuntime -Recurse -Force
}

Copy-Item $labSource $labRuntime -Recurse

robocopy `
  "E:\本地项目\NeteaseCloudMusicApi-4.13.8" `
  "$labRuntime\NeteaseCloudMusicApi-4.13.8" `
  /E /XD node_modules .git .claude

if ($LASTEXITCODE -ge 8) {
  throw "复制 music-api 源码失败，robocopy exit code: $LASTEXITCODE"
}
```

说明：

- 临时目录可以安全清理，不会修改知识仓库或原始业务源码。
- 排除 `node_modules`，Linux 镜像会在构建时安装自己的生产依赖。
- `robocopy` 返回 `0-7` 都可能表示成功或有文件被复制，只有 `8` 及以上表示失败。

## 七、本地环境变量

```powershell
cd "$env:TEMP\nginx-music-api-network-runtime"
Copy-Item .env.example .env
```

当前网络访问 Docker Hub 不稳定，把两个基础镜像改为已经验证可用的代理：

```powershell
(Get-Content .env) `
  -replace '^NODE_IMAGE=.*$', 'NODE_IMAGE=docker.m.daocloud.io/library/node:20-bookworm-slim' `
  -replace '^NGINX_BASE_IMAGE=.*$', 'NGINX_BASE_IMAGE=docker.m.daocloud.io/library/nginx:1.27-alpine' |
  Set-Content .env

Get-Content .env
```

## 八、本地构建和配置检查

```powershell
cd "$env:TEMP\nginx-music-api-network-runtime"
docker compose config
docker compose build
docker compose run --rm nginx nginx -t
```

因为 Nginx 声明了 `depends_on: music-api`，执行这条 `compose run` 时 Compose 会先启动并等待 music-api 健康，再创建一次性 Nginx 容器。后续执行 `docker compose up -d` 会复用已经健康的 music-api 容器。

重点检查 `docker compose config`：

- 只有 Nginx 发布 `8086:80`。
- music-api 只有 `expose: 3000`，没有 `ports`。
- 两个服务都加入 `app-net`。
- Nginx 依赖 music-api 的健康状态。

## 九、本地启动和验证

```powershell
docker compose up -d
docker compose ps
```

期望：

```text
lab5-music-api   running healthy
lab5-nginx       running healthy
```

验证 Nginx：

```powershell
curl.exe --fail "http://127.0.0.1:8086/health"
```

验证代理链路：

```powershell
curl.exe --fail --max-time 30 "http://127.0.0.1:8086/search?keywords=test&limit=1&type=1"
```

验证内部 DNS 和配置：

```powershell
docker exec lab5-nginx getent hosts music-api
docker exec lab5-nginx grep -n "proxy_pass" /etc/nginx/conf.d/default.conf
```

应该能解析出 music-api 的容器内 IP，并看到：

```text
proxy_pass http://music-api:3000;
```

## 十、本地确认 music-api 没有暴露端口

```powershell
docker compose ps
docker port lab5-music-api
```

`docker port lab5-music-api` 没有输出，表示它没有宿主机端口映射。外部访问面只保留 Nginx `8086`。

## 十一、本地清理

```powershell
cd "$env:TEMP\nginx-music-api-network-runtime"
docker compose down
```

容器和网络会删除，构建好的两个镜像保留。

确认不再需要临时源码后再执行：

```powershell
Remove-Item -LiteralPath "$env:TEMP\nginx-music-api-network-runtime" -Recurse -Force
```

## 十二、生成服务器上传包

压缩包同时包含第五套 Compose 材料和完整 music-api 源码，但排除本地依赖与 Git 元数据。

```powershell
tar -czf "$env:TEMP\nginx-music-api-network-lab.tar.gz" `
  --exclude=node_modules `
  --exclude=.git `
  --exclude=.claude `
  --exclude=nginx-music-api-network/NeteaseCloudMusicApi-4.13.8 `
  -C "E:\github项目\frontend-knowledge\Docker专题\docker-labs" nginx-music-api-network `
  -C "E:\本地项目" NeteaseCloudMusicApi-4.13.8

scp "$env:TEMP\nginx-music-api-network-lab.tar.gz" `
  ubuntu@YOUR_SERVER_IP:/tmp/
```

## 十三、服务器解压和整理

```bash
UPLOAD_DIR="/tmp/nginx-network-lab-upload-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$UPLOAD_DIR"
tar -xzf /tmp/nginx-music-api-network-lab.tar.gz -C "$UPLOAD_DIR"

mv "$UPLOAD_DIR/NeteaseCloudMusicApi-4.13.8" \
  "$UPLOAD_DIR/nginx-music-api-network/"

test -f "$UPLOAD_DIR/nginx-music-api-network/docker-compose.yml"
test -f "$UPLOAD_DIR/nginx-music-api-network/music-api.Dockerfile"
test -f "$UPLOAD_DIR/nginx-music-api-network/NeteaseCloudMusicApi-4.13.8/app.js"
test -f "$UPLOAD_DIR/nginx-music-api-network/nginx/default.conf"
```

四条 `test` 没有输出表示通过。

## 十四、服务器备份和部署目录

如果旧的第五套演练已经存在，先停止它：

```bash
if [ -f /opt/docker-labs/nginx-music-api-network/docker-compose.yml ]; then
  cd /opt/docker-labs/nginx-music-api-network
  docker compose down
fi
```

备份并替换：

```bash
if [ -d /opt/docker-labs/nginx-music-api-network ]; then
  mv /opt/docker-labs/nginx-music-api-network \
    "/opt/docker-labs/nginx-music-api-network.bak-$(date +%Y%m%d-%H%M%S)"
fi

mv "$UPLOAD_DIR/nginx-music-api-network" \
  /opt/docker-labs/nginx-music-api-network

chown -R ubuntu:ubuntu /opt/docker-labs/nginx-music-api-network
```

## 十五、服务器环境变量和端口检查

```bash
cd /opt/docker-labs/nginx-music-api-network
cp .env.example .env

sed -i \
  's#^NODE_IMAGE=.*#NODE_IMAGE=docker.m.daocloud.io/library/node:20-bookworm-slim#' \
  .env

sed -i \
  's#^NGINX_BASE_IMAGE=.*#NGINX_BASE_IMAGE=docker.m.daocloud.io/library/nginx:1.27-alpine#' \
  .env

cat .env
sudo ss -lntp | grep ':8086 ' || true
```

没有进程监听 `8086` 才继续。

## 十六、服务器构建和启动

```bash
docker compose config
docker compose build
docker compose run --rm nginx nginx -t
docker compose up -d
docker compose ps
```

## 十七、服务器分层验证

```bash
docker inspect --format \
  '{{.Name}} {{.State.Status}} {{.State.Health.Status}} {{.RestartCount}}' \
  lab5-music-api lab5-nginx

curl --fail "http://127.0.0.1:8086/health"

curl --fail --max-time 30 \
  "http://127.0.0.1:8086/search?keywords=test&limit=1&type=1"

docker exec lab5-nginx getent hosts music-api
docker port lab5-music-api
```

期望：

- 两个容器都是 `running healthy 0`。
- 健康接口成功。
- 搜索接口返回 `code: 200`。
- Nginx 能解析 `music-api` 服务名。
- `docker port lab5-music-api` 没有输出。

## 十八、本地前端联调

腾讯云安全组允许 TCP `8086` 后，把本地前端音乐 API 地址临时切换为：

```text
http://YOUR_SERVER_IP:8086
```

搜索成功后，证明外部请求只能先进入 Nginx，再通过 Docker 内部网络访问 music-api。

联调完成后，主测试入口仍切回 `http://YOUR_SERVER_IP:3000`。

## 十九、日志和排查

```bash
docker compose logs --tail=100 nginx
docker compose logs --tail=100 music-api
docker network inspect nginx-music-api-network_app-net
```

常见问题：

- Nginx 返回 `502`：先看 music-api 是否健康，再检查两个容器是否都在 `app-net`。
- `host not found in upstream "music-api"`：服务名错误或两个服务不在同一网络。
- `8086` 服务器本机成功但公网失败：检查腾讯云安全组。
- music-api 启动失败：查看依赖安装、入口文件和容器日志，不要先修改 Nginx。

## 二十、停止与影响范围

```bash
cd /opt/docker-labs/nginx-music-api-network
docker compose down
```

只会停止第五套的 `lab5-nginx`、`lab5-music-api` 和 `app-net`，不会影响：

- systemd music-api `3000`
- 第三套 Docker music-api `3002`
- 第四套 Docker Nginx `8085`
- 宿主机 Nginx `80/443`

## 二十一、完成标准

- 本地 Compose 构建和启动成功。
- `nginx -t` 通过。
- 两个容器达到 `running healthy 0`。
- Nginx 通过 `music-api:3000` 服务名访问上游。
- music-api 没有宿主机端口映射。
- `8086/health` 和 `8086/search` 成功。
- 本地前端通过 `YOUR_SERVER_IP:8086` 搜索成功。
- 原有 systemd 和前四套 Docker 演练服务不受影响。

## 二十二、本地验证记录

2026-07-14 已完成 Windows 本地验证：

- `siye-music-api-network:5.0.0` 和 `siye-nginx-music-api-network:5.0.0` 构建成功。
- `nginx -t` 返回配置语法正确。
- `lab5-music-api` 和 `lab5-nginx` 均达到 `running healthy 0`。
- `http://127.0.0.1:8086/health` 返回共享网络演练健康信息。
- `http://127.0.0.1:8086/search` 经 Nginx 代理后返回 `code: 200`。
- Nginx 容器把 `music-api` 服务名解析为 Docker 内部 IP，并使用 `proxy_pass http://music-api:3000`。
- `docker port lab5-music-api` 没有输出，确认 music-api 未映射宿主机端口。
- 本地测试容器、网络和临时源码目录已清理，两个 `5.0.0` 镜像保留。
- 本地验证完成后继续进行了 Linux 服务器验证，最终结果见下一节。

## 二十三、Linux 服务器验证记录

2026-07-14 已完成 Linux 服务器和本地前端验证：

- Linux 部署目录为 `/opt/docker-labs/nginx-music-api-network`。
- `lab5-music-api` 和 `lab5-nginx` 均达到 `running healthy 0`。
- Nginx 发布端口为 `8086 -> 80`，music-api 仅显示 `3000/tcp`，没有宿主机端口映射。
- Nginx 通过同一 `app-net` 网络中的 `music-api:3000` 访问上游。
- 本地 `siyeWorld` 通过 `http://YOUR_SERVER_IP:8086/search` 请求返回 `200 OK`。
- 浏览器响应头包含 `Access-Control-Allow-Origin: *`。
- 第五套共享网络演练至此完成；下一阶段进入完整多服务 Compose 整合和镜像发布准备。
