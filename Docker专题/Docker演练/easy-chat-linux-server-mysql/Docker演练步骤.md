# easy-chat + linux-server + MySQL Docker Compose 演练步骤

## 一、目标

这是第二套 Docker 演练，目标是在第一套 `mysql + linux-server` 的基础上，把 `easy-chat` 也纳入容器编排。

这套演练主要验证：

- `easy-chat` 容器启动
- 本地前端通过公网 IP 连到 Docker 版 `easy-chat`，完成实时广播
- 本地前端直接调用 Docker 版 `linux-server`，把聊天消息写入 MySQL
- 停止 `linux-server` 时 Socket 实时聊天仍可工作，验证两个服务已经解耦

## 二、当前演练端口规划

- 宿主机 `3308` -> 容器 `3306`（MySQL）
- 宿主机 `8084` -> 容器 `8081`（linux-server）
- 宿主机 `3031` -> 容器 `3030`（easy-chat）

当前不要占用：

- `3306`：当前宿主机 MySQL
- `3307`：第一套 Docker 演练 MySQL
- `3030`：当前 systemd 版 `easy-chat`
- `8081`：当前 systemd 版 `linux-server`
- `8082`：第一套 Docker 演练版 `linux-server`
- `8083`：当前 `siyeWorld` 临时静态站点

## 三、当前目录结构

- `docker-compose.yml`
- `.env.example`
- `linux-server/Dockerfile`
- `easy-chat/Dockerfile`
- `easy-chat/package.json`
- `easy-chat/server.js`
- `easy-chat/config/index.js`

补充说明：

- 这套目录里的 `easy-chat` 是为了 Docker 演练单独整理出来的一份最小运行副本
- 如果后续本地 `E:\本地项目\siyeWorld\packages\easy-chat` 有功能变更，记得同步更新这里的 `server.js`、`config/index.js` 和 `package.json`

## 四、本地准备 linux-server 的 jar

### 1. 打包

方式一，先进入项目目录：

```powershell
cd E:\本地项目\java-project\linux-server
mvn test
mvn package -DskipTests
```

方式二，直接指定 `pom.xml`：

```powershell
mvn -f E:\本地项目\java-project\linux-server\pom.xml test
mvn -f E:\本地项目\java-project\linux-server\pom.xml package -DskipTests
```

### 2. 复制 jar 到当前演练目录

```powershell
Copy-Item "E:\本地项目\java-project\linux-server\target\linux-server-0.0.1-SNAPSHOT.jar" "E:\本地项目\frontend-knowledge\Docker专题\Docker演练\easy-chat-linux-server-mysql\linux-server\linux-server-0.0.1-SNAPSHOT.jar" -Force
```

## 五、准备环境变量文件

把：

- `Docker专题/Docker演练/easy-chat-linux-server-mysql/.env.example`

复制成：

- `Docker专题/Docker演练/easy-chat-linux-server-mysql/.env`

示例：

```env
MYSQL_ROOT_PASSWORD=REPLACE_WITH_ROOT_PASSWORD
MYSQL_DATABASE=siye_chat_docker_lab_2
MYSQL_USER=siye_chat_lab
MYSQL_PASSWORD=REPLACE_WITH_APP_PASSWORD
MYSQL_HOST_PORT=3308
LINUX_SERVER_HOST_PORT=8084
EASY_CHAT_HOST_PORT=3031
SERVER_HOST=YOUR_SERVER_IP
```

## 六、上传演练目录到 Linux 服务器

建议上传到：

- `/opt/docker-labs/easy-chat-linux-server-mysql`

本地 PowerShell：

```powershell
scp -r "E:\本地项目\frontend-knowledge\Docker专题\Docker演练\easy-chat-linux-server-mysql" ubuntu@YOUR_SERVER_IP:/tmp/
```

服务器执行：

```bash
sudo mkdir -p /opt/docker-labs
sudo chown ubuntu:ubuntu /opt/docker-labs
sudo rm -rf /opt/docker-labs/easy-chat-linux-server-mysql
sudo mv /tmp/easy-chat-linux-server-mysql /opt/docker-labs/
sudo chown -R ubuntu:ubuntu /opt/docker-labs/easy-chat-linux-server-mysql
```

## 七、启动第二套 Docker 演练

```bash
cd /opt/docker-labs/easy-chat-linux-server-mysql
docker compose config
docker compose up -d --build
docker compose ps
```

这套配置显式声明了：

```yaml
networks:
  app-net:
    driver: bridge
```

也就是：

- 当前这套演练不再只依赖 Compose 自动默认网络
- 我们手动定义了一张 `app-net`
- `mysql`、`linux-server`、`easy-chat` 都接到这张网络里
- `linux-server` 仍通过服务名 `mysql:3306` 访问数据库
- `easy-chat` 虽然也在同一网络中，但不再调用 `linux-server`

## 八、基础验证

### 1. 验证 easy-chat 健康接口

```bash
curl "http://127.0.0.1:3031/health"
```

### 2. 验证 linux-server 聊天历史接口

```bash
curl "http://127.0.0.1:8084/api/chat/messages?roomCode=public-room&pageSize=10"
```

### 3. 验证 Socket.IO 握手

```bash
curl "http://127.0.0.1:3031/socket.io/?EIO=4&transport=polling"
```

如果这条返回了 `sid`、`upgrades` 等字段，说明 Docker 版 `easy-chat` 已经能对外握手。

## 九、端到端验证

这一步建议继续用你本地 `siyeWorld` 前端做真实联调。

把本地前端两个入口临时切到：

```text
Socket: http://YOUR_SERVER_IP:3031
聊天历史 API: http://YOUR_SERVER_IP:8084
```

然后在聊天页发送一条消息。

发送后在服务器上执行：

```bash
curl "http://127.0.0.1:8084/api/chat/messages?roomCode=public-room&pageSize=10"
curl "http://127.0.0.1:8084/api/logs/query?service=chat-history&page=1&pageSize=10"
```

如果能看到刚发出的消息，说明两条独立链路都已打通：

```text
本地前端 -> YOUR_SERVER_IP:3031 -> Docker 版 easy-chat -> 实时广播
本地前端 -> YOUR_SERVER_IP:8084 -> Docker 版 linux-server -> Docker 版 MySQL
```

浏览器 Network 中应看到 `POST http://YOUR_SERVER_IP:8084/api/chat/messages`。`easy-chat` 日志中不应出现 `persistChatMessage`。

把组件临时改成 `<EasyChat :persist-messages="false" />` 后再次发送：实时消息应正常，但不应出现保存请求，MySQL 也不应新增该消息。

## 十、查看日志

```bash
cd /opt/docker-labs/easy-chat-linux-server-mysql
docker compose logs -f
docker compose logs -f easy-chat
docker compose logs -f linux-server
docker compose logs -f mysql
```

## 十一、停止和清理

```bash
docker compose stop
docker compose down
docker compose down -v
```

说明：

- `down -v` 会删除这套第二演练环境里的 MySQL 数据
- 不会影响当前 systemd 版 `easy-chat`、`linux-server`
- 也不会影响第一套 `3307/8082` 的 Docker 演练环境

## 十二、当前这套演练的意义

第一套 `mysql + linux-server` 主要让你理解：

- Java 服务怎么容器化
- MySQL 数据怎么持久化
- 日志目录怎么挂载

第二套把 `easy-chat` 加进来之后，你会进一步理解：

- 多一个 Node 服务进入 Compose 后如何联动
- 同一个前端如何分别调用 Socket 服务和后端 API
- 实时通信与数据持久化如何拆成两个独立职责
- 服务在同一 Compose 中运行，不等于服务之间必须直接依赖

## 十三、前端直连 linux-server 架构的增量重建

聊天持久化职责迁移到前端后，只需要重建 `linux-server` 和 `easy-chat`，不需要重建 MySQL，也不能使用 `docker compose down -v`。

本地更新包：

```text
E:\本地项目\frontend-knowledge\Docker专题\Docker演练\easy-chat-linux-server-mysql-update.tar.gz
```

上传到服务器 `/tmp` 后，在服务器执行：

```bash
release_id=$(date +%Y%m%d-%H%M%S)
lab_dir=/opt/docker-labs/easy-chat-linux-server-mysql
backup_dir=/opt/docker-labs/easy-chat-linux-server-mysql.bak-$release_id

cp -a "$lab_dir" "$backup_dir"
tar -xzf /tmp/easy-chat-linux-server-mysql-update.tar.gz -C "$lab_dir"
cd "$lab_dir"

docker compose config

docker compose exec -T mysql sh -c \
  'mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"' \
  < mysql-chat-client-ip-migration.sql

docker compose exec -T mysql sh -c \
  'mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"' <<'SQL'
SHOW COLUMNS FROM chat_message LIKE 'client_ip';
SHOW INDEX FROM chat_message WHERE Key_name = 'idx_chat_message_client_ip';
SQL

docker compose build linux-server easy-chat
docker compose up -d --no-deps --force-recreate linux-server easy-chat
docker compose ps
```

`--no-deps` 表示本次不重建 MySQL；已有 `mysql_data` 数据卷保持不变。

IP 识别版本必须先执行迁移脚本，再重建 `linux-server`。旧消息无法可靠回填来源 IP，因此其 `client_ip` 保持 `NULL`，新消息才会记录 IP。

如果 Docker Hub 超时，可以通过构建参数临时切换基础镜像源：

```bash
JAVA_IMAGE=docker.m.daocloud.io/library/eclipse-temurin:21-jre \
NODE_IMAGE=docker.m.daocloud.io/library/node:20-bookworm-slim \
docker compose build linux-server easy-chat
```

重建后检查：

```bash
curl -fsS http://127.0.0.1:3031/health
curl -fsS "http://127.0.0.1:8084/api/chat/messages?roomCode=public-room&pageSize=10"
docker compose logs --tail=100 linux-server easy-chat
docker compose exec -T easy-chat sh -c \
  'grep -n "CHAT_HISTORY_API_BASE_URL\|persistChatMessage" /app/server.js /app/config/index.js || true'
```

最后一条命令预期没有输出。然后把本地前端切到 Socket `3031`、历史 API `8084` 做真实发送验证。

### 最终验证记录

2026-07-14 已完成服务器重建和本地前端联调：

- `lab2-linux-server`、`lab2-easy-chat`、`lab2-mysql` 均为 `running`，重启次数为 `0`
- MySQL 原有消息仍存在，证明 `mysql_data` 数据卷未被重建
- 本地前端通过 `3031` 完成 Socket 实时广播
- 本地前端 `POST http://YOUR_SERVER_IP:8084/api/chat/messages` 返回 `200`
- 消息 `docker-decouple-1825` 在 Docker MySQL 中只有一条，`save_count = 1`
- `easy-chat` 容器内不存在 `CHAT_HISTORY_API_BASE_URL` 或 `persistChatMessage`
