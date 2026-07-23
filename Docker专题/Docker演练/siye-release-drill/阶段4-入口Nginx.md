# 第七套准生产发布演练：阶段 4 edge-nginx 统一入口

## 一、阶段目标

本阶段只增加一个 `edge-nginx` 容器，不加入 `siye-world` 前端镜像，也不替换宿主机现有 Nginx。

统一入口暂时使用：

```text
本地浏览器
  -> http://203.0.113.10:8090/music-api/*
  -> edge-nginx
  -> music-api:3000

本地浏览器
  -> http://203.0.113.10:8090/socket.io/*
  -> edge-nginx
  -> easy-chat:3030

本地浏览器
  -> http://203.0.113.10:8090/api/*
  -> edge-nginx
  -> linux-server:8081
```

`edge-nginx` 只加入 `edge-net`，不能加入 `data-net`，也不能访问 MySQL。`3100/3130/8181` 在阶段 4 验收期间先保留，用于对照和回滚；阶段 5 前端镜像验收完成后再关闭公网规则。

## 二、重要路由语义

- `/music-api/search` 转发为 music-api 的 `/search`，因此 Nginx 必须去掉 `/music-api` 前缀。
- `/socket.io/` 必须保留路径并支持 HTTP Upgrade，才能同时支持 polling 和 WebSocket。
- `/api/logs/query`、`/api/chat/messages` 转发到 linux-server 时必须保留 `/api` 前缀。
- `/health` 只检查 edge-nginx 自身；`/health/music-api`、`/health/easy-chat`、`/health/linux-server` 用于检查内部 DNS 和上游链路。

## 三、服务器执行前检查

执行目录不限：

```bash
echo "[INFO] 第七套当前状态"
cd /opt/docker-labs/siye-release-drill

docker compose \
  --env-file .env \
  -f compose.release-drill.yml \
  ps

docker inspect --format \
  '{{.Name}} image={{.Config.Image}} status={{.State.Status}} health={{.State.Health.Status}} restarts={{.RestartCount}}' \
  drill7-music-api \
  drill7-linux-server \
  drill7-mysql \
  drill7-easy-chat

echo "[INFO] 8090 端口"
sudo ss -lntp | grep ':8090 ' || true

echo "[INFO] 原 systemd 链路"
systemctl is-active music-api linux-server easy-chat

echo "[INFO] .env 权限"
stat -c '.env permission=%a owner=%U:%G' .env
```

继续条件：

- 四个现有容器均为 `running/healthy`，`RestartCount=0`
- `8090` 没有监听者
- 三个 systemd 服务仍为 `active`
- `.env` 权限为 `600`

如果 `8090` 已占用，先确认占用者，不要停止不认识的服务；改用其他宿主机端口时必须同步修改安全组和本地前端配置。

## 四、更新演练材料但保留服务器 `.env`

上传包解压后，将最新配置覆盖到现有目录；真实 `.env` 必须保留：

```bash
UPLOAD_DIR="/tmp/siye-release-drill-phase4-$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/opt/docker-labs/siye-release-drill-backup-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$UPLOAD_DIR"
tar -xzf /tmp/siye-release-drill-phase4.tar.gz -C "$UPLOAD_DIR"

SOURCE_DIR="$UPLOAD_DIR/siye-release-drill"
TARGET_DIR=/opt/docker-labs/siye-release-drill

test -f "$SOURCE_DIR/compose.release-drill.yml" \
  && echo "[OK] compose.release-drill.yml"
test -f "$SOURCE_DIR/nginx/edge.conf" \
  && echo "[OK] nginx/edge.conf"
test -f "$SOURCE_DIR/阶段4-入口Nginx.md" \
  && echo "[OK] 阶段4-入口Nginx.md"
test ! -f "$SOURCE_DIR/.env" \
  && echo "[OK] 上传包不包含 .env"

cp -a "$TARGET_DIR" "$BACKUP_DIR"

cp "$SOURCE_DIR/compose.release-drill.yml" "$TARGET_DIR/"
cp "$SOURCE_DIR/.env.example" "$TARGET_DIR/"
cp "$SOURCE_DIR/阶段4-入口Nginx.md" "$TARGET_DIR/"
cp "$SOURCE_DIR/回滚步骤.md" "$TARGET_DIR/"
cp "$SOURCE_DIR/验收清单.md" "$TARGET_DIR/"
mkdir -p "$TARGET_DIR/nginx"
cp "$SOURCE_DIR/nginx/edge.conf" "$TARGET_DIR/nginx/"

cd "$TARGET_DIR"
test -f .env && echo "[OK] 服务器 .env 未被覆盖"
stat -c '.env permission=%a owner=%U:%G' .env
echo "BACKUP_DIR=$BACKUP_DIR"
echo "UPLOAD_DIR=$UPLOAD_DIR"
```

## 五、只向服务器 `.env` 增加阶段 4 配置

不要重新复制 `.env.example`。先检查是否已存在配置：

```bash
cd /opt/docker-labs/siye-release-drill
grep -n '^EDGE_NGINX_' .env || true
```

如果没有输出，再追加：

```bash
cat >> .env <<'EOF'

EDGE_NGINX_IMAGE=docker.m.daocloud.io/library/nginx:1.27-alpine
EDGE_NGINX_BIND_ADDRESS=0.0.0.0
EDGE_NGINX_HOST_PORT=8090
EOF

chmod 600 .env
```

检查重复键和权限：

```bash
awk -F= '
  /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
  { count[$1]++ }
  END {
    failed=0
    for (key in count) {
      if (count[key] > 1) {
        print "[ERROR] duplicate key:", key, count[key]
        failed=1
      }
    }
    if (!failed) print "[OK] 没有重复配置键"
    exit failed
  }
' .env

grep '^EDGE_NGINX_' .env
stat -c '.env permission=%a owner=%U:%G' .env
```

## 六、解析 Compose 并检查边界

```bash
cd /opt/docker-labs/siye-release-drill

docker compose \
  --env-file .env \
  -f compose.release-drill.yml \
  config --quiet \
  && echo "[OK] Compose 配置解析通过"

docker compose \
  --env-file .env \
  -f compose.release-drill.yml \
  config --services

docker compose \
  --env-file .env \
  -f compose.release-drill.yml \
  config --images

docker compose \
  --env-file .env \
  -f compose.release-drill.yml \
  config > /tmp/drill7-phase4-config.yml

python3 - <<'PY'
import yaml

with open('/tmp/drill7-phase4-config.yml', encoding='utf-8') as file:
    config = yaml.safe_load(file)

services = config['services']
edge = services['edge-nginx']

print('edge_image =', edge['image'])
print('edge_ports =', edge.get('ports'))
print('edge_networks =', list(edge.get('networks', {})))
print('edge_volumes =', edge.get('volumes'))
print('mysql_ports =', services['mysql'].get('ports'))
print('build_services =', [name for name, value in services.items() if 'build' in value])

assert list(edge['networks']) == ['edge-net']
assert services['mysql'].get('ports') is None
assert all('build' not in value for value in services.values())
assert edge['ports'][0]['target'] == 80
assert edge['ports'][0]['published'] == '8090'
PY

echo "[OK] edge-nginx 网络、端口、挂载和镜像边界正确"
```

## 七、拉取镜像并校验 Nginx 配置

```bash
cd /opt/docker-labs/siye-release-drill

docker compose \
  --env-file .env \
  -f compose.release-drill.yml \
  pull edge-nginx

docker image inspect \
  docker.m.daocloud.io/library/nginx:1.27-alpine \
  --format 'IMAGE_ID={{.Id}}
OS={{.Os}}
ARCH={{.Architecture}}
REPO_DIGESTS={{json .RepoDigests}}'

docker compose \
  --env-file .env \
  -f compose.release-drill.yml \
  run --rm --no-deps edge-nginx nginx -t
```

`nginx -t` 必须同时出现 `syntax is ok` 和 `test is successful`。现有三个业务容器必须继续运行。

## 八、只启动 edge-nginx

```bash
cd /opt/docker-labs/siye-release-drill

docker compose \
  --env-file .env \
  -f compose.release-drill.yml \
  up -d \
  --no-build \
  --pull never \
  edge-nginx

for i in $(seq 1 12); do
  HEALTH="$(docker inspect \
    --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
    drill7-edge-nginx 2>/dev/null || true)"
  echo "[$i/12] health=$HEALTH"
  [ "$HEALTH" = "healthy" ] && break
  [ "$HEALTH" = "unhealthy" ] && break
  sleep 5
done

docker compose \
  --env-file .env \
  -f compose.release-drill.yml \
  ps

docker inspect --format \
  '{{.Name}} image={{.Config.Image}} status={{.State.Status}} health={{.State.Health.Status}} restarts={{.RestartCount}} networks={{json .NetworkSettings.Networks}}' \
  drill7-edge-nginx

sudo ss -lntp | grep ':8090 ' || true
docker logs --tail 50 drill7-edge-nginx
```

## 九、服务器统一入口冒烟

```bash
echo "[TEST] edge-nginx 自身"
curl --fail --silent --show-error --max-time 10 \
  http://127.0.0.1:8090/
echo
curl --fail --silent --show-error --max-time 10 \
  http://127.0.0.1:8090/health
echo

echo "[TEST] 三个内部上游"
for path in music-api easy-chat linux-server; do
  curl --fail --silent --show-error --max-time 15 \
    "http://127.0.0.1:8090/health/$path"
  echo
done

echo "[TEST] music-api 路由与前缀移除"
curl --fail --silent --show-error --max-time 60 \
  -o /tmp/drill7-edge-search.json \
  -w 'HTTP %{http_code} time=%{time_total}s size=%{size_download}\n' \
  'http://127.0.0.1:8090/music-api/search?keywords=test&limit=1&type=1'
head -c 300 /tmp/drill7-edge-search.json
echo

echo "[TEST] linux-server 路由"
curl --fail --silent --show-error --max-time 30 \
  -o /tmp/drill7-edge-logs.json \
  -w 'HTTP %{http_code} time=%{time_total}s size=%{size_download}\n' \
  'http://127.0.0.1:8090/api/logs/query?service=all&page=1&pageSize=3'
head -c 300 /tmp/drill7-edge-logs.json
echo

echo "[TEST] Socket.IO polling"
curl --fail --silent --show-error --max-time 15 \
  'http://127.0.0.1:8090/socket.io/?EIO=4&transport=polling' \
  -H 'Origin: http://localhost:8080'
echo
```

检查允许和拒绝来源：

```bash
echo "[TEST] 允许的 API Origin"
curl --silent --show-error --max-time 10 \
  -D - -o /dev/null \
  -X OPTIONS http://127.0.0.1:8090/api/chat/messages \
  -H 'Origin: http://localhost:8080' \
  -H 'Access-Control-Request-Method: POST'

echo "[TEST] 未授权的 API Origin"
curl --silent --show-error --max-time 10 \
  -D - -o /dev/null \
  -X OPTIONS http://127.0.0.1:8090/api/chat/messages \
  -H 'Origin: https://example.com' \
  -H 'Access-Control-Request-Method: POST'
```

## 十、公网与本地 siyeWorld 联调

先在腾讯云安全组临时允许 TCP `8090`。当前用户选择手动配置安全组；演练结束后必须删除或限制来源。

Windows PowerShell 先验证公网入口：

```powershell
curl.exe --noproxy "*" `
  --fail --silent --show-error --max-time 60 `
  -o NUL `
  -w "HTTP %{http_code} time=%{time_total}s size=%{size_download}`n" `
  "http://203.0.113.10:8090/music-api/search?keywords=test&limit=1&type=1"
```

在 `E:\本地项目\siyeWorld\.env.local` 使用：

```dotenv
VUE_APP_MUSIC_API_BASE_URL=http://203.0.113.10:8090/music-api
VUE_APP_SOCKET_URL=http://203.0.113.10:8090
VUE_APP_CHAT_HISTORY_API_BASE_URL=http://203.0.113.10:8090
VUE_APP_LOG_SERVER_BASE_URL=http://203.0.113.10:8090
```

修改后必须重启 `yarn serve`。至少验证：

- 音乐搜索、歌单和歌曲请求经过 `/music-api`
- Socket.IO polling/WebSocket 经过 `/socket.io`
- 消息保存、历史读取和日志查询经过 `/api`
- 刷新后消息仍存在，MySQL 中 `message_id` 无重复
- 浏览器 Network 面板不再出现 `3100/3130/8181` 请求

## 十一、最终状态和停止条件

```bash
docker inspect --format \
  '{{.Name}} status={{.State.Status}} health={{.State.Health.Status}} restarts={{.RestartCount}}' \
  drill7-music-api \
  drill7-linux-server \
  drill7-mysql \
  drill7-easy-chat \
  drill7-edge-nginx

docker logs --since 30m drill7-edge-nginx 2>&1 | \
  grep -Ei 'emerg|alert|crit|error|upstream timed out|connect\(\) failed|host not found' | \
  tail -n 50 || true
```

以下任一情况出现时停止阶段 4，并按 `回滚步骤.md` 只撤回 edge-nginx：

- edge-nginx `unhealthy` 或持续重启
- `nginx -t` 失败
- 任一上游通过直连端口正常，但统一入口持续返回 `502/504`
- Socket.IO polling 或 WebSocket 升级失败
- `/music-api` 前缀未正确去除
- edge-nginx 意外加入 `data-net` 或 MySQL 出现公网端口
- 原四个容器或 systemd 主链路受到影响

全部通过并填写 `验收清单.md` 后，阶段 4 才完成，下一项进入 `siye-world:0.0.1` 前端镜像发布与部署。
