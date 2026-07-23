# AGENTS

## 项目定位

这个仓库用于做资料存储，主要服务于学习巩固、知识沉淀和面试准备。

- `md-viewer` 子项目用于本地启动服务，方便在浏览器中查看仓库内的 `md` 文件。
- 其余 `md`、`js` 等文件主要是知识资料，后续前端、后端、运维、部署等相关内容都可以继续补充到合适的位置。
- 当前仓库内已经有较多前端相关知识积累，后续会继续扩充。

## 用户背景

- 用户当前主方向是前端开发。
- 正在转向全栈开发工程师方向。
- 除了继续巩固和加强前端知识，已经学习了 Java 基础知识。
- 当前正在学习部署、运维，以及其他除前端之外的工程化技能。
- 后续也会继续学习后端相关知识，包括但不限于微服务、数据库、Redis、Spring、Spring Boot、Docker、Docker Compose 等。
- 当前在后端、部署、数据库、Linux、Docker、Spring Boot、Maven 等方向仍处于持续上手阶段；后续相关说明默认按“给转全栈的前端同学看的版本”来写，尽量补充命令作用、执行上下文、目录定位方式、适用场景和常见误区，避免只给结论式步骤。

## 当前学习与实践重点

- 持续积累前端相关知识、原理、面试题和工程实践经验。
- 逐步补充后端开发知识，形成从前端到服务端的完整知识体系。
- 重点学习 Linux 环境下的部署与运维，因为这更贴近真实企业开发环境。
- 当前正在从“能把服务跑起来”过渡到“按接近生产的标准发布、回滚、排查和演进服务”。
- Docker / Docker Compose 已进入学习计划，但当前优先顺序不是直接替换现有服务，而是先把已验证成功的 `systemd + 目录部署` 方案完善到稳定可复用，再逐步补 Docker 版本。

## 服务器与运维现状

### 腾讯云服务器

- 已购买腾讯云服务器。
- 操作系统为 `Ubuntu 24.04 LTS`。
- 已通过腾讯的 `OrcaTeam` 运维软件使用 `ssh` 登录服务器。
- 当前使用 `ubuntu` 账号登录。
- `ubuntu` 账号可通过 `sudo` 执行任意命令。
- 为避免在仓库中直接暴露服务器地址，不记录腾讯云和阿里云服务器的真实公网 IP；涉及腾讯云服务器的命令与历史记录统一使用 RFC 5737 文档专用地址 `203.0.113.10` 代称，该地址不能用于连接真实服务器。
- 新购买的域名为 `siyes.cn`，当前已绑定到这台腾讯云 Linux 服务器。
- `siyes.cn` ICP 备案已通过，备案号为 `闽ICP备17032186号-3`。
- `siyes.cn` 的 ICP 备案和公安联网备案流程均已完成。仓库只记录备案已完成的状态，不记录公安备案号。
- 当前主站 `/var/www/siyes.cn/index.html` 已发布新版 `SIYES` 服务导航首页，页脚展示备案号并链接到 `https://beian.miit.gov.cn/`；`siyes.cn` 和 `www.siyes.cn` 均由 Docker edge 提供 HTTPS，HTTP 自动跳转 HTTPS。
- 主站静态目录由 `siye-prod-edge-nginx` 只读挂载，首页文件可在宿主机原子替换后立即生效，不需要重启或重建 Docker edge。
- 腾讯云 Linux 服务器上的正式访问入口统一使用 `siyes.cn` 及其子域名；`siyefun.top` 域名体系继续作为阿里云 Windows 的前端访问入口和迁移参考。

### Linux 当前已落地服务

- `music-api.service`
- `easy-chat.service`
- `linux-server.service`

### Linux 当前主要目录

- `/opt/music-api/NeteaseCloudMusicApi-4.13.8`
- `/opt/easy-chat`
- `/opt/linux-server`
- `/var/log/siye`

### Linux 当前日志文件

- `/var/log/siye/music-api.log`
- `/var/log/siye/music-api-error.log`
- `/var/log/siye/socket.log`
- `/var/log/siye/socket-error.log`

### Linux 当前域名与访问入口

- 主域名：`siyes.cn`
- 主站别名：`www.siyes.cn`
- `svg-draw` 静态站点目标域名：`draw.siyes.cn`
- `siyeWorld` 前端目标域名：`music.siyes.cn`
- 网易云音乐 API 目标域名：`music-api.siyes.cn`
- `linux-server` Java API 目标域名：`linux-api.siyes.cn`
- Docker Sub2API 服务目标域名：`sub2api.siyes.cn`
- `easy-chat` Socket 目标域名：`socket.siyes.cn`
- `frontend-knowledge` 项目预留域名：`knowledge.siyes.cn`
- 以上 9 个域名均已添加 `A` 记录并解析到腾讯云服务器；仓库不记录实际解析地址。
- 腾讯云控制台已确认以上 9 条解析记录状态均为“正常”，记录类型均为 `A`。DNS 正常只代表域名能够解析到服务器，不代表站点、反向代理或 HTTPS 已经完成上线。
- Linux 正式部署完成后的对外访问矩阵固定为：
  - `https://siyes.cn`：正式主站和服务导航首页
  - `https://www.siyes.cn`：主站别名，最终与 `siyes.cn` 使用同一站点
  - `https://music.siyes.cn`：`siyeWorld` 正式前端入口
  - `https://music-api.siyes.cn`：网易云音乐 API 独立服务入口
  - `https://linux-api.siyes.cn`：`linux-server` Java API 独立入口，提供聊天消息保存、历史查询和日志查询
  - `https://socket.siyes.cn`：`easy-chat` Socket.IO 独立服务入口
  - `https://sub2api.siyes.cn`：Docker Sub2API 独立服务入口
  - `https://draw.siyes.cn`：`svg-draw` 静态站点入口
  - `https://knowledge.siyes.cn`：当前 `frontend-knowledge` 项目预留入口，应用和 edge Host 尚未部署
- 当前仍处于准生产演练阶段，但 `siyes.cn` 备案已通过；`siye-world:0.0.2` 的演练 `.env.production` 仍编译 `http://203.0.113.10:8090`，音乐 API 基地址追加 `/music-api`，Socket.IO、聊天历史和日志使用 `http://203.0.113.10:8090`。正式 Docker 全量部署完成前不切换正式 HTTPS 域名。
- 备案和 HTTPS 完成后的正式前端改为直接访问 `https://music-api.siyes.cn`、`https://socket.siyes.cn`、`https://linux-api.siyes.cn`。届时前端部署服务器只需提供静态文件和 SPA 回退，不需要配置业务接口代理；独立域名也便于其他客户端和服务器直接调用。第三方浏览器站点仍受 CORS 限制，服务端程序调用不受浏览器 CORS 限制。
- 已使用 DNS-01 成功签发 `/etc/letsencrypt/live/siyes-production/` 通配符证书，覆盖 `siyes.cn` 和 `*.siyes.cn`，因此后续新增普通一层子域名不需要重新签发证书。证书有效期至 2026-10-19；DNSPod API Token 仅保存在服务器 `/etc/letsencrypt/dnspod.env`（`600 root:root`），Certbot manual auth/cleanup Hook 已完成 staging `renew --dry-run`：两条 TXT 自动创建、等待传播、验证并按 record ID 清理，状态目录无残留，正式证书哈希未变化，`certbot.timer` 正常。部署 Hook 已验证可执行 `nginx -t` 并平滑重载 `siye-prod-edge-nginx`。证书与自动续期完成不代表正式域名已经切流。
- 以上域名统一纳入 HTTPS 迁移范围；每个服务迁移时同步准备 HTTPS 配置、证书和 HTTP 到 HTTPS 跳转
- 当前域名可能受 ICP 备案状态影响，证书机构无法完成公网验证时，证书签发只能在域名访问恢复后重试
- 当前 Socket 仍可通过 `203.0.113.10:3030` 直连联调
- 当前测试阶段 Socket.IO 服务入口为 `http://203.0.113.10:3030/socket.io`
- 当前测试阶段音乐 API 入口为 `http://203.0.113.10:3000/search`，直接访问 `music-api.service`
- 当前 `linux-server` 端口为 `8081`
- 当前测试阶段日志接口入口为 `http://203.0.113.10:8081/api/logs`，直接访问 `linux-server.service`

### ICP 备案期间临时 IP 端口发布方案

- 为了在 `siyes.cn` 备案完成前快速发布并验证 `siyeWorld/siyeMusic`，前端及接口暂时使用 `203.0.113.10 + 端口` 访问。
- 在正式 Docker 全量部署、全部功能验收和最终切流完成前，现有 systemd Linux 主链路及其全部配置属于不可变保护对象。未经用户明确确认正式切换窗口，任何演练、部署或排障都不得停止、重启、禁用、屏蔽、替换或删除 `music-api.service`、`easy-chat.service`、`linux-server.service`，也不得修改或覆盖其 unit 文件、环境配置、启动参数、部署目录与制品、现用端口、日志目录与日志配置。当前主站首页及其备案号也必须保持可访问。只允许执行 `systemctl is-active/status`、`journalctl`、端口和日志查看等只读检查；备案通过本身不代表可以自动修改、迁移或下线 systemd 主链路。
- Docker 和 Docker Compose 演练必须使用独立容器名、目录、网络和临时端口与 systemd 主链路并行；不得让容器绑定或接管 systemd 当前使用的 `3000`、`3030`、`8081`。只有正式域名、HTTPS、Docker 业务链路、回滚方案均完成验证，并由用户再次明确确认后，才能另行制定 systemd 迁移或下线步骤。
- `siyeWorld` 测试版已部署到 `/var/www/siyeWorld/dist`，访问入口为 `http://203.0.113.10:8083`，由 Nginx `listen 8083` 提供静态站点。
- 当前音乐 API 测试入口直接使用 `http://203.0.113.10:3000/search`，不经过 Nginx 中间端口；原 `3001` 配置已删除。
- 当前 Socket 测试入口使用 `http://203.0.113.10:3030/socket.io`，直接访问 `easy-chat.service`。
- 当前日志接口测试入口使用 `http://203.0.113.10:8081/api/logs`，直接访问系统目录部署版 `linux-server.service`。
- `siyeWorld` 测试版已验证音乐搜索、Socket.IO、聊天历史加载和日志入口；前端页面、Socket.IO 请求、音乐 API 请求及聊天历史请求均已返回 `200`。
- `http://203.0.113.10:8082` 仍对应 Docker 演练版 `linux-server`，不作为当前主测试入口。
- 服务器 `8080` 当前由 Docker 部署的 `sub2api` 服务使用，不能再分配给 `siyeWorld` 前端。
- 已通过 `sudo ss -lntp` 确认 `8080` 由 `docker-proxy` 监听；原 `3001` Nginx 入口已删除，`8083` 用于 `siyeWorld` 临时前端静态站点入口。
- `3030` 是 Socket.IO 服务端口，不能用于 `/search` 等音乐 API 请求；向 `203.0.113.10:3030/search` 请求会返回 `404`。
- 备案通过并完成 HTTPS 后，前端切回 `music.siyes.cn`，音乐 API 切回 `music-api.siyes.cn`，Socket 切回 `socket.siyes.cn`；随后关闭或限制临时公网端口。

### `siyes.cn` 域名迁移原则

- 所有服务按“一次迁移一个域名、每一步都保留回滚入口”的方式调整，不一次性修改全部服务。
- 每个新域名迁移时同时准备 HTTP 和 HTTPS；HTTP 用于先验证站点，HTTPS 配置和证书签发条件满足后立即完成。
- HTTPS 配置完成后，正式站点默认将 HTTP 重定向到 HTTPS；备案期间如果证书机构无法访问域名，只保留 HTTP 临时验证，不把证书失败误判为 Nginx 配置失败。
- 新域名验证成功前，不删除原有 `siyefun.top` Nginx 配置、证书和 DNS 记录。
- 每个站点使用独立的 `/etc/nginx/sites-available/<域名>` 配置文件，并通过 `sites-enabled` 软链接启用。
- 当前已完成或正在验证：`draw.siyes.cn`、`music-api.siyes.cn`、`socket.siyes.cn`、IP 端口版 `sub2api` 和 IP 端口版 `siyeWorld`；`siyes.cn` 主站暂不纳入本阶段处理。
- 第一项静态网站 `draw.siyes.cn` 已完成 DNS、Nginx HTTP 和 SPA 路由回退验证；当前继续补齐 HTTPS 配置，完成后再进入下一个服务。
- 已尝试使用 `certbot --nginx -d draw.siyes.cn` 签发证书，但 Let's Encrypt 访问域名时收到 DNSPod 的 `webblock.html`，当前 HTTPS 证书签发被备案/域名访问拦截阻断。
- 当前不应反复重试相同的 HTTP-01 证书命令；待域名公网访问恢复后再重试，或后续改用 DNS-01 验证方式。
- `music-api.siyes.cn` 已完成 DNS、Nginx HTTP 反向代理和本地前端真实请求验证。
- 本地前端访问 `music-api.siyes.cn` 时，CORS 预检 `OPTIONS` 返回 `204`，`POST /user/playlist` 返回 `200`，证明浏览器到 Nginx 再到 `music-api.service` 的链路已经跑通。
- `music-api.siyes.cn` 的 `GET /search` 曾出现 `499`，表示客户端在 Nginx 完成响应前主动断开；该状态不代表域名或 Nginx 代理未生效，应结合前端取消请求、超时和重复搜索逻辑继续判断。
- `socket.siyes.cn` 已完成 DNS 和 Nginx HTTP 代理验证，目标为 `/opt/easy-chat` 的 `3030` 端口。
- `http://socket.siyes.cn/health` 返回 `200`，Socket.IO Engine.IO polling 握手返回 `200`、`sid` 和 `upgrades:["websocket"]`，说明 Socket.IO 代理链路已跑通。
- 本地浏览器通过 `socket.siyes.cn` 联调时收到 `302`，并被重定向到 DNSPod 的 `webblock.html`；这是 ICP 备案/域名访问拦截，不是 Socket.IO 或 Nginx 配置错误。
- 在域名备案完成前，本地 Socket 联调暂时继续使用 `http://203.0.113.10:3030`；新域名 Nginx 配置保留，备案后再切换回 `http://socket.siyes.cn`，HTTPS 后切换为 `https://socket.siyes.cn`。
- 本地前端切回 `http://203.0.113.10:3030` 后，Socket.IO polling 请求返回 `200 OK`，临时 IP 直连联调已恢复；该请求绕过了 `socket.siyes.cn` 的 Nginx 域名入口。

### Linux 当前数据库状态

- 当前聊天室持久化数据库使用 `MySQL`。
- 当前数据库名为 `siye_chat`。
- 当前聊天消息表为 `chat_message`。
- 当前 `linux-server` 通过 `spring.datasource.*` 连接本机 MySQL。
- 聊天消息持久化职责已从 Socket Server 迁移到前端：前端直接调用 `linux-server`，`easy-chat` Socket Server 不再读取 `CHAT_HISTORY_API_BASE_URL`，也不再直接访问 Java 服务。
- 该新架构已于 2026-07-14 在 systemd 主链路完成真实部署验证：本地前端通过 `3030/8081` 同时完成 Socket 广播和消息保存，刷新可读到历史记录，MySQL 对应 `message_id` 只有一条。

### 当前部署状态补充

- 原 Linux 练习域名 `music-api.siyefun.top` 已完成基础部署验证，并已配置 `systemd` 常驻。
- 新域名 `music-api.siyes.cn` 已完成 HTTP 迁移和本地前端联调，HTTPS 仍受备案/域名访问拦截影响。
- `easy-chat` 已在 Linux 服务器独立部署到 `/opt/easy-chat`，并已配置 `systemd` 常驻。
- `socket.siyes.cn` 已完成 HTTP 入口迁移验证，HTTPS 仍受备案/域名访问拦截影响。
- `linux-server` 已在 Linux 服务器独立部署到 `/opt/linux-server`，当前承担两类能力：
  - 日志查询接口
  - easy-chat 历史消息存储与查询接口
- `sub2api` 已通过 Docker 独立部署，当前访问入口为 `http://203.0.113.10:8080`；`sub2api.siyes.cn` 域名入口待备案和 HTTPS 条件满足后再处理。
- 当前 Sub2API 实际目录为 `/sub2api`，这是已有 Docker 演练部署，不是正式生产服务。它使用目录型 Compose 数据布局：`./data`、`./postgres_data`、`./redis_data`，分别保存应用、PostgreSQL 和 Redis 数据；当前演练基线为 `weishaw/sub2api:latest@sha256:2ca591c2af97eb0e2797cfc7fb7bd587194d94cebdac76f73d677eeab1d4d6c8`、`postgres:18-alpine@sha256:9a8afca54e7861fd90fab5fdf4c42477a6b1cb7d293595148e674e0a3181de15`、`redis:8-alpine@sha256:9d317178eceac8454a2284a9e6df2466b93c745529947f0cd42a0fa9609d7005`，当前标签仅作为演练基线，不作为正式生产版本策略。
- 当前 Sub2API 演练的应用宿主机入口为 `8080 -> 8080`，PostgreSQL `5432` 和 Redis `6379` 没有宿主机端口；现有 `sub2api`、`sub2api-postgres`、`sub2api-redis`、`/sub2api` 数据目录和现有 `.env` 在正式 Docker 全量部署前均保持不动。
- 当前已同时存在 `systemd + 目录部署` 主验证链路、Docker 演练服务和独立 Docker `sub2api` 服务；Docker `sub2api` 不替换现有 `systemd` 服务。
- 当前 Docker 演练目录为 `/opt/docker-labs/linux-server-mysql`。
- 当前第一套 Docker 演练已完成 `mysql + linux-server` 的独立编排验证，使用端口：
  - `3307 -> 3306`
  - `8082 -> 8081`
- 当前 Docker 演练版已验证通过的能力包括：
  - Docker Compose 启动 `MySQL` 与 `linux-server`
  - `linux-server` 容器读取宿主机 `/var/log/siye`
  - 本地前端通过 `203.0.113.10:8082` 查询日志
  - Docker 版 `chat-history` 写入、查询、聚合到 `service=all`
  - Docker 演练版接口时间已统一为中国本地时间
- 当前第二套 Docker 演练已完成 `easy-chat + linux-server + MySQL` 的独立编排验证，使用端口：
  - `3308 -> 3306`
  - `8084 -> 8081`
  - `3031 -> 3030`
- 当前第二套 Docker 演练版已验证通过的能力包括：
  - Docker Compose 启动 `MySQL`、`linux-server`、`easy-chat`
  - 本地前端通过 `203.0.113.10:3031` 连到 Docker 版 `easy-chat`
  - Docker 版 `chat-history` 能在 `8084` 继续查询到新消息
  - Docker 演练已改为前端通过 `203.0.113.10:8084` 直接调用 `linux-server` 保存消息，并已完成容器重建和真实联调验证
- `easy-chat` 当前已经实现聊天历史持久化能力：
  - 前端页面首次进入默认加载最新 10 条
  - 消息加载后自动滚动到底部
  - 向上滚到顶部时继续加载历史
  - 没有更多历史时顶部提示“没有更多信息了”
  - 前端组件 `persistMessages` 默认值为 `true`，设置为 `false` 时只通过 Socket 实时发送，不请求保存接口
  - 保存失败会触发 `message-persist-error`，不会阻断 Socket 广播
- 当前日志查询页已经支持查询：
  - `music-api`
  - `socket`
  - `easy-chat-history`
  - `all` 模式下会合并上述数据统一分页返回
- 当前已经成功将多个小服务部署到 Linux 服务器并和本地前端打通。
- 当前计划是在已部署服务迁移时同步完成 HTTP/HTTPS 配置；ICP 备案通过后只需确认域名访问恢复，不再重新设计或补做整套 Nginx 配置。
- `siyes.cn` 主站已发布新的单文件服务导航首页，通过卡片进入音乐空间、知识库和 Sub2API；首页继续由宿主机静态目录维护，不单独制作镜像。

### 阿里云服务器与现有线上部署

- 之前已有一台阿里云服务器。
- 该服务器当前是 Windows 系统。
- 已申请域名 `siyefun.top`。
- 当前已通过 `nginx` 进行部署。
- 现有 Nginx 配置参考 [linux/nginx.conf](E:/本地项目/frontend-knowledge/Linux部署/nginx.conf)。

## 已有部署项目

### 1. siyeWorld

项目地址：
[https://github.com/siyesummer/siyeWorld](https://github.com/siyesummer/siyeWorld)

相关 GitHub 仓库已创建并作为后续 CI/CD 发布边界：

- [siyesummer/siyeWorld](https://github.com/siyesummer/siyeWorld)：前端主项目和 easy-chat 工作区
- [siyesummer/NeteaseCloudMusicApi-private](https://github.com/siyesummer/NeteaseCloudMusicApi-private)：独立 music-api 源码和镜像构建来源
- [siyesummer/linux-server](https://github.com/siyesummer/linux-server)：独立 Java 日志、聊天存储服务和镜像构建来源
- 后续优先使用 GitHub Actions 按仓库构建、测试并推送 Docker Hub 版本镜像；本地构建和推送仅作为学习或紧急发布备用方案。

当前对应关系：

- 音乐播放器对应域名 `siyefun.top`
- 网易云音乐接口相关服务对应域名 `api.siyefun.top`
- Socket 服务对应 `siyefun.top:3030`

补充说明：

- 腾讯云 Linux 新域名体系使用 `siyes.cn`：
  - `music.siyes.cn`
  - `music-api.siyes.cn`
  - `sub2api.siyes.cn`
  - `draw.siyes.cn`
  - `socket.siyes.cn`
- `siyes.cn` 已绑定到腾讯云 Linux 服务器，ICP 备案已经通过，备案号为 `闽ICP备17032186号-3`。
- `siyes.cn` 主站已完成 HTTPS 和新版导航首页发布，入口由正式 Docker edge 提供。
- 已部署服务的 HTTPS 证书和 Nginx HTTPS 配置纳入后续迁移任务，备案完成后再按服务逐项切换。
- `siyeWorld` 测试版已部署到 Linux 服务器 `/var/www/siyeWorld/dist`，Nginx 临时端口配置为 `8083`；由于当前通过 IP 加 HTTP 访问，浏览器显示“不安全”属于预期现象。
- 正式 Docker 全量服务切流前，`siyeWorld/siyeMusic` 测试链路继续保留以下 IP 加端口入口：Socket.IO 为 `http://203.0.113.10:3030/socket.io`，音乐 API 为 `http://203.0.113.10:3000/search`，日志接口为 `http://203.0.113.10:8081/api/logs`。
- `linux-server` 的 CORS 白名单已加入 `http://203.0.113.10:8083`，重新部署 JAR 后聊天历史接口可被测试前端正常访问。
- 当前日志查询前端本地联调阶段固定请求 `http://203.0.113.10:8081`。
- `sub2api.siyes.cn` 对应独立的 Docker `sub2api` 项目，不对应 `linux-server:8081`；当前 Docker 服务通过 `http://203.0.113.10:8080` 访问，域名反向代理目标端口以后续 Docker Compose 实际暴露端口为准。
- 当前 `siyeWorld` 测试版采用 `Nginx 静态站点 + IP:8083`；正式 Docker 全量服务和 HTTPS 完成验收后再切换到 `music.siyes.cn`，并关闭或限制临时端口。

### 2. svg-draw

项目地址：
[https://github.com/siyesummer/svg-draw](https://github.com/siyesummer/svg-draw)

当前对应域名：

- `http://svg-draw.siyefun.top/`
- 原 Linux 练习域名：`draw.siyefun.top`
- 腾讯云 Linux 新目标域名：`draw.siyes.cn`
- `draw.siyes.cn` 已解析到 `203.0.113.10`，HTTP 返回 `200 OK`，不存在的前端路由可正确回退到 `index.html`
- `draw.siyes.cn` 当前 HTTP 已完成；HTTPS 已开始尝试，但因 DNSPod 返回 `webblock.html` 导致证书机构无法完成 HTTP-01 验证
- 当前 `draw.siyes.cn` 仍由宿主机 Nginx 指向 `/var/www/svg-draw/dist`，作为正式 Docker 全量部署前的稳定回退站点；正式阶段将把 `svg-draw` 制作为独立 Nginx 静态镜像，由统一 edge-nginx 按 `draw.siyes.cn` Host 转发，不发布独立宿主机端口。

## 本地项目与服务器目录映射

- Linux `/opt/music-api/NeteaseCloudMusicApi-4.13.8` 对应本地 `E:\本地项目\NeteaseCloudMusicApi-private`
- Linux `/opt/easy-chat` 对应本地 `E:\本地项目\siyeWorld\packages\easy-chat`
- Linux `/opt/linux-server` 对应本地 `E:\本地项目\java-project\linux-server`

### 本地开发默认入口补充

- 本地开发联调 `siyeWorld` 时，音乐 API 启动入口默认使用 `E:\本地项目\siyeWorld\packages\siye-music\app.js`
- 本地开发联调 `siyeWorld` 时，前端请求封装默认使用 `E:\本地项目\siyeWorld\packages\siye-core\src\modules\request.js`
- 本地开发联调 `siyeWorld` 时，`packages/siye-music` 当前固定依赖版本为 `NeteaseCloudMusicApi@4.13.6`
- Linux 服务器当前 `music-api` 部署验证版本仍为 `NeteaseCloudMusicApi@4.13.8`

### siyeWorld 多环境服务地址配置原则

- 本地开发环境使用 `localhost + 端口`，例如本地 music-api、Socket 和 linux-server 入口。
- `siyefun.top` 已在阿里云 Windows 服务器部署最新 `siyeWorld` 前端；该前端使用正式的 `https://music-api.siyes.cn`、`https://socket.siyes.cn` 和 `https://linux-api.siyes.cn` 业务入口，已完成浏览器功能验收。
- 当前 Linux 阶段 5 镜像使用 `203.0.113.10:8090` 完成演练；不能因为正式域名 DNS 已解析就提前把 HTTPS 域名写进演练镜像。
- `.env.production` 已切换为三个独立 HTTPS 服务域名；`siyefun.top` 当前复用正式域名版前端制品。已发布版本标签继续保持不可变，后续更新仍需先完成 Windows 独立验证并保留可回滚制品。
- 前端配置区分 `development` 与 `production`；演练和正式域名切换通过修改 `.env.production` 后发布不同镜像版本体现，不在源码中维护并行回退地址。服务地址、Socket 地址、聊天历史接口和日志接口不能散落硬编码在多个子项目中。
- 推荐由统一配置文件或构建脚本生成前端和 easy-chat 所需配置；密码、CORS、数据库连接等运行时配置继续由服务器 `.env` 提供，不写入镜像。
- `siyeWorld` 浏览器端的 music-api、Socket、聊天历史和日志地址全部是必填 `VUE_APP_*` 变量，源码不得提供 localhost、IP、域名等回退值；`serve/build` 缺少任一变量时必须立即失败并列出缺失项。
- 浏览器配置按 Vue CLI 模式拆分：仓库根 `.env.development` 供 `yarn serve` 自动读取，使用 localhost；根 `.env.production` 供 `yarn build`、Dockerfile 和发布 Workflow 共同读取，是唯一发布构建地址来源。当前演练阶段写入 `IP:8090`，备案后切换为三个独立 HTTPS 服务域名并发布新版本。两份标准文件均提交 Git；个人临时覆盖只使用不提交的 `.env.development.local` 或 `.env.production.local`。
- easy-chat Node 本地运行参数仍单独放在 `packages/easy-chat/.env.local`，示例放在包内 `.env.example`；它属于服务端运行配置，不与浏览器的 `.env.development/.env.production` 合并。
- easy-chat Node 服务端的 `PORT`、`CORS_ALLOW_ORIGIN` 必须由包内 `.env.local` 或部署 Compose 注入；源码和 Dockerfile 不提供端口、CORS、连接地址默认值，也不继续兼容 `CHAT_PORT`、`SERVER_HOST`、`CONNECT_URL` 等旧变量链。
- GitHub Actions 构建 `siye-world` 前端镜像时必须读取并校验仓库根 `.env.production`；Dockerfile 复制同一文件并由 Vue CLI 自动读取，不能依赖开发者本机 `.env.local`，也不能再维护一套重复的 build args 或为了让 CI 通过而恢复源码默认地址。
- GitHub Pages 制品使用独立 `.env.pages` 和 `yarn build:pages`，设置 `VUE_APP_PUBLIC_PATH=/siyeWorld/`、`VUE_APP_ROUTER_MODE=hash` 和 `NODE_ENV=production`；业务地址已经切换为正式的 `https://music-api.siyes.cn`、`https://socket.siyes.cn` 和 `https://linux-api.siyes.cn`。常规开发、Docker 正式构建和 Pages 三种模式分别使用 `.env.development`、`.env.production`、`.env.pages`，不能互相覆盖。
- GitHub Pages 已不再请求下线的 HTTP `8090` 演练入口，因此前端调用正式 API 不存在原先的 HTTP API Mixed Content 问题；第三方歌曲资源是否全部为 HTTPS 仍应结合浏览器 Console 和 Network 单独检查。
- 根 `scripts/deploy.js` / `siyeWorldDeploy` 属于早期 Windows 目录部署生成器，不作为当前 Docker 正式发布配置来源；阶段 5 前端镜像发布不得读取其 `config.js` 默认值。
- 当前演练版使用 `IP:8090 + /music-api、/socket.io、/api` 统一路由；备案后的正式版使用三个独立 HTTPS 服务域名。二者属于不同发布阶段和不同镜像版本，不能在同一版本内混用。

## 当前已经新增的重要功能

### 日志查询能力

- 已在本地 `siyeWorld` 中新增日志查询页面。
- 已在 `linux-server` 中新增日志查询接口。
- 当前日志查询接口支持服务端分页，前端只传 `page`、`pageSize`。
- 当前日志查询接口支持：
  - `music-api`
  - `socket`
  - `chat-history`
  - `all`
- 当前日志查询页已经去掉“返回条数”手动筛选，改为依赖后端 `total + page + pageSize` 实现分页。
- 当前日志查询页使用共享 `STable` 组件展示结果，并在底部使用分页器翻页。

### easy-chat 历史消息能力

- 已在 `linux-server` 中新增聊天消息保存接口。
- 已在 `linux-server` 中新增聊天历史查询接口。
- 前端发送消息时使用同一个消息对象分别调用 Socket Server 和 `linux-server`；Socket Server 只负责广播，前端决定是否持久化。
- 已将聊天消息持久化到 MySQL 的 `siye_chat.chat_message` 表。
- `linux-server` 依赖 `(room_code, message_id)` 唯一键，并捕获 `DuplicateKeyException`，保证迁移窗口内并发重复提交仍只保存一条。
- 聊天消息 IP 辅助识别已完成编码并部署到 systemd 主链路：`chat_message.client_ip` 保存后端解析的请求 IP，历史接口只返回 `isSelf`，不向前端暴露真实 IP；同 IP 即使 `senderId` 变化也会判定为同一发送者。
- systemd IP 识别版本已验证：`ip-identify-test-001` 与 `ip-identify-test-002` 的 `senderId` 不同、`client_ip` 均为 `192.0.2.10`，历史接口均返回 `isSelf: true`，前端均靠右显示。旧记录的 `client_ip` 保持 `NULL`。
- IP 只作为辅助识别；同一家庭、公司或运营商 NAT 下的不同用户可能共享公网 IP，不能替代正式登录账号。
- IP 识别版本本地验证已完成：Java 11 个测试全部通过，包含同 IP 不同 `senderId`、不同 IP 隔离、代理 IP 防伪和 `isSelf` JSON 契约；迁移脚本已在 MySQL 8.0.39 上连续执行两次验证幂等，前端定向 lint 与生产构建通过。
- Docker 第二套 IP 识别版本已完成数据库迁移、镜像重建和真实联调：新消息保存 `client_ip = 192.0.2.10`，不同 `senderId` 的历史记录均返回 `isSelf: true` 并靠右显示；旧记录保持 `client_ip = NULL`。
- 已在前端聊天室实现：
  - 首屏默认加载最新 10 条
  - 加载完成滚动到底部
  - 顶部上拉继续分页加载历史
  - 无更多历史时给出提示
- 聊天身份使用浏览器 `localStorage` 缓存：`easy-chat:sender-id` 保存 Socket 消息的 `senderId`，`easy-chat:user-name` 保存昵称；组件加载时优先恢复缓存，没有缓存时才生成新的 `guid`。
- 修改昵称失焦后会同步写回 `localStorage`；清理浏览器站点数据后会重新生成发送人 ID。

## Docker 学习计划

- 当前已经具备学习 Docker / Docker Compose 的前置条件，因为已经实际完成过：
  - Nginx 静态站点部署
  - `systemd` 常驻 Node / Java 服务
  - 前后端联调
  - 日志落盘与日志查询
  - MySQL 安装、建库建表、服务接入
- 当前 Docker 学习策略：
  - 先补 Docker 基础命令与概念文档
  - 域名好后，先把现有 `systemd + 目录部署` 可用版本完善并完成正式验证
  - 再基于当前已跑通的服务体系，逐步补 Docker 版本与 Docker Compose 版本
- 当前已完成对 [Docker命令说明.md](E:/本地项目/frontend-knowledge/Docker专题/Docker命令说明.md) 的首轮浏览，下一阶段应从“最小可运行容器实践”进入到“基于当前项目的 Docker Compose 编排实践”。
- 当前不建议立刻把现有可用服务全部切换到 Docker，以免打断已经跑通的联调链路。
- 更合理的顺序是：
  - 先稳住现有目录部署版本
  - 再单独做 Docker 演练版本
  - 最后再决定是否迁移现有服务
- 当前第一套 Docker 演练已经完成 `mysql + linux-server` 验证闭环。
- 当前第二套 Docker 演练已经完成 `easy-chat + linux-server + MySQL` 验证闭环。
- 当前已完成六套 Docker 演练，第六套已验证完整多服务 Compose、统一 Nginx 入口、内部 DNS、MySQL 持久化和本地前端真实联调；第七套准生产发布演练的阶段 1 至阶段 5 均已完成。阶段 6 已完成 `siye-world:0.0.1 -> 0.0.2` 的镜像、网关、服务器和浏览器升级验证，但数据库唯一性复核及 `0.0.2 -> 0.0.1` 回滚尚未执行；按用户决定暂时暂停阶段 6，优先开始正式 Docker 全量部署。

## 正式部署方案

### 源码仓库与镜像边界

- GitHub 源码仓库：
  - `siyesummer/siyeWorld`
  - `siyesummer/NeteaseCloudMusicApi-private`
  - `siyesummer/linux-server`
- Docker Hub 镜像仓库已经创建：
  - `siyesummer/siye-world`
  - `siyesummer/easy-chat`
  - `siyesummer/music-api`
  - `siyesummer/linux-server`
- 正式服务自己的 `Dockerfile`、`.dockerignore`、构建说明和部署说明放在对应源码仓库的 `deploy/` 目录；`frontend-knowledge/Docker专题/Docker演练` 继续只保存学习演练材料。
- `siyeWorld` 仓库负责构建前端制品和 `easy-chat` 镜像；`NeteaseCloudMusicApi-private` 独立构建 `music-api` 镜像；`linux-server` 独立执行 Maven 测试、打包和镜像构建。
- `music-api`、`easy-chat`、`linux-server` 和前端镜像独立部署；MySQL 使用官方固定版本镜像，不和 Java 服务打成一个镜像，也不自行推送业务 MySQL 镜像。

### GitHub Actions 发布规则

- 镜像统一由 GitHub Actions 构建并推送到 Docker Hub；本地构建和推送仅作为学习、排障或紧急发布备用方案。
- 正式发布由仓库 Actions 页面的 `workflow_dispatch` 手动触发，不在每次 `push main` 时自动发布。
- 每个源码仓库的正式版本从 `0.0.1` 开始，默认每次正式发布自动递增 patch：`0.0.1 -> 0.0.2 -> 0.0.3`。
- 发布工作流依次执行代码校验、版本计算、Docker Hub 镜像推送、Docker Hub Description 同步，并通过 GitHub Release API 创建 Git Tag 和 GitHub Release；同一仓库的发布工作流使用 `concurrency` 防止并发生成相同版本。
- 正式 Compose 固定使用明确版本标签或镜像 digest，不以 `latest` 作为生产版本；同时保留 commit SHA 标签便于追踪。
- `siyeWorld` 仓库同时产出前端和 `easy-chat`，但两类镜像已经使用独立手动 Workflow 和独立版本序列：前端使用 `siye-world-image-v<version>`，Socket 服务使用 `easy-chat-image-v<version>`；两者可以分别发布，不因位于同一源码仓库而强制使用相同版本。
- 三个 GitHub 仓库已经配置 `DOCKERHUB_USERNAME` 和 `DOCKERHUB_TOKEN` Repository Secrets；只负责镜像推送时 Token 使用 Docker Hub `Read & Write`，需要通过 Docker Hub API 自动更新 Description 的仓库必须使用 `Read, Write, Delete`。Token 不提交到源码或 `.env`。

### `music-api:0.0.1` 首次正式发布复盘

- `siyesummer/NeteaseCloudMusicApi-private` 已于 2026-07-15 完成第一次正式发布闭环：GitHub Actions 手动触发、代码校验、多架构构建、Docker Hub 推送、Docker Hub Description 同步、`music-api-v0.0.1` Git Tag 和 GitHub Release 均成功。
- Docker Hub 当前正式版本为 `siyesummer/music-api:0.0.1`，同时生成对应 commit SHA 标签；镜像支持 `linux/amd64`、`linux/arm64`。`0.0.1` 成功发布后视为冻结版本，后续代码变化必须发布 `0.0.2`，不能继续覆盖正式版本标签。
- 发布前统一执行 `npm run verify`，包含全仓库 Lint、`app.js/server.js/generateConfig.js` 语法检查和联网测试；Husky `pre-push` 负责本地提前拦截，发布 Workflow 再执行一次作为不可绕过的镜像发布门禁。
- Windows `core.autocrlf=true` 曾导致全仓库出现大量 CRLF/Prettier 误报；仓库已增加 `.gitattributes` 统一文本文件使用 LF。跨平台仓库不能只依赖编辑器行尾设置。
- 上游仓库已有 `v4.x` Tag，不能直接使用 `v0.0.1` 作为本项目版本序列；正式 Git Tag 使用 `music-api-v0.0.1` 前缀，Docker Hub 镜像仍使用纯版本标签 `0.0.1`。
- Docker Hub Description 必须和镜像发布放在同一个 Workflow 中，内容读取 `deploy/README.md`；不能再由根 README 推送单独触发，否则说明内容可能和已发布镜像不同步。
- Docker Hub 镜像 Push 使用 `Read & Write` 即可，但 Description API 的 PATCH 请求要求 Token 具备 `Read, Write, Delete`；权限不足时镜像已经上传，Description 步骤仍会返回 `403 Forbidden`。这说明“镜像推送成功”不等于“整次发布成功”。
- `peter-evans/dockerhub-description@v4` 已升级为 `@v5`；GitHub Actions 中关于 Action Node 运行时弃用的警告不等于业务镜像 Node.js 版本错误，后续仍需单独评估 `checkout/setup-node` Action 和业务基础镜像的升级。
- Workflow 内不能使用 `git tag` 后直接 `git push`：一方面会触发 Husky `pre-push`，导致完整测试重复执行；另一方面，当目标提交修改过 `.github/workflows` 时，GitHub 会拒绝没有 `workflows` 权限的 GitHub App Token 推送 Tag。当前改为 `gh release create --target "$GITHUB_SHA"`，通过 GitHub API 同时创建 Release 和 Tag，只依赖 `contents: write`。
- GitHub Actions 的重试粒度是 Job，不是 Step；当前发布流程位于单个 Job，末尾失败会导致校验和镜像构建整体重跑。后续工作流复杂后可拆成 `verify -> build-and-push -> update-description -> create-release` 多个 Job，使失败重试更精确。
- 镜像、Description、Git Tag 和 GitHub Release 分属不同 API，无法做到数据库事务意义上的完全原子发布。当前顺序为“校验 -> 计算版本 -> 推送镜像 -> 同步 Description -> API 创建 Tag/Release”；没有 Git Tag 的失败发布可以继续使用同一版本重试，但必须先确认远端 Tag 状态，不能盲目重跑导致版本跳号。

### 前端制品与多环境配置

- 最新 `siyeWorld` 已同时部署到腾讯云正式入口和阿里云 Windows 的 `siyefun.top`；两个前端入口均调用腾讯云上三个独立的正式 HTTPS 业务域名。
- 前端当前代码配置区分 `development` 与 `production`：开发环境访问 localhost；当前演练 production 使用 `203.0.113.10:8090`；备案后的正式 production 使用三个独立 HTTPS 服务域名。后续 Windows 原则上复用正式域名版 dist，只有确有必要时才新增 Windows 专用构建模式。
- 前端音乐 API、Socket、聊天历史和日志地址由根目录统一配置或构建脚本注入，不能继续散落硬编码在 `siye-core`、`easy-chat` 和 `src/api` 中。
- 服务器 `.env` 不能修改已经编译进浏览器 JS 的地址。演练 IP 或正式域名变化时必须重新构建并发布前端新版本，不能只改容器运行时 `.env`。
- 当前演练前端通过 edge-nginx `8090` 统一代理业务；备案后的正式前端所在服务器只提供静态文件、缓存、健康检查和 SPA 回退，三个服务域名的 Nginx Host、HTTPS、WebSocket Upgrade、超时和 CORS 统一在腾讯云 Linux 维护。
- 正式用户打开 `https://music.siyes.cn` 后，页面跨域请求三个独立 HTTPS 服务域名；正式的 `music.siyes.cn` 不承担 `/music-api`、`/socket.io`、`/api` 代理职责。
- Windows `siyefun.top` 当前继续采用无 Docker 的 dist + Nginx 方案，最新版前端已经切换上线并验证正常；后续更新仍应使用版本化 dist、独立验证和旧制品回滚机制，不直接覆盖或删除上一可用版本。

### 正式 Docker 全量并行部署与切流原则

- 当前正式目标调整为：在不影响现有 systemd 的前提下，先并行部署一套完整生产 Docker 栈；主站由 edge-nginx 只读挂载当前 `/var/www/siyes.cn` 静态 HTML，业务包含 `siye-world`、`music-api`、`easy-chat`、`linux-server`、MySQL、Sub2API、`svg-draw`、统一 edge-nginx 和 HTTPS。
- `svg-draw` 正式部署边界：从 `siyesummer/svg-draw` 的正式 Git commit 生成版本化 dist，新增独立 Dockerfile/Workflow 和 Docker Hub 镜像（镜像仓库需先确认或创建），容器只加入 `edge-net`，使用 Nginx SPA/static 回退；正式验收通过前不覆盖 `/var/www/svg-draw/dist` 和现有 `draw.siyes.cn` Host 配置。
- `draw.siyes.cn` 正式验收必须单独覆盖：根路径返回静态首页、CSS/JS/字体等资源无 404、HTTP Host 与 HTTPS/SNI 均命中 `svg-draw` 容器；当前源码没有 `vue-router`，若后续引入 history 路由则必须继续验证 `index.html` 回退。验收期间保留宿主机 Nginx 站点作为回滚入口，不能因为 Docker 静态镜像已健康就提前切换或删除旧站点。
- 正式 Docker 栈使用独立目录、独立 Compose project、独立容器名、独立网络、独立数据卷和非冲突测试端口；准备和验证阶段不得占用现有宿主机 Nginx 的 `80/443`，不得占用 systemd 的 `3000/3030/8081`，也不得复用第七套演练容器和数据卷。
- 正式 Sub2API 使用独立部署目录和 Compose project，不复用 `/sub2api` 的容器、`.env` 或数据目录；当前草案已把 Sub2API、PostgreSQL、Redis 拆到独立 `sub2api/` 项目，并固定为已核对 digest，仍需完成 PostgreSQL/Redis 备份、恢复和升级兼容性验证。
- 正式 edge-nginx 最终负责 8 个正式 Host 的域名路由和 TLS；并行验证阶段先绑定独立端口，例如 HTTP `18080`、HTTPS `18443`，通过 Host/SNI、服务器本机请求和受控公网入口完成验证。端口只是候选，执行前必须检查占用和安全组。
- HTTPS 纳入正式 Docker 栈整体交付：证书申请、续期方式、证书只读挂载、TLS 参数、HTTP 到 HTTPS 跳转和 8 个域名的 SNI 验证必须在切流前完成。证书和私钥不得写入镜像、Git 或普通 `.env`。
- `siyes.cn` 当前静态首页及备案号在并行阶段由 edge-nginx 只读挂载 `/var/www/siyes.cn` 提供，内容仍由原宿主机目录维护；必须验证备案号、工信部链接、根域名和 `www` 行为完全一致。正式首页不得遗漏 `闽ICP备17032186号-3`。
- 正式数据库必须使用独立生产数据卷，并在切流前完成现有聊天数据备份、迁移、校验和恢复演练；不能把第七套 `siye_chat_release_drill` 演练库直接当成生产库，也不能通过切换前端掩盖数据未迁移问题。
- Sub2API 的正式数据必须从现有 `/sub2api` 目录做独立备份和恢复验证后再迁移；正式 `sub2api.siyes.cn` 只代理应用容器，不向公网暴露 PostgreSQL 或 Redis。现有 `http://203.0.113.10:8080` 在 Docker 全量切流前继续作为独立回退入口。
- 全量验收至少覆盖：8 个域名路由、HTTPS 证书与跳转、首页备案信息、SPA history、音乐搜索与播放、Socket.IO polling/WebSocket、聊天广播、消息唯一持久化与历史、日志查询、MySQL 备份恢复、Sub2API、`svg-draw`、容器重启恢复、日志和回滚。
- 所有功能通过后才安排最终切流。切流前必须冻结配置、备份现有宿主机 Nginx、记录当前端口和进程、准备一键恢复入口，并明确切流窗口。切流操作只改变对外流量入口，不立即停止 systemd 服务；systemd 保持运行作为观察期回滚链路。
- Docker 正式链路稳定运行并经过用户明确确认后，才另行讨论 systemd 下线。备案通过、证书签发成功或 Docker 容器健康中的任一单项，都不能单独作为下线 systemd 的依据。

### Linux 生产 Compose 与网络

- Linux 服务器的正式 Docker 栈拆为 `core/`、`sub2api/`、`svg-draw/`、`edge/` 四个 Compose 项目；跨项目只通过外部 `siye-prod-edge-net` 连接，不把独立服务的密钥、数据卷和生命周期混在同一个 `.env`。
- 正式 Docker 栈本地基线已建立在 `Docker专题/正式部署/siye-stack/`：`core/` 管理 siyeWorld、三个后端和聊天 MySQL，`sub2api/` 管理 Sub2API 三容器，`svg-draw/` 管理静态镜像，`edge/` 管理首页静态挂载、8 个 Host 和 TLS；根目录 `stack.sh` 只做配置、拉取、分项目启动和状态检查，停止命令必须指定项目且不删除数据卷。
- 正式 Compose 只引用 Docker Hub 镜像和版本，不在服务器通过 `git pull` 后现场构建业务源码。
- `edge-nginx` 当前演练阶段作为 `8090` 统一入口，负责前端和三类路径代理；正式阶段可由宿主机 Nginx 终止 TLS，并按 `music.siyes.cn`、`music-api.siyes.cn`、`socket.siyes.cn`、`linux-api.siyes.cn` 等 Host 转发到对应容器服务。前端部署到其他服务器时不需要复制这些独立服务域名的代理。宿主机和容器不能同时绑定同一 `80/443`。
- 网络划分为：
  - `edge-net`：`edge-nginx`、`siye-world`、`music-api`、`easy-chat`、`linux-server`、`sub2api`
  - `data-net`：`linux-server`、`mysql`
- MySQL 不加入 `edge-net`，不发布公网端口；数据使用独立 volume，必须准备定时备份、恢复验证和数据库迁移流程。
- `draw` 继续作为静态站点管理，正式发布使用版本化 dist 目录和 `current` 软链接切换，不直接覆盖正在服务的目录。
- `svg-draw` 源码本地目录为 `E:\本地项目\svg-draw`，仓库地址为 `https://github.com/siyesummer/svg-draw`。该仓库已新增 `deploy/Dockerfile`、`deploy/nginx.conf`、`deploy/README.md` 和手动 `release-image.yml`；现有 Pages Workflow 保持不动。Docker Hub `siyesummer/svg-draw:0.0.1` 已发布，后续按独立版本序列递增。
- 正式 Docker 日志方案已调整为双写：已经发布的 `music-api:0.0.2`、`easy-chat:0.0.2` 在保留 stdout/stderr 的同时，通过 `LOG_FILE`、`ERROR_LOG_FILE` 写入宿主机 `/var/log/siye-production`；`linux-server:0.0.1` 只读挂载该目录到容器内 `/var/log/siye`。未配置文件路径时两个 Node 服务保持原行为，不影响现有 systemd 链路。两个新镜像完成服务器真实日志查询验证前仍不得正式切流。
- 日志双写版本已完成本地验证：music-api 完整 `npm run verify` 12 项通过，easy-chat `yarn verify` 通过；两个 DaoCloud 基础镜像的本地 Docker 构建成功，均以非 root `node` 用户向同一临时卷生成 `music-api.log`、`music-api-error.log`、`socket.log`、`socket-error.log`，同时 `docker logs` 仍保留输出。源码提交分别为 `5d2aaf351e6971f591bee2a1c63b6df2452822e9` 和 `3ef336159c3f56df470ea2305c0d2ecd81cc0eff`，对应的 `music-api:0.0.2`、`easy-chat:0.0.2` 已由 Actions 发布。
- 正式 Docker 栈已于 2026-07-21 在 `/opt/siye-production` 完成并行启动：core 五容器、Sub2API 三容器、svg-draw 和 edge-nginx 全部 `healthy` 且重启次数为 `0`；业务容器和数据库均未发布宿主机端口，edge 仅绑定 `127.0.0.1:18080/18443`。正式文件日志双写、日志查询、新 MySQL 消息幂等、内部 DNS、八个已部署 Host 的 HTTP/HTTPS 路由、通配符证书、Socket.IO/CORS 和 HTTP `308` 跳转均已验证。并行启动阶段旧宿主机 Nginx、旧 `/sub2api` 容器和三个 systemd 服务保持运行；正式切流完成后旧运行实例已按下线步骤停止并禁用。
- 正式 Sub2API 按用户决定使用全新 PostgreSQL、Redis 和应用数据卷，不迁移旧 `/sub2api` 数据；旧服务继续保留为切流前回退入口。正式聊天 MySQL 也按用户决定不迁移旧 systemd 数据库中的 26 条消息，新库删除 `production-smoke` 冒烟记录后从空数据开始；旧 systemd MySQL 数据库保持不动，作为历史数据和回退链路保留。
- 正式入口已于 2026-07-21 完成切流：宿主机 Nginx 继续占用公网 `80/443`，Docker edge 继续只绑定 `127.0.0.1:18080/18443`；宿主机按 Host 将流量代理到 `https://127.0.0.1:18443`，容器没有直接抢占公网端口。切换包位于 `Docker专题/正式部署/siye-stack/宿主机Nginx切流/`，v2 在 Nginx 优雅重载后等待新 worker 实际提供正确证书和主站内容，然后完成 8 个 HTTPS Host、Socket.IO、9 个 HTTP `308` 和 `knowledge.siyes.cn` `503 pending` 验收。本次回滚状态位于 `/opt/siye-production/backups/host-nginx-cutover-20260721-163248`；4 个旧站点文件仍保留，只禁用了对应 `sites-enabled` 软链接。
- 切流后已从服务器外部网络复验：8 个正式 HTTPS 入口均返回 `200`、TLS 校验结果为 `0`且连接腾讯云服务器；`knowledge.siyes.cn` 返回预期 `503` 且 TLS 校验为 `0`；Socket.IO polling、正式 Origin CORS 和 music-api CORS 预检均通过。切流验收期间旧 systemd 服务和旧 Sub2API 保持运行，完成最终确认后已停止并禁用。
- 切流后的浏览器真实验收已通过：主站 HTTPS 与备案页面正常；`music.siyes.cn` 音乐搜索返回 `200`，聊天消息保存 POST、历史查询 GET 和 Socket.IO polling 均返回 `200`，新消息可在日志查询页查到；音频实际播放已由用户人工确认；`draw.siyes.cn` 页面和静态资源正常；`sub2api.siyes.cn` 管理员登录、管理 API 和真实上游调用均正常，宿主机 Nginx 的 `client_max_body_size 100m` 已生效，原 `/responses` 请求的 `413` 已解决；`knowledge.siyes.cn` 返回预期的 `503 pending`。
- 2026-07-21 21:09 完成旧链路下线：`music-api.service`、`linux-server.service`、`easy-chat.service` 均为 `disabled/inactive`；旧 `sub2api`、`sub2api-postgres`、`sub2api-redis` 均为 `exited` 且 `restart=no`；旧 `3000/3030/8080/8081` 端口均未监听。正式十个 Docker 容器均为 `running/healthy` 且 `restart=unless-stopped`，Docker、宿主机 Nginx 和 `certbot.timer` 均为启用状态。下线前后状态备份位于 `/opt/siye-production/backups/legacy-stop-20260721-210035`；旧 MySQL、旧服务目录和旧数据仍保留，未删除。
- 旧域名 `music.siyefun.top` 当前解析到腾讯云服务器，但该旧域名没有完成腾讯云接入备案；腾讯云对 HTTP GET 直接返回 `302` 并跳转到 DNSPod `webblock.html`，请求没有进入宿主机 Nginx。该现象不是正式 Docker 切流故障；新正式入口固定为 `https://music.siyes.cn`。旧域名若继续保留在阿里云 Windows，应另行确认其 DNS 是否需恢复到旧阿里云服务器；未经用户确认不修改其 DNS、Nginx 或备案接入。
- 2026-07-20 手动触发 Actions 时额外误触发布了 `siye-world:0.0.4`，该镜像同样来自提交 `3ef336159c3f56df470ea2305c0d2ecd81cc0eff`，本次提交没有前端功能变更。`0.0.4` 作为已发布的不可变历史制品保留但不部署，正式生产草案继续固定使用经过正式域名配置确认的 `siye-world:0.0.3`；不得因为 Docker Hub 上存在更高版本而自动改用 `0.0.4`。

### 运行时配置、部署和回滚

- 服务器 `.env` 保存镜像版本、CORS、数据库连接、日志目录和部署端口等运行时配置，权限至少为 `600`，不提交 Git、不打进镜像。
- 修改已有 MySQL 数据卷使用的账号密码时，不能只修改 `.env`；必须同步执行 `ALTER USER`，再更新 `linux-server` 配置并验证连接。
- 正式更新流程：备份当前 Compose 和 `.env`、修改目标镜像版本、执行 `docker compose pull`、`docker compose config`、`docker compose up -d`、健康检查和真实接口冒烟验证。
- 正式回滚通过把 `.env` 中的镜像标签恢复到上一版本，再执行 `docker compose pull && docker compose up -d`；数据库变更必须优先采用向后兼容迁移，不能依赖镜像回滚自动回滚数据。
- Node 服务默认日志仍输出 Docker stdout；正式 `core` 在 `0.0.2` 起额外双写到独立宿主机日志目录，由 `linux-server` 只读查询。后续如果改用 Loki/Promtail 等集中采集，必须保留日志查询接口的兼容迁移和回滚方案。

### 第七套：准生产发布演练计划

- 演练定位：第一次完全使用 GitHub Actions 和 Docker Hub 正式版本镜像完成部署，不再通过压缩包上传源码，也不在服务器执行源码构建；继续与现有 `systemd + 目录部署` 主链路并行，不直接替换当前可用服务。
- 第七套及后续版本升级、回滚演练期间，整套 systemd Linux 服务与配置均不得改动：演练命令不得包含针对 `music-api`、`easy-chat`、`linux-server` 的 `systemctl stop/restart/disable/mask`，不得执行 `daemon-reload` 来加载相关变更，不得编辑相关 unit、环境文件、部署目录、Nginx 现有配置、日志配置或占用 `3000/3030/8081`。每个阶段只检查三个服务仍为 `active`；出现 Docker 故障时只能修复、回滚或停止演练容器，不能通过调整 systemd 主链路来迁就演练环境。
- 本地演练材料已建立在 `Docker专题/Docker演练/siye-release-drill/`，服务器目录计划使用 `/opt/docker-labs/siye-release-drill/`。阶段 1 已包含 `compose.release-drill.yml`、`.env.example`、`阶段1-发布演练.md`、`验收清单.md` 和 `回滚步骤.md`；Nginx 配置在统一网关阶段再加入，避免阶段 1 混入尚未验证的服务。
- 阶段 1 已于 2026-07-16 完成：服务器通过 `docker compose pull` 拉取 `siyesummer/music-api:0.0.1`，RepoDigest 为 `sha256:effd6e0ac198e62e9b27804bc5a5c0066b7eb71b4efc043e57130c970b14732d`；`drill7-music-api` 使用 `3100 -> 3000`，持续为 `running/healthy` 且重启次数为 `0`。
- 阶段 1 已完成服务器新旧链路、CORS 允许与拒绝来源、Windows 公网直连以及本地 `siyeWorld` 真实搜索、用户歌单和歌曲请求验证；原 systemd `music-api.service` 保持 `active` 且 `3000` 链路未受影响。腾讯云 `3100` 对全部 IPv4 开放已登记为演练期间的安全例外，统一入口验收后必须删除该规则。
- 阶段 2 的镜像发布准备已完成：`linux-server` 仓库已新增正式 Dockerfile、Compose 示例、`.env.example`、Docker Hub Description、GitHub Actions 自动版本发布工作流和本地 `pre-push` Maven 校验，并清理了未提交部署模板中的明文 MySQL 密码。
- `linux-server` 发布候选版已通过 12 项 Java 测试、Compose 解析、非 root 镜像构建和隔离 MySQL 真实冒烟；`/health`、CORS 允许/拒绝、聊天写入与查询、日志查询均通过，容器为 `healthy` 且重启次数为 `0`，这些结果作为 `0.0.1` 正式发布前的本地基线证据。
- `linux-server:0.0.1` 已于 2026-07-16 完成正式发布：源码提交为 `a49c3a45ff6c2a1ef771cd241013b592c4f0cffe`，GitHub Actions Run 为 `29485330681`，`linux-server-v0.0.1` Tag/Release、Docker Hub `0.0.1` 与 commit SHA 标签、`linux/amd64`、`linux/arm64` 以及 Docker Hub Description 均已成功。
- 第七套阶段 2 服务器演练材料已补齐：将 MySQL `8.0.39` 和 `siyesummer/linux-server:0.0.1` 加入同一 Compose，MySQL 只连接内部 `data-net` 且不映射宿主机端口，Java 临时使用 `8181 -> 8081`，下一步为上传配置包并在服务器逐步验证。
- 第七套阶段 2 服务器冒烟已通过：`drill7-mysql`、`drill7-linux-server`、`drill7-music-api` 均为 `running/healthy` 且重启次数为 `0`；MySQL 无宿为端口，Java 以 `10001:10001` 运行，日志查询、CORS、聊天写入/历史查询和 `save_count=1` 均已验证；原 systemd `8081` 链路仍返回 `200`。阶段 2 只剩本地 `siyeWorld` 通过公网 `8181` 真实联调。
- 第七套阶段 2 本地 `siyeWorld` 真实联调已通过：日志查询和聊天历史返回 `200`，三条前端消息均持久化且无重复 `message_id`，`client_ip=192.0.2.10` 证明当前公网 Docker 端口链路保留了真实来源 IP。阶段 2 已完成，下一项为阶段 3 `easy-chat:0.0.1`。
- `easy-chat:0.0.1` 已由 `siyeWorld` 仓库 GitHub Actions 正式推送到 Docker Hub，同时生成 `0.0.1` 和 `sha-3d07580aab723...` 标签并同步 Docker Hub Description；源码提交为 `3d07580aab723b959256162bfb883daa03ce8ba7`。第七套阶段 3 Compose、环境模板、操作手册、验收与回滚材料已补齐，计划临时使用 `3130 -> 3030` 与原 systemd `3030` 并行验证。
- 第七套阶段 3 已完成：服务器拉取 `siyesummer/easy-chat:0.0.1`，RepoDigest 为 `sha256:5c7d7374a871094b7bd1a870603bbccc30737f8f2553bf9172bd3b73a1384be7`；`drill7-easy-chat` 使用 `3130 -> 3030`、只加入 `edge-net`、以非 root `node` 用户运行，并保持 `running/healthy/RestartCount=0`。
- 阶段 3 本地真实联调已通过：浏览器通过 `203.0.113.10:3130` 完成 Socket.IO polling 和实时广播，通过 `8181` 保存消息并在刷新后读取历史；MySQL 新记录 `uT256RN29ZXGGoVEXTvQPKHpruEJS983` 唯一存在，`client_ip=192.0.2.10`。四个第七套容器均为 `healthy/0`，原 `easy-chat.service` 与 `3030` 链路未受影响。
- 第七套阶段 4 edge-nginx 已于 2026-07-17 完成：使用官方固定版本 `docker.m.daocloud.io/library/nginx:1.27-alpine`，IMAGE_ID/RepoDigest 为 `sha256:65645c7bb6a0661892a8b03b89d0743208a18dd2f3f17a54ef4b76fb8e2f2a10`，临时入口 `8090 -> 80`，只加入 `edge-net`；`/music-api/*`、`/socket.io/*`、`/api/*` 三条路由均通过服务器、公网和本地 siyeWorld 验证。
- 为支持阶段 4 本地前端统一入口，`siyeWorld` 日志查询地址已改为读取 `VUE_APP_LOG_SERVER_BASE_URL`；阶段 4 曾临时使用根 `.env.local` 指向 `http://203.0.113.10:8090`。阶段 5 已删除该临时文件并改为提交 `.env.development/.env.production`，历史配置不再作为当前开发入口。
- 阶段 4 真实消息 `uS4mV1mPaPImjcwdpFduFvVD1yq4hOVE`（内容“厉害了”）通过统一入口保存，MySQL 中 `client_ip=192.0.2.11`、`save_count=1`，刷新后历史和日志聚合均能读取；五个容器全部 `running/healthy/RestartCount=0`，三个 systemd 服务仍为 `active`。
- 阶段 4 启动 edge-nginx 时 Compose 重新创建了 music-api 和 linux-server；二者快速恢复健康，MySQL 未重建且数据未丢失。正式更新前必须继续先执行 `docker compose config` 并关注 `up` 是否会重建依赖服务，不能把“只指定一个服务”误认为其他服务一定不会被协调更新。
- 阶段 5 本地发布准备已于 2026-07-18 完成：`siyeWorld` 仓库新增 `deploy/siye-world/` 多阶段 Dockerfile、Nginx SPA 配置、Compose 示例和 Docker Hub README，并新增独立的 `Release siye-world image` 手动 Workflow。浏览器配置拆分为 `.env.development` 和 `.env.production`；当前演练构建由 Workflow、Dockerfile 和 Vue CLI 共同读取 `.env.production` 中的 `203.0.113.10:8090`，不依赖本机 `.env.local`。
- 阶段 5 的 edge-nginx 根路径改为代理 `siye-world:80`，`/health` 保留网关自身探针，`/music-api/`、`/socket.io/`、`/api/` 继续优先匹配后端。前端从 `http://203.0.113.10:8090` 提供服务时，music-api、easy-chat 和 linux-server 三项 CORS 白名单必须同时加入这个完整 Origin。
- 阶段 5 的 `http://203.0.113.10:8090` 用于前端容器健康、静态资源、SPA、音乐、Socket.IO、聊天历史和日志的完整演练。备案完成后修改 `.env.production` 为独立 HTTPS 域名并发布下一新版本，再由宿主机 Nginx 按 8 个 Host 接收 `80/443` 流量；正式域名验收后才关闭 `8090` 公网入口。
- 阶段 5 同时已验证 Pages 专用构建能力：`.env.pages` 复用演练 IP，资源前缀为 `/siyeWorld/`、路由为 hash、包含 `.nojekyll`。当前不创建或启用 Pages 发布 Workflow；按原计划仅在第七套全部完成且备案仍未通过时再新增手动 Pages 发布流程。
- 第七套阶段 5 已于 2026-07-18 完成：`siyesummer/siye-world:0.0.1` 由 GitHub Actions 正式发布，源码提交为 `2ac790c806658a583ea00e1f8a11ec61e819c305`，服务器拉取到的 RepoDigest 为 `sha256:e3260fccde648467f94c581b83301f1548784b663572a551d536e6330c058694`；`drill7-siye-world` 只加入 `edge-net`、不发布宿主机端口，并保持 `running/healthy/RestartCount=0`。
- 阶段 5 服务器、公网和浏览器完整验收已通过：`/` 与 `/log-query` SPA 路由、`/music-api/*`、`/socket.io/*`、`/api/*` 均经 `203.0.113.10:8090` 返回成功，浏览器 Network 不再请求 `3100/3130/8181`；真实消息 `ugN4Bc047ZgoMLvTjV9Yk0LuCodbVmWb`（内容“看上去通了”）在 MySQL 中 `save_count=1`、`client_ip=192.0.2.11`。六个容器全部 `healthy/0`，三个 systemd 服务保持 `active` 且未修改任何 systemd 配置。
- 阶段 5 发生过一次可恢复的 `502`：为加载新 CORS 而重建三个后端容器后，仍在运行的 edge-nginx 缓存了后端旧容器 IP。三个后端直连健康，启动 `siye-world` 后仅重建 edge-nginx 即恢复。后续重建任何被 Nginx 静态 `proxy_pass` 引用的容器时，都必须先等待目标容器健康，再用 `--no-deps --force-recreate edge-nginx` 让网关重新解析 Docker DNS；不能把该问题误判为 CORS 或通过修改 systemd 解决。
- 阶段 6 默认以无状态 `siye-world` 为升级对象，执行真实的 `0.0.1 -> 0.0.2 -> 0.0.1`。`0.0.2` 必须由 GitHub Actions 正式发布、具有独立 Tag/Release 和可验证的新镜像 digest，并在域名审核期间继续使用 `IP:8090` 演练配置；不能用同一镜像的 commit SHA 标签冒充真实升级，也不能提前切换正式 HTTPS 域名。`0.0.2` 起镜像通过 Workflow 构建参数写入 `/release.json` 和 OCI `version/revision` 标签，升级后用该接口验证实际版本；`0.0.1` 不含此接口，回滚后以阶段 5 记录的 image ID、RepoDigest 和业务行为作为恢复证据。
- 镜像与服务边界：
  - `siyesummer/music-api:0.0.1`
  - `siyesummer/linux-server:0.0.1`
  - `siyesummer/easy-chat:0.0.1`
  - 最后发布和部署的 `siyesummer/siye-world:0.0.1`
  - MySQL 使用官方固定版本镜像，不制作业务 MySQL 镜像
  - edge-nginx 演练阶段可使用官方固定版本 Nginx 镜像和版本化配置文件
- 演练阶段顺序：
  1. 服务器检查磁盘、Docker、现有容器、端口和网络，备份演练 Compose 与 `.env`，确认不影响 `systemd` 主链路及第六套演练。
  2. 依次完成 `music-api`、`linux-server`、`easy-chat` 正式镜像发布，并在服务器只通过 `docker compose pull` 拉取明确版本；记录镜像 digest，后续阶段不得重新构建同一版本。
  3. 后端容器先临时发布独立宿主机端口，本地 `siyeWorld` 使用 `203.0.113.10 + 端口` 手工验证音乐 API、Socket.IO、消息保存、历史查询和日志接口。
  4. 后端直连验证通过后加入 edge-nginx，通过一个统一 IP 端口验证 `/music-api`、`/socket.io`、`/api` 等代理链路和容器内部 DNS。
  5. 最后发布并部署演练版 `siye-world:0.0.1`，通过 `8090` 完成完整业务验收。备案和 HTTPS 完成后修改 `.env.production`，发布下一新版本并执行正式域名验收。
  6. 完成一次真实升级和回滚演练，例如 `0.0.1 -> 0.0.2 -> 0.0.1`，确认镜像回滚、MySQL 数据保留、容器健康和日志排查流程都可用。
- 临时端口建议先以 `3100 -> 3000`、`3130 -> 3030`、`8181 -> 8081`、`8090 -> 80` 为候选，执行前必须使用 `ss -lntp` 和 `docker ps` 确认未占用；MySQL 不发布宿主机端口。
- 本地前端实际 Origin 必须加入各后端 CORS 白名单；`music-api` 已支持逗号分隔的多 Origin。正式 `core/.env` 的三项 CORS 当前统一允许 `https://music.siyes.cn`、`http://siyefun.top`、`http://music.siyefun.top`、`http://localhost:8080` 和 siyeWorld GitHub Pages Origin `https://siyesummer.github.io`。GitHub Pages 实际页面路径为 `/siyeWorld/`，但 CORS Origin 不包含路径；协议和端口属于 Origin 的一部分。
- 网络仍按正式方案划分：`edge-net` 连接 edge-nginx、siye-world 和各业务服务，`data-net` 只连接 linux-server 与 MySQL；MySQL 不进入 `edge-net`。
- 临时后端公网端口只用于演练，优先在腾讯云安全组限制为当前本地公网 IP。统一入口和前端镜像验收完成后，必须关闭或限制 `3100/3130/8181`，最终只保留 edge-nginx 对外入口。
- 当前用户选择在腾讯云控制台手动添加演练端口规则，并暂时接受测试端口对全部 IPv4 开放；这是演练期间的已知安全例外，不作为生产基线。统一入口验收完成后必须删除 `3100/3130/8181` 入站规则，MySQL 全程不开放公网端口。
- 每一阶段都设置停止条件：容器必须达到 `running/healthy`、重启次数为 `0`、日志无新增异常、真实请求返回预期结果；任一阶段失败先保留日志和镜像版本，不继续叠加部署下一服务。
- 最终验收至少覆盖：音乐搜索和用户歌单、Socket.IO polling/WebSocket、实时聊天广播、消息持久化和历史翻页、日志查询、MySQL 数据卷重建后数据保留、Nginx 统一代理、前端刷新路由、容器重启恢复、版本升级及回滚。
- 演练完成标准：服务器全程未现场构建业务源码；Compose 固定使用明确版本或 digest；四个业务镜像均能追溯到 Git Tag、GitHub Release 和 commit SHA；后端临时端口已回收；回滚步骤和验证证据已写入演练文档。
- 正式域名验收标准：8 条 DNS 解析保持正常；每个域名的 Nginx Host 命中正确服务；HTTPS 证书有效；HTTP 正确跳转 HTTPS；`music.siyes.cn` 前端和 SPA history 通过；页面跨域访问 `music-api.siyes.cn`、`linux-api.siyes.cn`、`socket.siyes.cn` 全部成功且 CORS 精确；`sub2api.siyes.cn`、`draw.siyes.cn` 可分别完成验证；完成前不得删除演练 IP/端口回滚入口。
- `siyesummer/siyeWorld` 已新增 `.github/workflows/deploy-github-pages.yml`，使用 `workflow_dispatch` 手动触发：按 `yarn.lock` 安装依赖，执行 `yarn verify` 和 `yarn build:pages`，上传 `dist` 后通过 GitHub 官方 Pages Actions 部署；`push` 不会自动发布。
- GitHub Pages 发布来源已使用 GitHub Actions，访问地址为 `https://siyesummer.github.io/siyeWorld/`；该入口现在部署 Vue 前端制品，不再作为只渲染根 `Readme.md` 的 Jekyll 文档站。

### 正式发布前待确认项

- 当前 4 个 Docker Hub 镜像仓库均为 Public；`music-api:0.0.1` 已公开发布并确认接受镜像包含运行源码，其他业务镜像首次正式推送前仍需分别确认公开范围，不能接受则切换为 Private 并在服务器执行 Docker Hub 登录。
- `linux-server` 正式独立域名已确定为 `linux-api.siyes.cn`，DNS `A` 记录已正常解析到腾讯云服务器；后续只需补齐对应 Nginx Host、HTTPS 证书、HTTP 跳转和独立接口验收，不再使用待定的 `api.siyes.cn` 表述。
- 正式生产 Compose 基线已另建于 `Docker专题/正式部署/siye-stack/`，并通过本地 Compose 结构校验和 edge-nginx HTTP `nginx -t`；当前只完成本地准备，尚未上传或启动服务器生产栈。
- 正式启动前不再要求 `siyes-home` 镜像；当前首页直接只读挂载宿主机静态 HTML。`music-api:0.0.2`、`easy-chat:0.0.2` 已发布，仍需完成服务器日志双写验证、聊天和 Sub2API 数据备份恢复与 8 域名证书。任一项未完成都不能切换宿主机 `80/443`。

## 当前重要部署文档与运维文档

以下文档当前位于本地项目 `E:\本地项目\java-project\linux-server\deploy`，后续继续部署或回滚时应优先参考：

- `SERVER_STEPS.md`
- `CHAT_STORAGE_MYSQL_STEPS.md`
- `LOG_QUERY_CHAT_HISTORY_STEPS.md`
- `mysql-chat-storage.sql`
- `mysql-chat-client-ip-migration.sql`
- `linux-server.service`
- `easy-chat.service`
- `easy-chat-server.js`
- `RELEASE_CHECKLIST.md`
- `DEPLOY_ROLLBACK_SOP.md`
- `CHAT_STORAGE_FRONTEND_MIGRATION.md`

当前仓库内新增的 Docker 学习资料统一放在 `Docker专题` 目录下：
- [Docker专题/README.md](E:/本地项目/frontend-knowledge/Docker专题/README.md)
- [Docker命令说明.md](E:/本地项目/frontend-knowledge/Docker专题/Docker命令说明.md)
- [Docker演练步骤.md](E:/本地项目/frontend-knowledge/Docker专题/Docker演练/linux-server-mysql/Docker演练步骤.md)

## 文档使用建议

- 任何会影响 `linux-server` 或 `easy-chat` 启动链路的变更，先看 `RELEASE_CHECKLIST.md`
- 任何需要上服务器替换 jar、脚本、service 文件的动作，按 `DEPLOY_ROLLBACK_SOP.md` 执行
- 任何涉及 MySQL 建库建表和聊天室持久化的操作，优先看 `CHAT_STORAGE_MYSQL_STEPS.md`
- 任何涉及聊天持久化职责从 Socket Server 迁移到前端的发布动作，优先看 `CHAT_STORAGE_FRONTEND_MIGRATION.md`
- 任何涉及日志查询页接入聊天历史消息的发布动作，优先看 `LOG_QUERY_CHAT_HISTORY_STEPS.md`
- Docker 初学阶段，优先结合 [Docker命令说明.md](E:/本地项目/frontend-knowledge/Docker专题/Docker命令说明.md) 做命令记忆和本地/服务器演练
- 当前服务器 Docker 演练从 [Docker演练步骤.md](E:/本地项目/frontend-knowledge/Docker专题/Docker演练/linux-server-mysql/Docker演练步骤.md) 开始，先跑 `mysql + linux-server`，不要直接动现有 `systemd` 版本

## 当前协作约定

- 后续如果要修改服务器上的 `music-api`、`easy-chat`、`linux-server` 入口文件、配置文件、日志格式、启动方式，默认优先在本地对应项目中修改，再同步到服务器。
- 涉及服务启动、数据库初始化、Spring Bean 注入、systemd 配置的改动，按接近生产的标准处理，不能只以本地“看起来能跑”为准。
- 后续凡是涉及 Java、Maven、Spring Boot、Docker、MySQL、Linux 部署命令的说明，默认采用“给转全栈的前端同学看的版本”输出：除了给步骤，还要说明这一步是在做什么、命令为什么这样写、命令是按当前目录执行还是按明确路径执行、什么时候该用哪一种写法。
- 发布前至少完成：
  - 本地测试
  - 本地打包
  - 必要的语法检查
  - 真实 jar 冒烟启动
  - 回滚文件与回滚命令预先准备

## 后续协作建议

- 当新增知识点时，优先放到语义最接近的现有资料文件中；如果当前没有合适分类，再新增文件。
- 关于部署、运维、后端学习的内容，后续可以逐步建立独立的专题文档目录。
- 与服务器、域名、Nginx、Linux、Docker、数据库、Redis、Java 后端相关的实践记录，建议持续沉淀到仓库内，便于复盘和面试使用。
- 这份 `AGENTS.md` 作为仓库背景说明文件，后续可持续补充项目结构、技术栈、学习进度、服务器资产和部署现状。

## 最近更新补充

- 当前 Docker 学习资料已经统一归档到 `Docker专题/`，Linux 与 Nginx 相关资料统一归档到 `linux/`。
- 当前第一套 Docker 演练已完成并验证：`mysql + linux-server`，端口映射为 `3307 -> 3306`、`8082 -> 8081`。
- 当前第二套 Docker 演练已完成并验证：`easy-chat + linux-server + MySQL`，端口映射为 `3308 -> 3306`、`8084 -> 8081`、`3031 -> 3030`。
- systemd 主链路与第二套 Docker 演练均已完成持久化职责迁移并验证；两套环境中均由前端分别调用 `easy-chat` 和 `linux-server`，Socket Server 只负责实时广播。
- systemd 主链路最终验证证据：前端 `POST http://203.0.113.10:8081/api/chat/messages` 返回 `200`，Socket 日志记录 `after-decouple-1818` 的 `clientMsg`，MySQL 查询结果 `save_count = 1`，`socket-error.log` 无新增错误。
- 第二套 Docker 演练增量更新包已生成到 `Docker专题/Docker演练/easy-chat-linux-server-mysql-update.tar.gz`，包含新 JAR、解耦后的 Socket Server、Compose 和 Dockerfile，不包含服务器 `.env`。
- 第二套 Docker 演练的 `linux-server` 与 `easy-chat` 镜像已通过 DaoCloud 基础镜像源构建，并在服务器重建成功；`lab2-linux-server`、`lab2-easy-chat`、`lab2-mysql` 均为 `running` 且重启次数为 `0`，MySQL 容器和数据卷未重建。
- 第二套 Docker 演练最终验证证据：本地前端 `POST http://203.0.113.10:8084/api/chat/messages` 返回 `200`，消息 `docker-decouple-1825` 实时显示并可读取，Docker MySQL 查询结果 `save_count = 1`。
- 当前 Docker 演练的实际目标是先学习编排和联调，不替换现有 `systemd + 目录部署` 主链路。
- `NeteaseCloudMusicApi-private` 本地仓库已新增 `deploy/Dockerfile`、`deploy/README.md` 和 `.github/workflows/release-image.yml`，使用 `workflow_dispatch` 手动发布、自动版本递增、多架构构建、Docker Hub 推送、Git Tag 和 GitHub Release。
- 由于该仓库保留上游 `v4.x` Tag，正式 Git Tag 使用 `music-api-v0.0.1` 前缀序列，Docker Hub 镜像仍使用 `siyesummer/music-api:0.0.1`；本地正式 Dockerfile 构建和 `/search` 冒烟验证已通过。
- `music-api:0.0.1` 已完成 GitHub Actions 首次正式发布：Docker Hub 版本标签和 commit SHA 标签、多架构镜像、Docker Hub Description、`music-api-v0.0.1` Git Tag 和 GitHub Release 均已成功；下一步推广到 `linux-server` 和 `siyeWorld/easy-chat`，并进入第七套准生产发布演练。
- 第三套 `music-api` Docker 演练已部署到服务器 `/opt/docker-labs/music-api/`，使用 `3002 -> 3000` 与现有 `systemd` 版本并行运行。
- 第三套演练已经完成服务器和本地前端真实验证：`lab3-music-api` 状态为 `running`、重启次数为 `0`，本地前端通过 `http://203.0.113.10:3002/search` 请求返回 `200`，响应头包含 `Access-Control-Allow-Origin: *`。
- `music-api` Docker 演练使用本地 `E:\本地项目\NeteaseCloudMusicApi-private` 完整源码构建；不能只复制 `app.js`，也不能把本地 `node_modules` 上传到 Linux 容器。
- Docker 版 `music-api` 默认通过 `docker compose logs` 查看日志，不会自动写入 systemd 版本使用的 `/var/log/siye/music-api.log`。
- `music-api` 的 `server.js` 已支持通过环境变量 `CORS_ALLOW_ORIGIN` 配置单个 Origin、逗号分隔的多个 Origin 或 `*`，未配置时默认使用 `*`；多 Origin 模式会按请求 Origin 返回当前命中的单个值并设置 `Vary: Origin`，未授权来源不返回 CORS 许可头。
- 本地 Windows 开发环境已安装 Docker Desktop `4.82.0`，已确认 Docker CLI `29.6.1` 和 Docker Compose `v5.3.0` 可执行。
- Docker Desktop 当前使用 WSL 2 后端；WSL 组件安装后已完成系统重启，本地 Docker Engine 已验证可用。
- 本地 Docker Engine 已在重启后验证成功，`hello-world` 运行通过；首次构建 `music-api` 时 Docker Hub 授权域名不可达，已验证 `docker.m.daocloud.io/library/node:20-bookworm-slim` 可作为临时 `NODE_IMAGE` 来源。
- 本地已使用 `docker.m.daocloud.io/library/node:20-bookworm-slim` 成功构建 `siye-music-api:4.13.8`，并以 `3002 -> 3000` 启动验证；CORS 预检返回 `204`，`/search` 返回 `code: 200`。冒烟测试容器已删除，镜像保留在本地。
- 第四套 `nginx + music-api` Docker 演练材料已整理到 `Docker专题/Docker演练/nginx-music-api/`，使用 `8085 -> 80` 反向代理宿主机 `3002` 上的 Docker `music-api`。
- 第四套演练已完成 Windows 本地和 Linux 服务器验证：`siye-nginx-music-api:1.0.0` 构建成功，`nginx -t` 通过，服务器 `lab4-nginx` 达到 `running healthy 0`，使用 `8085 -> 80`；本地前端通过 `http://203.0.113.10:8085/search` 请求返回 `200`，响应头包含 `Access-Control-Allow-Origin: *`。
- 第五套共享网络演练材料已整理到 `Docker专题/Docker演练/nginx-music-api-network/`，使用同一 Compose 的 `app-net`，由 Nginx 通过 `music-api:3000` 服务名访问上游；只发布 `8086 -> 80`，music-api 不映射宿主机端口。
- 第五套已完成 Windows 本地和 Linux 服务器验证：两个 `5.0.0` 镜像构建成功，`lab5-music-api` 和 `lab5-nginx` 均达到 `running healthy 0`，内部 DNS 能解析 `music-api`，`8086/search` 返回 `code: 200`，且 `docker port lab5-music-api` 无输出。
- 第六套完整多服务 Compose 演练材料已整理到 `Docker专题/Docker演练/siye-stack/`，将 MySQL、linux-server、easy-chat、music-api 和 Nginx 统一放入 `app-net`，仅发布 `8087 -> 80`。
- 第六套已完成 Windows Docker Desktop、Linux 服务器和本地前端真实联调验证：4 个自定义镜像构建成功，服务器 `lab6-mysql`、`lab6-linux-server`、`lab6-easy-chat`、`lab6-music-api`、`lab6-nginx` 均为 `running healthy 0`；music-api 源码使用本地 `E:\本地项目\NeteaseCloudMusicApi-private`。
- 本地前端通过 `http://203.0.113.10:8087` 完成音乐搜索、Socket.IO、聊天保存、历史读取和日志查询，相关请求均返回 `200`；MySQL 两条测试消息的 `sender_id` 不同、`client_ip` 均为 `192.0.2.10`，历史接口均返回 `isSelf: true`。

## 2026-07-21 最终生产状态

本节记录正式切流和旧服务清理后的当前状态；与前文演练期、并行验证期或观察期描述冲突时，以本节为准。

- 正式公网入口已改为 Docker edge 直连：`siye-prod-edge-nginx` 直接绑定 `0.0.0.0:80/443`，旧 `127.0.0.1:18080/18443` 不再监听。宿主机 Nginx、`nginx-common` 和 `python3-certbot-nginx` 已彻底卸载，`nginx.service LoadState=not-found`，`/etc/nginx` 等宿主机残留已清理；正式 Docker edge 保持 `running/healthy`、`restart=unless-stopped`。
- 卸载 `python3-certbot-nginx` 后已复核证书自动续期链路：Certbot `2.9.0` 保留，`siyes-production` 仍使用 `manual + dns-01`，DNSPod auth/cleanup Hook 和 Docker edge deploy Hook 均为 `700 root:root`，`certbot.timer` 为 `active/enabled`；deploy Hook 已再次通过容器内 `nginx -t` 并成功平滑重载 `siye-prod-edge-nginx`。
- Docker edge 已补齐 `knowledge.siyes.cn` Host；应用上线前 HTTP 返回 HTTPS `308`，HTTPS 返回 `503 pending`。缺失 Host 配置更新备份位于 `/opt/siye-production/backups/edge-knowledge-route/20260721-221250`。
- 8 个正式 HTTPS Host、9 个 HTTP `308`、Socket.IO/CORS、音乐播放、聊天、日志、Sub2API 真实调用和 `client_max_body_size 100m` 均已验收。证书部署 Hook 已验证可直接执行 `siye-prod-edge-nginx` 容器内 `nginx -t` 和平滑重载。
- Docker edge 公网直连回滚状态位于 `/opt/siye-production/backups/docker-edge-direct-cutover/20260721-221641`；第一阶段宿主机 Nginx 代理回滚状态位于 `/opt/siye-production/backups/host-nginx-cutover-20260721-163248`。
- Docker edge 公网直连脚本已统一归档到 `Docker专题/正式部署/siye-stack/`：旧版保留在 `Docker入口直连切流-v1/`，补齐 `knowledge.siyes.cn` 配置安装与验证的实际切流版本保留在 `Docker入口直连切流-v2/`；原仓库根目录的 v2 临时展开副本已移入正式部署目录，不再作为独立项目维护。
- 旧 `music-api.service`、`linux-server.service`、`easy-chat.service` unit 已删除，`LoadState=not-found`；旧 `/opt/music-api`、`/opt/easy-chat`、`/opt/linux-server` 和 `/var/log/siye` 已删除，旧 `3000/3030/8081` 不再监听。宿主机 MySQL 软件、配置、`/var/lib/mysql` 和依赖已清理，宿主机 `3306` 不再监听；正式 Docker MySQL 和其他正式容器均保持 `running/healthy`、`restart=unless-stopped`。
- 旧 Sub2API 已彻底清理：旧 `sub2api`、`sub2api-postgres`、`sub2api-redis` 容器已删除，旧网络 `sub2api_sub2api-network` 已删除，旧 `/sub2api` 目录已删除，未发现旧命名数据卷和 systemd unit；`weishaw/sub2api:latest`、`postgres:18-alpine`、`redis:8-alpine` 旧标签已取消。正式 `siye-prod-sub2api*` 容器、digest 镜像、`/opt/siye-production/sub2api` 和 `siye-prod-sub2api-*` 数据卷保持 `running/healthy`，`https://sub2api.siyes.cn/health` 返回 `{"status":"ok"}`。
- Docker 学习环境已清理：20 个 `drill7-*`/`lab*` 容器、8 个学习网络、5 个学习数据卷、17 个学习或旧版本镜像标签以及非正式 `mysql:8.0.39` 标签均已删除；Docker 构建缓存释放约 `1.251GB`，宿主机 MySQL 自动依赖释放约 `241MB`。正式镜像、容器、网络和命名数据卷保持不变。
- 正式 `siye-prod-sub2api-postgres` 还挂载 PostgreSQL 18 镜像自动创建的匿名父卷 `c5439b1ef25e833c77d72863ef8cd6b36d7c9f7100fad61185278b311f519fd8` 到 `/var/lib/postgresql`，正式命名数据卷 `siye-prod-sub2api-postgres-data` 挂载到 `/var/lib/postgresql/data`。匿名父卷当前由正式容器引用，必须保留；不得执行无差别 `docker volume prune`。
- 后续清理仍不得删除 `/opt/siye-production`、`/var/log/siye-production`、正式 Docker 数据卷、证书、正式 Compose 配置、PostgreSQL 匿名父卷或上述回滚备份。

## 2026-07-22 网络与防火墙基线

- 当前生产只使用 IPv4；腾讯云实例尚未启用公网 IPv6，DNSPod 仅维护 `A` 记录，没有 `AAAA` 记录。现阶段不启用 IPv6，避免 DNS、Docker edge 监听、防火墙和证书续期链路只配置一半导致部分客户端优先访问 IPv6 后失败。
- Docker edge `siye-prod-edge-nginx` 直接占用公网 `0.0.0.0:80` 和 `0.0.0.0:443`；旧的 `18080/18443` 并行端口已关闭。生产业务入口不再经过宿主机 Nginx。
- 宿主机当前预期监听端口只有：`22/tcp`（SSH）、`80/tcp`（Docker edge HTTP）和 `443/tcp`（Docker edge HTTPS）。`sudo ss -nltp` 已确认 `80/443` 的进程为 `docker-proxy`。
- `127.0.0.53:53`、`127.0.0.54:53` 属于 `systemd-resolved` 本地 DNS，仅回环可访问；`127.0.0.1:40349` 属于 `containerd` 的 Docker 运行时内部监听，同样不对公网开放，不应直接停止或删除。
- 腾讯云安全组当前保留 IPv4 TCP `22`、`80`、`443` 和 ICMP Ping。`22` 有固定管理公网 IP 时应收窄来源；没有固定 IP 时先保持可管理性。没有 IPv6 公网入口和 `AAAA` 记录时，不需要开放 IPv6 `80/443`，无实际用途的 IPv6 `443` 规则可以删除。
- 若未来启用 IPv6，必须作为独立变更同时完成实例 IPv6 地址、DNSPod `AAAA` 记录、Docker edge IPv6 `80/443` 监听、腾讯云 IPv6 防火墙规则、HTTPS/SNI 和公网双栈验收；不能只在腾讯云控制台点击“开启 IPv6”。

## 2026-07-22 GitHub Pages 发布与浏览器验收

- `siyeWorld` 手动 GitHub Pages Workflow 已提交并成功用于发布，Pages 地址为 `https://siyesummer.github.io/siyeWorld/#/`；页面静态资源、`/siyeWorld/` 前缀和 hash 路由均能正常加载。
- 浏览器已验证音乐列表和播放界面可用；Network 中对 `https://music-api.siyes.cn` 的歌曲 URL、详情等请求返回 `200 OK`，连接腾讯云服务器的 HTTPS `443` 端口。
- music-api 响应已返回 `Access-Control-Allow-Origin: https://siyesummer.github.io` 和 `Access-Control-Allow-Credentials: true`，证明生产 CORS 白名单正确匹配 Pages Origin；CORS Origin 不包含 `/siyeWorld/` 路径。
- GitHub Pages 上的 Socket.IO 连接、实时聊天、消息保存与历史读取、日志查询均已逐项验收正常；结合前述静态页面、hash 路由和音乐 API 验证，本次 Pages 完整业务链路验收通过。
- 浏览器地址栏截图仍显示“不安全”提示，不能仅凭音乐请求成功判定页面安全状态完全正常；后续如提示持续存在，应优先检查页面信息、Console 中的 Mixed Content，以及歌曲封面、音频等第三方资源是否仍返回 HTTP 地址。

## 2026-07-22 `siyefun.top` 最新前端部署验收

- 阿里云 Windows 的 `siyefun.top` 已部署最新 `siyeWorld` 前端，页面、音乐搜索与播放、Socket.IO、实时聊天、消息保存与历史读取、日志查询均已验收正常。
- 浏览器 Network 已确认页面向 `https://music-api.siyes.cn` 发起请求并获得 `200 OK`；响应的 `Access-Control-Allow-Origin: http://siyefun.top` 与当前页面 Origin 匹配，说明该入口的生产 CORS 配置已经生效。
- 页面已展示 ICP 备案信息。当前访问入口仍为 `http://siyefun.top`，浏览器地址栏显示“不安全”符合未启用站点 HTTPS 的现状；业务 API 使用 HTTPS 不等于顶层页面已经具备 HTTPS。

## 2026-07-22 `siyes.cn` 首页发布验收

- `Docker专题/正式部署/siye-stack/siyes首页/index.html` 已发布到服务器 `/var/www/siyes.cn/index.html`，正式首页标题为 `SIYES`。
- 首页采用单文件、无外部资源依赖的 C 端导航设计，提供三个卡片入口：`https://music.siyes.cn`、`https://knowledge.siyes.cn`、`https://sub2api.siyes.cn`；用户已确认卡片跳转正常。
- 首页页脚保留 `闽ICP备17032186号-3`，链接到 `https://beian.miit.gov.cn/`；`siyes.cn` HTTPS 页面已验证正常。
- 发布前备份位于 `/opt/siye-production/backups/siyes-home-20260722-214507`。发布使用临时文件加原子替换，未重启或重建 `siye-prod-edge-nginx`。
- 发布完成后 `/tmp/siyes-home-index.html` 已清理；后续首页更新继续先上传到 `/tmp`、校验三个域名和备案号、备份当前文件，再原子替换并保留回滚目录。

## 2026-07-22 公网 IP 匿名化约定

- 当前工作树已移除腾讯云和阿里云两台服务器的真实公网 IP；涉及腾讯云服务器的历史命令和演练材料统一使用 RFC 5737 文档专用地址 `203.0.113.10` 代称。该地址不能用于真实连接，实际运维优先使用正式域名或从本机安全配置读取真实地址。
- `siyeWorld` 不再通过阿里云服务器 IP 判断备案展示，改为匹配 `siyefun.top` 和 `www.siyefun.top`，避免业务代码绑定或泄露服务器地址。
- 历史验收记录中的客户端公网 IP 已分别匿名化为 RFC 5737 地址 `192.0.2.10` 和 `192.0.2.11`。后续文档不得记录服务器、开发者或用户的真实公网 IP；`127.0.0.1`、`0.0.0.0`、Docker 内部地址和 RFC 5737 示例地址可以保留。
- 当前文件清理不会自动移除既有 Git 提交中的旧值；如需从远程历史彻底删除，必须单独评估 `git filter-repo`、提交 SHA 变化、分支协作和强制推送风险，未经用户明确确认不得改写历史。

## 2026-07-23 `frontend-knowledge` GitHub Pages 发布验收

- `frontend-knowledge` 已通过仓库根目录 `.github/workflows/deploy-pages.yml` 的 `workflow_dispatch` 手动 Workflow 成功发布到 `https://siyesummer.github.io/frontend-knowledge/#/`。
- 页面已验证正常加载知识目录、中文目录名、暗色主题、代码/YAML 文件查看和 Hash 路由；静态资源使用 `/frontend-knowledge/` 基础路径。
- 该 Pages 站点使用 `md-viewer` 的静态模式：Workflow 构建时生成知识树和文件 JSON，不运行 Express 或 WebSocket，因此不提供本地模式的文件实时刷新。
- 静态生成脚本只读取 Git 已跟踪文件和未被 `.gitignore` 忽略的文件；本地 `.env`、`node_modules`、构建产物和隐藏目录不会进入 Pages 制品。`.env.example` 仅作为示例配置展示。
- 本次提交为 `b60520b`（`feat: organize knowledge base and add Pages deployment`）；后续资料更新后需再次手动运行该 Workflow 才会发布新版本。

## 2026-07-23 `knowledge.siyes.cn` 生产部署准备

- 已确定使用“服务器 Git 工作副本 + 单个 knowledge Docker 容器 + 现有 Docker edge”的正式架构，不把 Vite 开发服务器 `5173` 作为生产入口，也不重新引入宿主机 systemd Node 服务。
- 服务器仓库计划固定为 `/opt/frontend-knowledge`；容器把该目录只读挂载到 `/knowledge`。只更新资料时执行 `git pull --ff-only` 即可由 chokidar 和 WebSocket 通知浏览器，修改 md-viewer 程序或依赖时才需要重建容器。
- `md-viewer/Dockerfile`、`md-viewer/.dockerignore`、`md-viewer/deploy/compose.yml`、`.env.example` 和部署说明已准备。生产容器 `siye-prod-knowledge` 加入外部网络 `siye-prod-edge-net`，不发布宿主机端口，由 Node `3001` 同时提供构建后的前端、`/api/*`、`/ws` 和 `/health`。
- Node 服务支持通过 `KNOWLEDGE_ROOT` 指定知识目录，生产环境才启用 Express 静态 `dist`；本地 `npm run dev` 继续由 Vite `5173` 提供页面、Node `3001` 只提供 API 和 WebSocket。真实 `.env` 已从可读取类型中移除。
- edge 源配置已准备 `knowledge:3001` upstream、普通代理和 `/ws` 长连接代理。当前只是本地待提交配置，服务器尚未启动 knowledge 容器、替换 edge 配置或切换 `knowledge.siyes.cn`，公网现状仍以服务器实际返回为准。
