# siye-stack 第六套完整多服务 Docker Compose 演练

这套演练把 mysql、linux-server、easy-chat、music-api 和 nginx 合并到同一套 Compose。它是并行学习环境，不替换服务器上的 systemd + 目录部署主链路。

## 一、拓扑和端口

浏览器 / siyeWorld
  |
  v
Nginx :80（宿主机只发布 8087:80）
  |-- /socket.io/ -> easy-chat:3030
  |-- /api/       -> linux-server:8081
  \-- 其他路径    -> music-api:3000
                         |
                         v
                      MySQL:3306

所有服务加入 app-net。mysql、linux-server、easy-chat 和 music-api 不映射宿主机端口。

## 二、目录和源码来源

仓库只保存 Compose、Dockerfile 和小型服务配置。准备脚本会从 E:/本地项目/NeteaseCloudMusicApi-private 复制完整 music-api 源码，从 E:/本地项目/java-project/linux-server/target 复制 JAR，并排除 node_modules、.git 和 .claude。

NeteaseCloudMusicApi-private/、linux-server/*.jar 和 .env 都被 .gitignore 排除，不会重复提交业务源码、构建产物或密码。

## 三、前置检查

先确认 docker version 和 docker compose version 可用。发布前按 Java 项目要求执行：

mvn -f E:/本地项目/java-project/linux-server/pom.xml test
mvn -f E:/本地项目/java-project/linux-server/pom.xml package -DskipTests

-f 明确指定 pom.xml，所以不要求当前 PowerShell 位于 Java 项目目录。

## 四、准备本地运行目录

在 PowerShell 执行：

    cd E:/本地项目/frontend-knowledge/Docker专题/Docker演练/siye-stack
    ./prepare-runtime.ps1 -Force
    $runtime = "$env:TEMP/siye-stack-runtime"
    cd $runtime

脚本会生成临时 .env 和 runtime-logs，并创建 4 个空日志文件，避免本地日志查询因为文件不存在返回 500。

## 五、本地环境变量和启动

本地 Docker Hub 访问不稳定时，在 .env 中把 MYSQL_IMAGE、JAVA_IMAGE、NODE_IMAGE 和 NGINX_BASE_IMAGE 改成 docker.m.daocloud.io/library/...，并设置两个本地演练密码。密码不要提交到仓库或服务器共享目录。

在临时目录执行：

    docker compose config
    docker compose build
    docker compose up -d
    docker compose ps

预期 lab6-mysql、lab6-linux-server、lab6-easy-chat、lab6-music-api、lab6-nginx 都是 running healthy。Compose 会等待 MySQL、Java、Socket 和 music-api 健康后才启动 Nginx。

## 六、网关验证

    docker exec lab6-nginx nginx -t
    curl.exe --fail http://127.0.0.1:8087/health
    curl.exe --fail http://127.0.0.1:8087/health/socket
    curl.exe --fail http://127.0.0.1:8087/health/linux-server
    curl.exe --fail --max-time 60 "http://127.0.0.1:8087/search?keywords=test&limit=1&type=1"
    curl.exe --fail "http://127.0.0.1:8087/socket.io/?EIO=4&transport=polling"

Socket.IO polling 响应应包含 sid、upgrades、pingInterval 和 pingTimeout。

## 七、聊天和日志验证

通过 Invoke-RestMethod 向 http://127.0.0.1:8087/api/chat/messages 发送一条 JSON 消息，再请求 GET /api/chat/messages?roomCode=public-room&pageSize=10。消息应能从同一套 MySQL 读取。

日志接口完整路径是 GET /api/logs/query?service=all&page=1&pageSize=10。本地空日志文件会返回空日志分页，聊天历史会聚合为 easy-chat-history 记录。

使用 docker exec lab6-nginx getent hosts mysql linux-server easy-chat music-api 检查内部 DNS。使用 docker port lab6-mysql、docker port lab6-linux-server、docker port lab6-easy-chat 和 docker port lab6-music-api 确认没有输出，只有 docker port lab6-nginx 显示 8087。

## 八、本地前端联调入口

统一网关入口为 http://YOUR_SERVER_IP:8087：音乐 API、Socket.IO、聊天历史和日志查询都使用这个地址。临时前端需要把 packages/siye-core/src/modules/request.js 的 BASE_URL、packages/easy-chat/config/index.js 的 Socket 端口和聊天历史地址、src/api/logs.js 的日志地址统一切到 8087。

这几项属于临时联调修改，不要删除已经跑通的 3000、3030、8081 和第五套 8086 入口。

## 九、服务器部署

服务器端口规划为新端口 8087。先用 sudo ss -lntp | grep ':8087 ' || true 确认未占用，再上传临时运行目录的压缩包。上传包必须排除 .env；服务器进入 /opt/docker-labs/siye-stack 后重新执行 cp .env.example .env 并设置服务器专用密码。

服务器 .env 设置 SIYE_LOG_DIR=/var/log/siye，这样 Java 服务继续读取宿主机现有日志目录；基础镜像可按服务器网络情况改为 DaoCloud 地址。服务器执行 docker compose config、docker compose build、docker compose up -d，再用 curl http://127.0.0.1:8087/health 和公网 8087 端口验证。

当前 Node 容器日志默认写 Docker stdout，不会自动写入 /var/log/siye/music-api.log 和 socket.log；后续如需让日志查询覆盖 Docker stdout，还要增加日志采集方案。

## 十、停止和回滚

停止第六套但保留 MySQL 数据卷：docker compose down。不要执行 docker compose down -v，除非明确要删除第六套数据库。

回滚时先停止并备份 /opt/docker-labs/siye-stack，再恢复带时间戳的备份目录。整个过程不影响现有 systemd 服务和前五套 Docker 演练。

## 十一、本地验证记录

2026-07-15 Windows Docker Desktop 验证完成：4 个自定义镜像构建成功；5 个容器均为 running healthy；Nginx 配置测试成功；内部 DNS 正常；只有 8087 -> 80 对外发布；音乐搜索返回 code: 200；Socket.IO polling 返回 sid；聊天保存、MySQL 读取和 /api/logs/query 聚合均成功。

## 十二、Linux 服务器和本地前端验证记录

2026-07-15 Linux 服务器验证完成：

- `/opt/docker-labs/siye-stack` 中 5 个容器均为 `running healthy 0`
- 本地前端通过 `http://YOUR_SERVER_IP:8087` 完成音乐搜索、Socket.IO、聊天历史、聊天保存和日志查询
- 音乐搜索、聊天 GET/POST、Socket.IO polling 和日志查询均返回 `200`
- MySQL 中两条测试消息的 `sender_id` 不同，但 `client_ip` 都是 `192.0.2.10`
- 聊天历史返回两条消息且均为 `isSelf: true`
- `lab6-mysql`、`lab6-linux-server`、`lab6-easy-chat`、`lab6-music-api` 没有宿主机端口映射，只有 Nginx 发布 `8087 -> 80`
