# Docker专题

这个目录统一存放当前阶段和 Docker / Docker Compose 学习、演练有关的资料。

当前建议阅读顺序：

1. 先看 [Docker命令说明.md](E:/github项目/frontend-knowledge/Docker专题/Docker命令说明.md)，熟悉常用命令、核心概念和最小实践方式。
2. 再看 [Docker run 与 Docker Compose.md](E:/github项目/frontend-knowledge/Docker专题/Docker%20run%20与%20Docker%20Compose.md)，理解单容器启动、多容器编排、Docker Hub 发布思路和它们之间的区别。
3. 再看 [DOCKER_RUN_STEPS.md](E:/github项目/frontend-knowledge/Docker专题/docker-labs/linux-server-mysql/DOCKER_RUN_STEPS.md)，把当前这套 `mysql + linux-server` 组合翻译成纯 `docker run` 方式，理解 Compose 省掉了哪些手工步骤。
4. 再看 [DOCKER_LAB_STEPS.md](E:/github项目/frontend-knowledge/Docker专题/docker-labs/linux-server-mysql/DOCKER_LAB_STEPS.md)，按照步骤在 Linux 服务器上做第一套隔离式 Docker 演练。
5. 第一套跑通后，再继续看 [easy-chat-linux-server-mysql/DOCKER_LAB_STEPS.md](E:/github项目/frontend-knowledge/Docker专题/docker-labs/easy-chat-linux-server-mysql/DOCKER_LAB_STEPS.md)，把 `easy-chat` 也纳入 Docker 编排，完成第二套联调演练。
6. 第二套跑通后，看 [music-api/DOCKER_LAB_STEPS.md](E:/github项目/frontend-knowledge/Docker专题/docker-labs/music-api/DOCKER_LAB_STEPS.md)，独立构建 `music-api` 镜像，并通过宿主机 `3002` 与现有 `systemd` 版本并行验证。
7. 第三套跑通后，看 [nginx-music-api/DOCKER_LAB_STEPS.md](E:/github项目/frontend-knowledge/Docker专题/docker-labs/nginx-music-api/DOCKER_LAB_STEPS.md)，构建独立 Nginx 镜像，通过宿主机 `8085` 反向代理 Docker `music-api`。
8. 第四套跑通后，看 [nginx-music-api-network/DOCKER_LAB_STEPS.md](E:/github项目/frontend-knowledge/Docker专题/docker-labs/nginx-music-api-network/DOCKER_LAB_STEPS.md)，把 Nginx 和 music-api 放进同一 Compose，通过 `music-api:3000` 服务名通信。

当前目录结构：

- `Docker命令说明.md`
- `Docker run 与 Docker Compose.md`
- `docker-labs/linux-server-mysql/`
- `docker-labs/easy-chat-linux-server-mysql/`
- `docker-labs/music-api/`
- `docker-labs/nginx-music-api/`
- `docker-labs/nginx-music-api-network/`

当前约定：

- Docker 相关材料统一归档到这个目录下管理。
- 现阶段 Docker 主要用于学习和演练，不直接替换当前已经跑通的 `systemd + 目录部署` 服务。
- 每套 Docker 演练都使用独立端口运行，不能直接替换或停止现有 `systemd + 目录部署` 服务。
- 第三套 `music-api` 演练已经完成本地镜像构建、服务器容器运行和本地前端真实请求验证，使用 `3002 -> 3000`，且不替换现有 systemd 版本。
- 第四套 `nginx + music-api` 演练已完成 Windows 本地和 Linux 服务器验证，使用 `8085 -> 80`，本地前端经 Docker Nginx 请求 Docker music-api 返回 `200`。
- 下一阶段学习共享 Docker 网络与多服务统一 Compose，逐步从 `host.docker.internal` 过渡到容器服务名通信。
- 第五套共享网络演练已完成 Windows 本地和 Linux 服务器构建、内部 DNS、健康检查和反向代理验证，使用 `8086 -> 80`。
- 第六套完整多服务 Compose 演练已完成 Windows 本地、Linux 服务器和本地前端真实联调验证，使用 `app-net` 统一组织 MySQL、linux-server、easy-chat、music-api 和 Nginx，仅发布 `8087 -> 80`，详见 [siye-stack/DOCKER_LAB_STEPS.md](E:/本地项目/frontend-knowledge/Docker专题/docker-labs/siye-stack/DOCKER_LAB_STEPS.md)。
- 下一阶段准备把第六套镜像整理为 Docker Hub 发布流程。
