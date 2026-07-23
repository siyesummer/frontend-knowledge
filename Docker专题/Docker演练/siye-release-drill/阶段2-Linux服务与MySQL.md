# 第七套准生产发布演练：阶段 2 linux-server + MySQL

## 一、阶段目标

本阶段在已运行的 `drill7-music-api` 旁边增加：

- `siyesummer/linux-server:0.0.1`
- 官方 MySQL `8.0.39`（通过 DaoCloud 镜像地址拉取）
- `data-net` 内部数据库网络
- `mysql_data` 持久化数据卷

原 systemd `linux-server.service` 继续使用 `8081`，Docker 正式镜像临时使用 `8181 -> 8081`。MySQL 不映射宿主机端口。

## 二、正式发布证据

```text
GitHub Actions Run: 29485330681
Git Tag: linux-server-v0.0.1
Commit: a49c3a45ff6c2a1ef771cd241013b592c4f0cffe
Image: siyesummer/linux-server:0.0.1
Architectures: linux/amd64, linux/arm64
```

Docker Hub Description 已从 `linux-server/deploy/README.md` 同步。该版本已冻结，后续修改必须发布 `0.0.2`。

## 三、服务器前置检查

在腾讯云 Linux 服务器执行：

```bash
cd /opt/docker-labs/siye-release-drill

systemctl is-active linux-server
sudo ss -lntp | grep -E ':(8081|8181|3306) ' || true

docker compose --env-file .env -f compose.release-drill.yml ps
docker ps --format \
  'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'

df -h / /var/lib/docker
docker system df

stat -c 'log-dir owner=%U:%G uid=%u gid=%g mode=%a' /var/log/siye
find /var/log/siye -maxdepth 1 -type f -printf '%f uid=%U gid=%G mode=%m\n'
```

重点确认：

- systemd `linux-server.service` 为 `active`
- `8081` 仍由现有 Java 服务使用
- `8181` 未占用
- 宿主机 `3306` 可以由现有 MySQL 使用，因为 Docker MySQL 不映射该端口
- 记录 `/var/log/siye` 的数字 GID，后续写入 `SIYE_LOG_GID`

## 四、安装阶段 2 配置

上传包不包含 `.env`，也不包含 JAR、Dockerfile 或业务源码。解压后先备份服务器当前配置：

```bash
cd /opt/docker-labs/siye-release-drill

BACKUP_DIR="/opt/docker-labs/siye-release-drill-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp compose.release-drill.yml .env "$BACKUP_DIR/"
chmod 600 "$BACKUP_DIR/.env"

echo "BACKUP_DIR=$BACKUP_DIR"
```

将上传包解压到独立临时目录：

```bash
UPLOAD_DIR="/tmp/siye-release-drill-phase2-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$UPLOAD_DIR"

tar -xzf /tmp/siye-release-drill-phase2.tar.gz -C "$UPLOAD_DIR"
SOURCE_DIR="$UPLOAD_DIR/siye-release-drill"

test -f "$SOURCE_DIR/compose.release-drill.yml" \
  && echo '[OK] compose.release-drill.yml'
test -f "$SOURCE_DIR/阶段2-Linux服务与MySQL.md" \
  && echo '[OK] 阶段2-Linux服务与MySQL.md'
test ! -f "$SOURCE_DIR/.env" \
  && echo '[OK] 上传包不包含 .env'
```

验证后只替换 Compose、`.env.example` 和文档，不覆盖服务器 `.env`：

```bash
cd /opt/docker-labs/siye-release-drill

cp "$SOURCE_DIR/compose.release-drill.yml" ./
cp "$SOURCE_DIR/.env.example" ./
cp "$SOURCE_DIR/阶段2-Linux服务与MySQL.md" ./
cp "$SOURCE_DIR/阶段1-发布演练.md" ./
cp "$SOURCE_DIR/回滚步骤.md" ./
cp "$SOURCE_DIR/验收清单.md" ./

stat -c '.env permission=%a owner=%U:%G' .env
```

`.env` 权限应仍为 `600`。开始追加阶段 2 变量前，不要删除备份目录。

## 五、追加阶段 2 环境变量

先确认阶段 1 `.env` 中尚无 MySQL 配置：

```bash
cd /opt/docker-labs/siye-release-drill

if grep -q '^MYSQL_IMAGE=' .env; then
  echo '[ERROR] .env 已包含阶段 2 配置，不要重复追加'
  exit 1
fi
```

生成演练专用随机密码并追加配置：

```bash
umask 077
MYSQL_ROOT_PASSWORD_VALUE="$(openssl rand -hex 32)"
MYSQL_PASSWORD_VALUE="$(openssl rand -hex 32)"
SIYE_LOG_GID_VALUE="$(stat -c '%g' /var/log/siye)"

cat >> .env <<EOF

MYSQL_IMAGE=docker.m.daocloud.io/library/mysql:8.0.39
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD_VALUE
MYSQL_DATABASE=siye_chat_release_drill
MYSQL_USER=siye_chat_release
MYSQL_PASSWORD=$MYSQL_PASSWORD_VALUE

LINUX_SERVER_IMAGE=siyesummer/linux-server:0.0.1
LINUX_SERVER_BIND_ADDRESS=0.0.0.0
LINUX_SERVER_HOST_PORT=8181
LINUX_SERVER_CORS_ALLOW_ORIGINS=http://localhost:8080,http://127.0.0.1:8080,http://siyefun.top,https://music.siyes.cn
SIYE_LOG_DIR=/var/log/siye
SIYE_LOG_GID=$SIYE_LOG_GID_VALUE
EOF

unset MYSQL_ROOT_PASSWORD_VALUE MYSQL_PASSWORD_VALUE SIYE_LOG_GID_VALUE
chmod 600 .env
```

不要把 `.env` 内容完整粘贴到对话或截图中。后续检查时只显示脱敏结果。

## 六、解析 Compose，但不启动

```bash
cd /opt/docker-labs/siye-release-drill

docker compose --env-file .env -f compose.release-drill.yml config --quiet
docker compose --env-file .env -f compose.release-drill.yml config --images
docker compose --env-file .env -f compose.release-drill.yml config --services

if docker compose --env-file .env -f compose.release-drill.yml config \
  | grep -q '^[[:space:]]*build:'; then
  echo '[ERROR] 检测到服务器构建配置'
else
  echo '[OK] 不存在 build 配置'
fi
```

应只包含 `mysql`、`music-api`、`linux-server` 三个服务。MySQL 不应出现 `published` 端口，linux-server 应为 `8181 -> 8081`。

## 七、拉取正式镜像并记录 digest

```bash
docker compose --env-file .env -f compose.release-drill.yml \
  pull mysql linux-server

docker image inspect siyesummer/linux-server:0.0.1 \
  --format 'IMAGE_ID={{.Id}} OS={{.Os}} ARCH={{.Architecture}} REPO_DIGESTS={{json .RepoDigests}}'
```

服务器为 `amd64`，镜像检查结果应显示 `linux/amd64`。

## 八、分步启动

先启动 MySQL：

```bash
docker compose --env-file .env -f compose.release-drill.yml \
  up -d --no-build --pull never mysql

docker compose --env-file .env -f compose.release-drill.yml ps mysql
docker inspect --format \
  '{{.Name}} {{.State.Status}} {{.State.Health.Status}} {{.RestartCount}} {{json .NetworkSettings.Ports}}' \
  drill7-mysql
docker port drill7-mysql
```

`docker port drill7-mysql` 应无输出。MySQL 健康后再启动 Java：

```bash
docker compose --env-file .env -f compose.release-drill.yml \
  up -d --no-build --pull never linux-server

docker compose --env-file .env -f compose.release-drill.yml ps
docker inspect --format \
  '{{.Name}} user={{.Config.User}} status={{.State.Status}} health={{.State.Health.Status}} restarts={{.RestartCount}}' \
  drill7-linux-server
```

## 九、服务器冒烟验证

```bash
curl --fail --silent --show-error http://127.0.0.1:8181/health

curl --fail --silent --show-error \
  'http://127.0.0.1:8181/api/logs/query?service=all&page=1&pageSize=10'

curl -i -X OPTIONS http://127.0.0.1:8181/api/chat/messages \
  -H 'Origin: http://localhost:8080' \
  -H 'Access-Control-Request-Method: POST'

curl -i -X OPTIONS http://127.0.0.1:8181/api/chat/messages \
  -H 'Origin: https://example.com' \
  -H 'Access-Control-Request-Method: POST'
```

允许来源应返回 `Access-Control-Allow-Origin: http://localhost:8080`；未授权来源应返回 `403` 或至少不带该许可头。

使用唯一 `messageId` 执行聊天写入和查询：

```bash
MESSAGE_ID="release-drill-phase2-$(date +%s)"

curl --fail --silent --show-error \
  -X POST http://127.0.0.1:8181/api/chat/messages \
  -H 'Content-Type: application/json' \
  --data "{\"roomCode\":\"release-drill\",\"messageId\":\"$MESSAGE_ID\",\"senderId\":\"phase2-server-smoke\",\"userName\":\"phase2-smoke\",\"content\":\"linux-server 0.0.1 server smoke\",\"sendTime\":\"$(date '+%F %T')\",\"type\":\"USER\"}"

echo
echo "MESSAGE_ID=$MESSAGE_ID"

curl --fail --silent --show-error \
  'http://127.0.0.1:8181/api/chat/messages?roomCode=release-drill&pageSize=10'
```

在 MySQL 容器内确认每个冒烟 `message_id` 只有一条：

```bash
docker compose --env-file .env -f compose.release-drill.yml \
  exec -T mysql sh -c \
  'mysql --default-character-set=utf8mb4 -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"' <<'SQL'
SELECT
  message_id,
  COUNT(*) AS save_count
FROM chat_message
WHERE message_id LIKE 'release-drill-phase2-%'
GROUP BY message_id
ORDER BY MAX(id) DESC
LIMIT 5;
SQL
```

## 十、本地 siyeWorld 真实联调

临时把本地前端的 linux-server 基地址改为：

```text
http://203.0.113.10:8181
```

保持 music-api 为 `http://203.0.113.10:3100`，Socket 可继续使用当前已验证入口。至少验证：

- 日志查询
- 聊天消息保存
- 刷新后历史加载
- 浏览器 CORS
- Docker MySQL 中对应 `message_id` 只有一条

## 十一、确认旧链路未受影响

```bash
systemctl is-active linux-server
curl --fail --silent --show-error \
  'http://127.0.0.1:8081/api/logs/query?service=all&page=1&pageSize=1'

docker inspect --format \
  '{{.Name}} {{.State.Status}} {{.State.Health.Status}} {{.RestartCount}}' \
  drill7-mysql drill7-linux-server drill7-music-api
```

阶段 2 完成后，三个 Docker 容器与原 systemd 链路应同时可用。
