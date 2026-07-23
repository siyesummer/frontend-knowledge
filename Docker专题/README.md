# Docker专题

这个目录统一存放当前阶段和 Docker / Docker Compose 学习、演练有关的资料。

当前建议阅读顺序：

1. 先看 [Docker命令说明.md](E:/本地项目/frontend-knowledge/Docker专题/Docker命令说明.md)，熟悉常用命令、核心概念和最小实践方式。
2. 再看 [Docker run 与 Docker Compose.md](E:/本地项目/frontend-knowledge/Docker专题/Docker%20run%20与%20Docker%20Compose.md)，理解单容器启动、多容器编排、Docker Hub 发布思路和它们之间的区别。
3. 再看 [Docker运行步骤.md](E:/本地项目/frontend-knowledge/Docker专题/Docker演练/linux-server-mysql/Docker运行步骤.md)，把当前这套 `mysql + linux-server` 组合翻译成纯 `docker run` 方式，理解 Compose 省掉了哪些手工步骤。
4. 再看 [Docker演练步骤.md](E:/本地项目/frontend-knowledge/Docker专题/Docker演练/linux-server-mysql/Docker演练步骤.md)，按照步骤在 Linux 服务器上做第一套隔离式 Docker 演练。
5. 第一套跑通后，再继续看 [easy-chat-linux-server-mysql/Docker演练步骤.md](E:/本地项目/frontend-knowledge/Docker专题/Docker演练/easy-chat-linux-server-mysql/Docker演练步骤.md)，把 `easy-chat` 也纳入 Docker 编排，完成第二套联调演练。
6. 第二套跑通后，看 [music-api/Docker演练步骤.md](E:/本地项目/frontend-knowledge/Docker专题/Docker演练/music-api/Docker演练步骤.md)，独立构建 `music-api` 镜像，并通过宿主机 `3002` 与现有 `systemd` 版本并行验证。
7. 第三套跑通后，看 [nginx-music-api/Docker演练步骤.md](E:/本地项目/frontend-knowledge/Docker专题/Docker演练/nginx-music-api/Docker演练步骤.md)，构建独立 Nginx 镜像，通过宿主机 `8085` 反向代理 Docker `music-api`。
8. 第四套跑通后，看 [nginx-music-api-network/Docker演练步骤.md](E:/本地项目/frontend-knowledge/Docker专题/Docker演练/nginx-music-api-network/Docker演练步骤.md)，把 Nginx 和 music-api 放进同一 Compose，通过 `music-api:3000` 服务名通信。
9. 第五套跑通后，看 [siye-stack/Docker演练步骤.md](E:/本地项目/frontend-knowledge/Docker专题/Docker演练/siye-stack/Docker演练步骤.md)，完成 MySQL、linux-server、easy-chat、music-api 和 Nginx 的统一编排与真实前端联调。
10. 第六套跑通并完成正式镜像发布后，依次按第七套的 [阶段 1](E:/本地项目/frontend-knowledge/Docker专题/Docker演练/siye-release-drill/阶段1-发布演练.md)、[阶段 2](E:/本地项目/frontend-knowledge/Docker专题/Docker演练/siye-release-drill/阶段2-Linux服务与MySQL.md)、[阶段 3](E:/本地项目/frontend-knowledge/Docker专题/Docker演练/siye-release-drill/阶段3-聊天服务.md)、[阶段 4](E:/本地项目/frontend-knowledge/Docker专题/Docker演练/siye-release-drill/阶段4-入口Nginx.md)、[阶段 5](E:/本地项目/frontend-knowledge/Docker专题/Docker演练/siye-release-drill/阶段5-siyeWorld前端.md) 和 [阶段 6](E:/本地项目/frontend-knowledge/Docker专题/Docker演练/siye-release-drill/阶段6-升级与回滚.md) 完成准生产发布演练。
11. 准生产演练暂停后，正式全量 Docker 栈以 [正式部署/siye-stack](E:/本地项目/frontend-knowledge/Docker专题/正式部署/siye-stack/README.md) 为基线；该目录按 `core/sub2api/svg-draw/edge` 拆分 Compose 和 `.env`，首页由 edge 只读挂载现有静态 HTML，并包含 8 个 Host、并行 `18080/18443` 与最终 HTTPS 切流边界。

当前目录结构：

- `Docker命令说明.md`
- `Docker run 与 Docker Compose.md`
- `Docker演练/linux-server-mysql/`
- `Docker演练/easy-chat-linux-server-mysql/`
- `Docker演练/music-api/`
- `Docker演练/nginx-music-api/`
- `Docker演练/nginx-music-api-network/`
- `Docker演练/siye-stack/`
- `Docker演练/siye-release-drill/`
- `正式部署/siye-stack/`

发布链路原理说明：

- [Docker 镜像从构建到运行生效链路](E:/本地项目/frontend-knowledge/Docker专题/Docker镜像从构建到运行生效链路.md)：以 `siye-world:0.0.2` 为例，说明 GitHub Actions、Dockerfile、镜像层、Compose、双层 Nginx、Docker DNS、升级和回滚之间的关系。

当前约定：

- Docker 相关材料统一归档到这个目录下管理。
- 现阶段 Docker 主要用于学习和演练，不直接替换当前已经跑通的 `systemd + 目录部署` 服务。
- 每套 Docker 演练都使用独立端口运行，不能直接替换或停止现有 `systemd + 目录部署` 服务。
- 第三套 `music-api` 演练已经完成本地镜像构建、服务器容器运行和本地前端真实请求验证，使用 `3002 -> 3000`，且不替换现有 systemd 版本。
- 第四套 `nginx + music-api` 演练已完成 Windows 本地和 Linux 服务器验证，使用 `8085 -> 80`，本地前端经 Docker Nginx 请求 Docker music-api 返回 `200`。
- 下一阶段学习共享 Docker 网络与多服务统一 Compose，逐步从 `host.docker.internal` 过渡到容器服务名通信。
- 第五套共享网络演练已完成 Windows 本地和 Linux 服务器构建、内部 DNS、健康检查和反向代理验证，使用 `8086 -> 80`。
- 第六套完整多服务 Compose 演练已完成 Windows 本地、Linux 服务器和本地前端真实联调验证，使用 `app-net` 统一组织 MySQL、linux-server、easy-chat、music-api 和 Nginx，仅发布 `8087 -> 80`，详见 [siye-stack/Docker演练步骤.md](E:/本地项目/frontend-knowledge/Docker专题/Docker演练/siye-stack/Docker演练步骤.md)。
- `music-api:0.0.1` 已完成正式发布；第七套准生产发布演练阶段 1 使用 `siyesummer/music-api:0.0.1`，服务器只拉取镜像并以 `3100 -> 3000` 和现有 systemd 版本并行验证。
- `linux-server:0.0.1` 已完成 GitHub Actions 正式发布；第七套阶段 2 使用 `8181 -> 8081` 与原 systemd Java 链路并行，MySQL 只加入内部 `data-net` 且不映射宿为端口。
- 第七套阶段 2 已完成服务器和本地 `siyeWorld` 真实验证：MySQL、linux-server 和 music-api 均为 `healthy/0`，聊天消息唯一持久且正确记录真实公网 IP，原 systemd `8081` 链路未受影响。
- `easy-chat:0.0.1` 已完成 GitHub Actions 正式发布和第七套阶段 3 真实联调；Docker 版使用 `3130 -> 3030`、仅加入 `edge-net`，四个第七套容器均为 `healthy/0`，聊天广播、Java 持久化、历史刷新和 MySQL 唯一记录均验证通过。
- 第七套阶段 4 edge-nginx 已完成：使用官方固定版本 `nginx:1.27-alpine`、临时入口 `8090 -> 80`，统一代理 `/music-api`、`/socket.io`、`/api`；服务器与 Windows 公网、本地 siyeWorld、CORS、真实消息持久化和日志聚合均验证通过，五个容器全部 `healthy/0`。
- 第七套阶段 5 已完成：`siye-world:0.0.1` 已通过 GitHub Actions 发布并在 Linux 部署，六个容器全部 `healthy/0`；前端 SPA、音乐、Socket.IO、聊天持久化和日志查询均通过 `8090` 完成浏览器真实验收。下一项按阶段 6 文档完成 `siye-world:0.0.1 -> 0.0.2 -> 0.0.1` 的真实升级与回滚。
- 阶段 5 已在 Docker Desktop 使用 DaoCloud Node/Nginx 基础镜像成功构建 `siye-world:local`；临时容器达到 `healthy/0`，`nginx -t`、首页、`/log-query` history 回退及制品地址审计通过，测试容器已删除、本地镜像保留。
- `siyefun.top` 暂不参与阶段 5 上线。后续单独做 Windows 无 Docker 发布演练：使用版本化 dist，新增独立 Nginx 配置文件和测试入口，不修改原 Windows 旧配置；验证和回滚流程完成后再决定正式切换。
- 当前已准备 `yarn build:pages` 与 `.env.pages`：生成 `/siyeWorld/` 资源前缀、hash 路由的 GitHub Pages 制品，并复用 `IP:8090` 演练配置；由于 HTTPS Pages 调用 HTTP 演练接口会触发 Mixed Content，现阶段只做静态与路由验收，暂不创建 Pages 发布 Workflow。
- `svg-draw` 正式 Docker 镜像发布与 GitHub Pages 发布分开：源码仓库的 Pages Workflow 继续负责静态 Pages，新增的 `release-image.yml` 负责 `siyesummer/svg-draw` 多架构镜像、Docker Hub Description、Git Tag 和 GitHub Release。
