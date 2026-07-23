# 第七套准生产发布演练：阶段 5 siye-world

## 一、阶段目标

本阶段发布并部署 `siyesummer/siye-world:0.0.1`，把阶段 4 的统一入口从 JSON 探针升级为完整前端入口：

```text
浏览器 -> 203.0.113.10:8090 -> edge-nginx
  /            -> siye-world:80
  /music-api/  -> music-api:3000
  /socket.io/  -> easy-chat:3030
  /api/        -> linux-server:8081
```

前端镜像通过仓库根 `.env.production` 编译 `203.0.113.10:8090` 演练入口，其中 music-api 追加 `/music-api`。该文件同时由普通 `yarn build`、Dockerfile 和 GitHub Actions 使用，是当前演练发布的唯一前端地址来源。服务器只拉取 Docker Hub 固定版本，不上传源码，不执行 `docker build`。备案完成后再把 `.env.production` 切换为三个独立 HTTPS 服务域名，并发布下一新版本，不能覆盖 `0.0.1`。

`siyefun.top` 不属于本阶段部署范围。Windows 服务器不使用 Docker，后续应基于同一正式 Git commit 单独生成版本化 `dist`，新增独立 Nginx 配置文件做灰度验证；不得修改服务器现有旧配置。本阶段不生成、不上传、不启用任何 `siyefun.top` 新配置。

仓库同时准备 `.env.pages + yarn build:pages`，用于在域名备案期间生成 GitHub Pages 项目站点制品。Pages 使用 `/siyeWorld/` 资源前缀和 `hash` 路由，并继续编译 `203.0.113.10:8090` 演练地址。但 Pages 页面是 HTTPS、演练接口是 HTTP，浏览器会拦截 Mixed Content，因此当前 Pages 只能验收静态页面、资源路径和 hash 路由，不能替代本阶段 `http://203.0.113.10:8090` 的完整业务验收。本阶段不创建或启用 Pages 发布 Workflow。

## 二、先完成 GitHub Actions 正式发布

在 `siyesummer/siyeWorld` 的 Actions 页面手动运行 `Release siye-world image`，首次保持 `bump=patch`。发布成功后确认：

- Docker Hub 存在 `siyesummer/siye-world:0.0.1`
- 同时存在 `sha-<commit>` 标签
- 支持 `linux/amd64` 和 `linux/arm64`
- Description 与 `deploy/siye-world/README.md` 一致
- Git Tag 和 GitHub Release 为 `siye-world-image-v0.0.1`

任一项失败都先停止，不部署不完整的发布结果。

## 三、生成并上传阶段 5 配置包

在本地 PowerShell 执行：

```powershell
tar -czf "$env:TEMP\siye-release-drill-phase5.tar.gz" `
  -C "E:\本地项目\frontend-knowledge\Docker专题\Docker演练" `
  siye-release-drill

tar -tzf "$env:TEMP\siye-release-drill-phase5.tar.gz"
scp "$env:TEMP\siye-release-drill-phase5.tar.gz" ubuntu@203.0.113.10:/tmp/
```

压缩包必须包含 `nginx/edge.conf` 和本文件，且不能包含服务器 `.env`。

## 四、服务器部署前检查

在腾讯云服务器执行：

```bash
cd /opt/docker-labs/siye-release-drill

docker compose --env-file .env -f compose.release-drill.yml ps
docker inspect --format \
  '{{.Name}} status={{.State.Status}} health={{.State.Health.Status}} restarts={{.RestartCount}}' \
  drill7-music-api drill7-linux-server drill7-mysql drill7-easy-chat drill7-edge-nginx

systemctl is-active music-api linux-server easy-chat
df -h / /var/lib/docker
stat -c '.env permission=%a owner=%U:%G' .env
```

五个容器必须仍为 `healthy/0`，三个 systemd 服务必须为 `active`。

## 五、安全更新演练目录

不要覆盖服务器 `.env`：

```bash
UPLOAD_DIR="/tmp/siye-release-drill-phase5-$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/opt/docker-labs/siye-release-drill-backup-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$UPLOAD_DIR"
tar -xzf /tmp/siye-release-drill-phase5.tar.gz -C "$UPLOAD_DIR"
SOURCE_DIR="$UPLOAD_DIR/siye-release-drill"
TARGET_DIR=/opt/docker-labs/siye-release-drill

test -f "$SOURCE_DIR/compose.release-drill.yml"
test -f "$SOURCE_DIR/nginx/edge.conf"
test -f "$SOURCE_DIR/阶段5-siyeWorld前端.md"
test ! -f "$SOURCE_DIR/.env"

cp -a "$TARGET_DIR" "$BACKUP_DIR"
cp "$SOURCE_DIR/compose.release-drill.yml" "$TARGET_DIR/"
cp "$SOURCE_DIR/.env.example" "$TARGET_DIR/"
cp "$SOURCE_DIR/阶段5-siyeWorld前端.md" "$TARGET_DIR/"
cp "$SOURCE_DIR/回滚步骤.md" "$TARGET_DIR/"
cp "$SOURCE_DIR/验收清单.md" "$TARGET_DIR/"
cp "$SOURCE_DIR/nginx/edge.conf" "$TARGET_DIR/nginx/"

stat -c '.env permission=%a owner=%U:%G' "$TARGET_DIR/.env"
echo "BACKUP_DIR=$BACKUP_DIR"
```

## 六、追加镜像版本并解析 Compose

只在缺少配置时追加：

```bash
cd /opt/docker-labs/siye-release-drill

grep -q '^SIYE_WORLD_IMAGE=' .env || \
  printf '\nSIYE_WORLD_IMAGE=siyesummer/siye-world:0.0.1\n' >> .env

chmod 600 .env

docker compose --env-file .env -f compose.release-drill.yml config --quiet
docker compose --env-file .env -f compose.release-drill.yml config --images
```

重点确认：

- `siye-world` 只加入 `edge-net`
- `siye-world` 没有宿主机端口
- `edge-nginx` 仍只发布 `8090 -> 80`
- 不存在 `build:`
- MySQL 仍没有宿主机端口

前端正式从网关提供服务后，浏览器 Origin 将变为 `http://203.0.113.10:8090`。确认以下三项白名单都包含这个完整 Origin：

```bash
grep -E '^(MUSIC_API_CORS_ALLOW_ORIGIN|LINUX_SERVER_CORS_ALLOW_ORIGINS|EASY_CHAT_CORS_ALLOW_ORIGIN)=' .env
```

如果缺少，使用 `nano .env` 分别追加 `http://203.0.113.10:8090`，保留已有 Origin，不能整行覆盖成单个值。修改后让三个服务读取新运行时配置：

```bash
docker compose --env-file .env -f compose.release-drill.yml \
  up -d --no-build --pull never --no-deps --force-recreate \
  music-api linux-server easy-chat

docker inspect --format \
  '{{.Name}} status={{.State.Status}} health={{.State.Health.Status}} restarts={{.RestartCount}}' \
  drill7-music-api drill7-linux-server drill7-easy-chat
```

等待三者重新达到 `healthy` 后再继续；MySQL 不应被重建。

## 七、拉取和检查正式镜像

```bash
docker compose --env-file .env -f compose.release-drill.yml pull siye-world

docker image inspect siyesummer/siye-world:0.0.1 \
  --format 'IMAGE_ID={{.Id}}
OS={{.Os}}
ARCH={{.Architecture}}
REPO_DIGESTS={{json .RepoDigests}}
HEALTHCHECK={{json .Config.Healthcheck}}'
```

记录 RepoDigest；不要重新构建或覆盖 `0.0.1`。

## 八、先验证前端容器，再切换网关

先只启动前端容器：

```bash
docker compose --env-file .env -f compose.release-drill.yml \
  up -d --no-build --pull never --no-deps siye-world

for i in $(seq 1 12); do
  HEALTH="$(docker inspect --format '{{.State.Health.Status}}' drill7-siye-world 2>/dev/null || true)"
  echo "[$i/12] health=$HEALTH"
  [ "$HEALTH" = healthy ] && break
  [ "$HEALTH" = unhealthy ] && break
  sleep 5
done

docker inspect --format \
  '{{.Name}} image={{.Config.Image}} status={{.State.Status}} health={{.State.Health.Status}} restarts={{.RestartCount}} networks={{json .NetworkSettings.Networks}}' \
  drill7-siye-world
```

通过 edge-nginx 容器内部网络直接验证前端，不改公网入口：

```bash
docker exec drill7-edge-nginx wget -qO- http://siye-world/health
docker exec drill7-edge-nginx wget -qO- http://siye-world/ | head -c 300
docker exec drill7-edge-nginx wget -qO- http://siye-world/log-query | head -c 300
```

三项成功后再让 edge-nginx 加载新配置：

```bash
docker compose --env-file .env -f compose.release-drill.yml \
  up -d --no-build --pull never --no-deps --force-recreate edge-nginx
```

使用 `--no-deps` 是为了避免阶段 4 曾发生的关联服务意外重建。

## 九、服务器统一入口验证

```bash
curl --fail --silent --show-error http://127.0.0.1:8090/ | head -c 300
curl --fail --silent --show-error http://127.0.0.1:8090/log-query | head -c 300
curl --fail --silent --show-error http://127.0.0.1:8090/health

curl --fail --silent --show-error --max-time 60 \
  'http://127.0.0.1:8090/music-api/search?keywords=test&limit=1&type=1' \
  -o /dev/null -w 'music-api HTTP %{http_code}\n'

curl --fail --silent --show-error --max-time 30 \
  'http://127.0.0.1:8090/api/logs/query?service=all&page=1&pageSize=3' \
  -o /dev/null -w 'linux-server HTTP %{http_code}\n'

curl --fail --silent --show-error --max-time 15 \
  -H 'Origin: http://203.0.113.10:8090' \
  'http://127.0.0.1:8090/socket.io/?EIO=4&transport=polling'
```

`/` 和 `/log-query` 都应返回同一前端 `index.html`；`/health` 仍返回 edge-nginx 健康 JSON。

## 十、浏览器完整验收

本地电脑直接打开：

```text
http://203.0.113.10:8090/
```

验证：

- 刷新 `/log-query` 等 history 路由不会 404
- 音乐搜索、歌单和播放相关请求走 `/music-api/*`
- Socket.IO 请求走 `/socket.io/*`
- 聊天保存、历史查询和日志查询走 `/api/*`
- Network 中不出现 `3100/3130/8181`
- 新消息刷新后仍存在，MySQL 同一 `message_id` 只有一条
- 六个容器全部 `healthy/0`，三个 systemd 服务仍为 `active`

## 十一、停止条件

出现以下任一情况立即按 `回滚步骤.md` 撤回阶段 5：

- 前端容器 `unhealthy` 或持续重启
- `/log-query` 刷新 404
- 请求仍包含编译时公网 IP 或 localhost
- edge-nginx 出现持续 `502/504` 或找不到 `siye-world`
- 后端业务链路发生回退

阶段 5 完成后再进入阶段 6 升级和回滚演练；在完整验收前不要关闭 `3100/3130/8181` 回滚入口。
