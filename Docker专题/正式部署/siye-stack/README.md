# siyes.cn 正式 Docker 部署基线

这里是正式部署草案，不是第七套演练目录。部署按生命周期拆成四个 Compose 项目，避免 Sub2API 的配置、密钥和数据库操作影响 siyeWorld 主业务。

## 目录与职责

```text
siye-stack/
├─ core/       siyeWorld、music-api、easy-chat、linux-server、MySQL
├─ sub2api/    Sub2API、PostgreSQL、Redis
├─ svg-draw/   svg-draw 静态镜像
└─ edge/       edge-nginx、8 个 Host、首页静态目录和 HTTPS
```

四个项目通过外部网络 `siye-prod-edge-net` 连接。只有 edge-nginx 发布宿主机端口；MySQL、PostgreSQL 和 Redis 只在各自内部网络通信，不发布公网端口。

根目录的 `stack.sh` 是 Linux 服务器上的编排入口。它不会读取示例 `.env`，不会删除数据卷，`down-*` 只能停止指定项目。

主站当前不制作 `siyes首页` 镜像。edge-nginx 只读挂载服务器现有 `/var/www/siyes.cn`，因此可以继续更新静态 HTML，也不会因为首页改动而重建业务镜像。`siyes.cn` 的 ICP 备案和公安联网备案流程均已完成，现有首页备案展示保持不动。首页内容稳定后，再决定是否独立镜像化。

## 当前镜像状态

- `siyesummer/siye-world:0.0.3`
- `siyesummer/music-api:0.0.2`（已发布，包含正式文件日志双写）
- `siyesummer/linux-server:0.0.1`
- `siyesummer/easy-chat:0.0.2`（已发布，包含正式文件日志双写）
- `siyesummer/svg-draw:0.0.1`
- `docker.m.daocloud.io/library/mysql:8.0.39`
- `docker.m.daocloud.io/library/nginx:1.27-alpine`
- Sub2API、PostgreSQL、Redis 使用 `sub2api/.env.example` 中已核对的 digest

`siyesummer/siye-world:0.0.4` 是 2026-07-20 误触 Workflow 产生的已发布历史制品，对应提交只有 easy-chat 文件日志变更，不作为本次部署候选。生产配置继续固定 `0.0.3`，不得按最高版本号自动升级。

## 第一次部署顺序

服务器目录建议为 `/opt/siye-production/`。分别上传四个子目录，并在每个目录建立权限为 `600` 的服务器 `.env`；不能直接使用示例密码。

### 1. 准备服务器配置

在 `core/`、`sub2api/`、`svg-draw/`、`edge/` 分别创建服务器 `.env`，然后：

```bash
cd /opt/siye-production
chmod 600 core/.env sub2api/.env svg-draw/.env edge/.env
chmod +x stack.sh
./stack.sh config
```

正式 Docker 日志使用 `/var/log/siye-production`，不能和 systemd 的 `/var/log/siye` 混用。先读取现有日志组 GID，再创建独立目录：

```bash
LOG_GID="$(stat -c '%g' /var/log/siye)"
sudo install -d -o ubuntu -g "$LOG_GID" -m 2775 /var/log/siye-production
echo "SIYE_LOG_GID=$LOG_GID"
stat -c 'path=%n permission=%a owner=%U:%G gid=%g' /var/log/siye-production
```

把输出的 GID 写入 `core/.env`。`music-api` 和 `easy-chat` 以读写方式挂载该目录并同时保留 Docker stdout/stderr；`linux-server` 只读挂载同一目录，因此日志查询页读取的是正式 Docker 日志，而不是旧 systemd 日志。

### 2. 依次启动三个上游项目

对 `core`、`sub2api`、`svg-draw` 分别执行：

```bash
cd /opt/siye-production/<项目目录>
docker compose --env-file .env -f compose.yml config --quiet
docker compose --env-file .env -f compose.yml pull
docker compose --env-file .env -f compose.yml up -d
docker compose --env-file .env -f compose.yml ps
```

Sub2API 的 PostgreSQL、Redis、应用数据由 `sub2api/` 独立管理，不复用 `/sub2api` 的 Compose、`.env` 或数据目录。

也可以由根脚本按固定顺序完成这三项和共享网络创建：

```bash
./stack.sh up
./stack.sh ps
```

### 3. 启动 edge-nginx HTTP 并行入口

先确认 `/var/www/siyes.cn/index.html` 仍包含已验证的 ICP 备案号和工信部链接：

```bash
cd /opt/siye-production/edge
docker compose --env-file .env -f compose.yml config --quiet
docker compose --env-file .env -f compose.yml up -d
docker compose --env-file .env -f compose.yml ps
```

等价的根脚本命令是 `./stack.sh up`；上面保留拆分后的单项目命令，便于只更新某一个边界。

并行 HTTP 入口为 `127.0.0.1:18080`。使用 Host 头逐个验证 8 个域名，主站会直接读取只读挂载的静态 HTML。

## HTTPS 阶段

证书使用 `siyes.cn` 与 `*.siyes.cn` 通配符组合，覆盖当前正式域名及后续新增的一层子域名。`knowledge.siyes.cn` 已预留给 `frontend-knowledge`，在应用和 edge Host 部署完成前不对外标记为可用。通过 `edge/compose.tls.yml` 挂载时必须只读挂载服务器整个 `/etc/letsencrypt`，不能只挂载 `live/siyes-production`，因为其中的证书通常是指向 `archive` 的软链接。

修改 `edge/.env`：

```text
EDGE_NGINX_SITES_FILE=./nginx/sites-https.conf
```

然后执行：

```bash
cd /opt/siye-production/edge
docker compose --env-file .env -f compose.yml -f compose.tls.yml config --quiet
docker compose --env-file .env -f compose.yml -f compose.tls.yml up -d --no-deps --force-recreate edge-nginx
```

HTTPS 并行入口为 `127.0.0.1:18443`。使用 `curl --resolve <host>:18443:127.0.0.1 https://<host>:18443/...` 验证证书 SNI 和路由。

DNSPod 自动续期 Hook 位于 `certbot/`，上传包不包含 Token；服务器凭据固定放在 `/etc/letsencrypt/dnspod.env`，权限必须为 `600 root:root`。2026-07-21 已完成 Certbot staging `renew --dry-run`：两条 TXT 自动创建、等待传播、验证并按 record ID 清理，正式证书哈希未变化，状态目录无残留；部署 Hook 的 `nginx -t` 与 `siye-prod-edge-nginx` 平滑重载也已通过，`certbot.timer` 正常。

2026-07-21 已完成并行 HTTPS 验收：`siyes.cn`、`www.siyes.cn`、`music.siyes.cn`、`music-api.siyes.cn`、`linux-api.siyes.cn`、`socket.siyes.cn`、`sub2api.siyes.cn`、`draw.siyes.cn` 均返回正确服务且证书校验结果为 `0`；Socket.IO polling、正式 Origin CORS 以及八个 Host 的 HTTP `308` 跳转均通过。宿主机 Nginx 继续占用公网 `80/443`，Docker edge 仅绑定 `127.0.0.1:18080/18443`。

## 宿主机 Nginx 正式切流

2026-07-21 已通过 `宿主机Nginx切流/` v2 完成正式入口切换。宿主机 Nginx 终止公网 TLS，将 8 个已上线 Host 按原始 Host 和 SNI 代理到 `https://127.0.0.1:18443`；`knowledge.siyes.cn` 在应用上线前返回带有有效证书的 `503 pending`。Docker edge 没有绑定公网 `80/443`。

切换后的服务器本机验收和外部公网验收均通过：8 个 HTTPS 入口返回 `200` 且 TLS 校验结果为 `0`，9 个 HTTP 入口均返回对应 HTTPS 的 `308`，Socket.IO polling 和 CORS 预检正常。本次精确回滚状态位于：

```text
/opt/siye-production/backups/host-nginx-cutover-20260721-163248
```

旧站点的 `sites-available` 文件仍保留，只有 4 个冲突的 `sites-enabled` 软链接被禁用。切流验收完成后，三个旧 systemd 业务服务已停止并禁用；旧 Sub2API 容器已停止并设置为 `restart=no`，旧数据仍保留。

浏览器真实验收同样已通过：主站、音乐搜索与音频实际播放、聊天消息保存与历史查询、Socket.IO polling、日志查询、svg-draw 静态资源、Sub2API 管理员登录、管理 API 和真实上游调用均正常；宿主机 Nginx 已生效 `client_max_body_size 100m`，原 `/responses` 请求的 `413` 已解决；`knowledge.siyes.cn` 继续返回计划内的 `503 pending`。

旧 `music.siyefun.top` 不属于本次正式入口：它当前解析到腾讯云 IP，但没有完成腾讯云接入备案，HTTP GET 会被腾讯云直接 `302` 到 DNSPod 拦截页。该响应未进入宿主机 Nginx，不影响 `https://music.siyes.cn` 正式链路。

## `draw.siyes.cn` 验收

- 根路径必须返回 svg-draw 页面，不能返回主站或 edge 默认响应。
- CSS、JS、字体和图标等资源全部返回 `200`。
- 当前 svg-draw 没有 `vue-router`；如果以后加入 history 路由，再增加刷新回退测试。
- HTTP Host 和 HTTPS SNI 都必须命中 `svg-draw` 容器。
- 容器重建后 edge 仍能通过 Docker DNS 解析新的容器 IP。

## 生命周期和回滚

- 更新核心业务只进入 `core/`，不会重建 Sub2API、edge 或 svg-draw。
- 更新 Sub2API 只进入 `sub2api/`，数据备份和恢复也只由该项目负责。
- 更新 svg-draw 只进入 `svg-draw/`，镜像标签独立递增。
- 更新证书或 Host 路由只重建 `edge/edge-nginx`。
- 回滚时恢复对应项目自己的 `.env` 镜像标签，再执行该项目的 `pull` 和 `up -d`；不能对整个服务器执行无差别 `down`。

`music-api:0.0.2`、`easy-chat:0.0.2` 的服务器文件日志双写与 `linux-server` 日志查询已经通过；正式 Sub2API 使用用户确认的新数据库和独立数据卷，不迁移旧 `/sub2api` 数据。正式聊天 MySQL 也不迁移旧 systemd 数据库中的 26 条消息，新库清理冒烟记录后从空数据开始，旧数据库保持不动。正式前端制品已确认只包含三个正式 HTTPS 服务域名且不包含演练 IP。DNSPod API 自动续期、证书部署 Hook、配置备份和宿主机 Nginx 正式切流均已完成验收。2026-07-21 21:09 已完成旧业务实例下线；正式 Docker 容器保持 `running/healthy`，并使用 `restart=unless-stopped`。下线前后状态备份位于 `/opt/siye-production/backups/legacy-stop-20260721-210035`，旧 MySQL、旧服务目录和旧 Sub2API 数据仍保留。
