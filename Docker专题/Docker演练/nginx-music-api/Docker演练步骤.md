# Nginx + music-api Docker Compose 演练步骤

## 一、演练目标

这是第四套 Docker 演练，目标是在不修改现有宿主机 Nginx 和域名配置的前提下，启动一套独立的 Docker Nginx，并反向代理第三套演练中的 Docker `music-api`。

请求链路是：

```text
浏览器或 curl
  -> 宿主机 8085
  -> lab4-nginx 容器 80
  -> host.docker.internal:3002
  -> lab3-music-api 容器 3000
```

端口安排：

- 现有 systemd `music-api`：宿主机 `3000`
- Docker `music-api`：宿主机 `3002 -> 容器 3000`
- 本次 Docker Nginx：宿主机 `8085 -> 容器 80`

本次不会占用宿主机 `80/443`，不会修改 `/etc/nginx`，也不会重启宿主机 Nginx。

## 二、为什么不直接写容器名 lab3-music-api

`lab3-music-api` 和 `lab4-nginx` 属于两个独立 Compose 项目，默认会进入两张不同的 Docker 网络。不同网络里的容器不能只靠容器名互相访问。

本次使用：

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

它会在容器内把 `host.docker.internal` 指向 Docker 宿主机网关。Nginx 先访问宿主机 `3002`，宿主机再根据端口映射把请求交给 `lab3-music-api:3000`。

这种方式适合当前“多个独立演练项目并行存在”的阶段。后续把 Nginx 和其他服务合并到同一套 Compose 时，再改为通过共享网络和服务名直接通信。

## 三、目录结构

```text
nginx-music-api/
├── .env.example
├── Dockerfile
├── docker-compose.yml
├── Docker演练步骤.md
└── nginx/
    └── default.conf.template
```

这套演练不需要复制业务源码。镜像只包含 Nginx 和一份配置模板。

## 四、Dockerfile 做了什么

```dockerfile
ARG NGINX_BASE_IMAGE=nginx:1.27-alpine
FROM ${NGINX_BASE_IMAGE}

COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
```

- `NGINX_BASE_IMAGE` 默认是官方 Nginx Alpine 镜像，也可以通过构建参数切换镜像代理。
- 配置被复制到 `/etc/nginx/templates/`，不是直接复制到 `/etc/nginx/conf.d/`。
- 官方 Nginx 镜像启动时会对模板执行 `envsubst`，生成 `/etc/nginx/conf.d/default.conf`。

Compose 中配置了：

```yaml
NGINX_ENVSUBST_FILTER: ^MUSIC_API_UPSTREAM$
```

这表示只替换模板里的 `${MUSIC_API_UPSTREAM}`。模板中的 `$host`、`$remote_addr`、`$scheme` 等 Nginx 自身变量会被保留，不会被环境变量替换成空字符串。

## 五、准备环境变量

本地 PowerShell：

```powershell
cd E:\本地项目\frontend-knowledge\Docker专题\Docker演练\nginx-music-api
Copy-Item .env.example .env
```

Linux 服务器：

```bash
cd /opt/docker-labs/nginx-music-api
cp .env.example .env
```

默认配置：

```env
NGINX_HOST_PORT=8085
NGINX_BASE_IMAGE=nginx:1.27-alpine
NGINX_APP_IMAGE=siye-nginx-music-api:1.0.0
MUSIC_API_UPSTREAM=host.docker.internal:3002
```

如果 Docker Hub 不可达，先测试：

```bash
docker pull docker.m.daocloud.io/library/nginx:1.27-alpine
```

成功后把 `.env` 中的基础镜像改为：

```env
NGINX_BASE_IMAGE=docker.m.daocloud.io/library/nginx:1.27-alpine
```

## 六、本地构建前检查

确认 Docker Engine：

```powershell
docker version
docker compose version
```

确认端口没有被占用：

```powershell
netstat -ano | Select-String ':3002\s|:8085\s'
```

没有输出表示两个端口当前空闲。

确认本地已经有第三套演练生成的镜像：

```powershell
docker image ls siye-music-api:4.13.8
```

## 七、本地启动 music-api 上游

如果本地没有运行 `music-api` 容器，执行：

```powershell
docker run -d `
  --name music-api-local-test `
  --init `
  -p 3002:3000 `
  -e NODE_ENV=production `
  -e TZ=Asia/Shanghai `
  -e CORS_ALLOW_ORIGIN=* `
  siye-music-api:4.13.8
```

验证上游：

```powershell
curl.exe --fail --max-time 30 "http://127.0.0.1:3002/search?keywords=test&limit=1&type=1"
```

上游失败时先修复 `music-api`，不要继续把 Nginx 返回的 `502` 当成 Nginx 配置错误。

## 八、本地构建和启动 Nginx

```powershell
cd E:\本地项目\frontend-knowledge\Docker专题\Docker演练\nginx-music-api
docker compose config
docker compose build
docker compose run --rm nginx nginx -t
docker compose up -d
docker compose ps
```

命令作用：

- `docker compose config`：展开 `.env` 并检查 Compose 配置。
- `docker compose build`：生成 `siye-nginx-music-api:1.0.0` 镜像。
- `docker compose run --rm nginx nginx -t`：创建一次性容器检查最终 Nginx 配置语法，完成后自动删除。
- `docker compose up -d`：后台启动正式演练容器。

## 九、本地分层验证

先验证 Nginx 自身健康接口：

```powershell
curl.exe --fail "http://127.0.0.1:8085/health"
```

预期：

```json
{"code":0,"service":"nginx-docker-lab","status":"ok"}
```

再通过 Nginx 请求真实音乐接口：

```powershell
curl.exe --fail --max-time 30 "http://127.0.0.1:8085/search?keywords=test&limit=1&type=1"
```

查看容器状态和日志：

```powershell
docker compose ps
docker compose logs --tail=100 nginx
```

## 十、本地测试后的清理

停止并删除本次 Nginx 容器和 Compose 网络，保留镜像：

```powershell
docker compose down
```

删除为了联调临时启动的本地 `music-api` 容器，保留镜像：

```powershell
docker rm -f music-api-local-test
```

## 十一、打包并上传服务器

本地 PowerShell：

```powershell
tar -czf "$env:TEMP\nginx-music-api-docker-lab.tar.gz" `
  --exclude=nginx-music-api/.env `
  -C "E:\本地项目\frontend-knowledge\Docker专题\Docker演练" nginx-music-api

scp "$env:TEMP\nginx-music-api-docker-lab.tar.gz" ubuntu@YOUR_SERVER_IP:/tmp/
```

只上传一个压缩包，因此只需要输入一次 SSH 密码。

## 十二、服务器解压与备份

```bash
UPLOAD_DIR="/tmp/nginx-lab-upload-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$UPLOAD_DIR"
tar -xzf /tmp/nginx-music-api-docker-lab.tar.gz -C "$UPLOAD_DIR"

test -f "$UPLOAD_DIR/nginx-music-api/docker-compose.yml"
test -f "$UPLOAD_DIR/nginx-music-api/Dockerfile"
test -f "$UPLOAD_DIR/nginx-music-api/nginx/default.conf.template"
```

三条 `test` 没有输出表示通过。

```bash
if [ -d /opt/docker-labs/nginx-music-api ]; then
  mv /opt/docker-labs/nginx-music-api \
    "/opt/docker-labs/nginx-music-api.bak-$(date +%Y%m%d-%H%M%S)"
fi

mv "$UPLOAD_DIR/nginx-music-api" /opt/docker-labs/nginx-music-api
chown -R ubuntu:ubuntu /opt/docker-labs/nginx-music-api
```

## 十三、服务器启动前检查

确认第三套 `music-api` 仍然可用：

```bash
docker inspect --format '{{.State.Status}} {{.RestartCount}}' lab3-music-api
curl --fail --max-time 30 \
  "http://127.0.0.1:3002/search?keywords=test&limit=1&type=1"
```

确认 `8085` 未被占用：

```bash
sudo ss -lntp | grep ':8085 ' || true
```

## 十四、服务器构建和启动

```bash
cd /opt/docker-labs/nginx-music-api
cp .env.example .env
sed -i \
  's#^NGINX_BASE_IMAGE=.*#NGINX_BASE_IMAGE=docker.m.daocloud.io/library/nginx:1.27-alpine#' \
  .env

docker compose config
docker compose build
docker compose run --rm nginx nginx -t
docker compose up -d
docker compose ps
```

## 十五、服务器验证

```bash
curl --fail "http://127.0.0.1:8085/health"
curl --fail --max-time 30 \
  "http://127.0.0.1:8085/search?keywords=test&limit=1&type=1"

docker inspect --format \
  '{{.State.Status}} {{.State.Health.Status}} {{.RestartCount}}' \
  lab4-nginx

docker compose logs --tail=100 nginx
```

期望容器状态：

```text
running healthy 0
```

## 十六、本地前端联调

如果腾讯云安全组允许 TCP `8085`，可以把本地前端音乐 API 地址临时切换为：

```text
http://YOUR_SERVER_IP:8085
```

搜索成功表示下面的完整链路已经跑通：

```text
本地前端 -> Docker Nginx -> Docker music-api -> 网易云接口
```

联调完成后，前端仍切回当前主测试入口 `http://YOUR_SERVER_IP:3000`。本次不修改 `music-api.siyes.cn` 的正式 Nginx 配置。

## 十七、日志和排查

```bash
cd /opt/docker-labs/nginx-music-api
docker compose ps
docker compose logs -f --tail=100 nginx
docker exec lab4-nginx nginx -T
```

常见现象：

- `/health` 成功但 `/search` 返回 `502`：Nginx 正常，上游 `3002` 不可达。
- 容器启动失败：先执行 `docker compose run --rm nginx nginx -t` 检查配置。
- 服务器本机 `8085` 成功但公网失败：检查腾讯云安全组，不要先修改 Nginx。
- 修改模板后只执行 `restart` 不会更新镜像，需要执行 `docker compose up -d --build --force-recreate`。

## 十八、停止和回滚

```bash
cd /opt/docker-labs/nginx-music-api
docker compose down
```

这个命令只删除第四套演练的 Nginx 容器和网络，不会停止 `lab3-music-api`，也不会影响宿主机 Nginx。

如果需要恢复旧演练目录，先保持第四套容器停止，再把对应的 `.bak-时间` 目录改回 `/opt/docker-labs/nginx-music-api`，重新执行配置检查和启动命令。

## 十九、完成标准

- `docker compose config` 通过。
- `nginx -t` 返回配置语法正确。
- `lab4-nginx` 为 `running healthy`，重启次数为 `0`。
- `127.0.0.1:8085/health` 返回成功。
- `127.0.0.1:8085/search` 返回音乐数据。
- 本地前端通过 `YOUR_SERVER_IP:8085` 搜索成功。
- `lab3-music-api` 和宿主机 Nginx 始终保持可用。

## 二十、本地验证记录

2026-07-14 已完成 Windows 本地验证：

- `siye-nginx-music-api:1.0.0` 镜像构建成功。
- `docker compose run --rm nginx nginx -t` 返回配置语法正确。
- `lab4-nginx` 达到 `running healthy 0`。
- `http://127.0.0.1:8085/health` 返回 Nginx 演练健康信息。
- `http://127.0.0.1:8085/search` 经 Nginx 代理后返回 `code: 200`。
- 容器内最终配置为 `proxy_pass http://host.docker.internal:3002`，`$host`、`$remote_addr` 等 Nginx 变量被正确保留。
- 本地测试容器和 Compose 网络已清理，`siye-nginx-music-api:1.0.0` 与 `siye-music-api:4.13.8` 镜像保留。
- 本地测试结束后容器已清理，Linux 服务器验证结果见下一节。

## 二十一、Linux 服务器验证记录

2026-07-14 已完成 Linux 服务器和本地前端验证：

- Linux 部署目录为 `/opt/docker-labs/nginx-music-api`。
- 服务器容器名为 `lab4-nginx`，镜像为 `siye-nginx-music-api:1.0.0`。
- 端口映射为 `8085 -> 80`，容器达到 `running healthy 0`。
- 本地 `siyeWorld` 通过 `http://YOUR_SERVER_IP:8085/search` 请求返回 `200 OK`。
- 浏览器响应头包含 `Access-Control-Allow-Origin: *`，上游 CORS 响应经过 Nginx 正常返回。
- 第四套演练没有修改宿主机 `/etc/nginx`，也没有占用宿主机 `80/443`。
- 第四套 Docker 演练至此完成；下一阶段进入共享网络与统一 Compose 编排。
