# music-api Docker Compose 演练步骤

## 一、这次演练要完成什么

这是第三套 Docker 演练，目标是把服务器当前通过 `systemd` 运行的 `music-api`，复制出一套相互隔离的 Docker 版本。

两套服务会同时保留：

- 正在使用的 `systemd` 版本：宿主机 `3000`，目录 `/opt/music-api/NeteaseCloudMusicApi-4.13.8`
- 本次 Docker 演练版本：宿主机 `3002` 映射到容器 `3000`

本次不会修改 `/opt/music-api`，也不会重启 `music-api.service`。即使 Docker 演练失败，原来的 `http://YOUR_SERVER_IP:3000` 仍然可以继续使用。

## 二、为什么必须准备完整源码

`music-api` 不是一个只有 `app.js` 的独立脚本。它启动时还会使用：

- `package.json` 和 `package-lock.json`
- `generateConfig.js`
- `server.js`
- `module/`、`plugins/`、`public/`、`static/`、`util/` 等目录

所以 Docker 构建上下文必须包含完整的 `NeteaseCloudMusicApi-4.13.8` 源码。只上传 `app.js` 会在启动时出现 `MODULE_NOT_FOUND`。

本次使用的源码来源是：

```text
E:\本地项目\NeteaseCloudMusicApi-4.13.8
```

它与服务器当前 `/opt/music-api/NeteaseCloudMusicApi-4.13.8` 对应，并且已经包含当前使用的中国本地时间日志改造。

## 三、演练目录最终结构

上传并整理后，服务器目录应该是：

```text
/opt/docker-labs/music-api/
├── .env
├── .env.example
├── Dockerfile
├── docker-compose.yml
├── DOCKER_LAB_STEPS.md
└── NeteaseCloudMusicApi-4.13.8/
    ├── .dockerignore
    ├── app.js
    ├── package.json
    ├── package-lock.json
    ├── server.js
    └── ...
```

这里有两个容易混淆的目录：

- 外层 `music-api/` 是本次 Docker 演练目录，放 Compose 和演练用 Dockerfile。
- 内层 `NeteaseCloudMusicApi-4.13.8/` 是镜像构建所需的应用源码。

源码目录本身也带有原项目的 `Dockerfile`，但本次 Compose 已通过 `dockerfile: ../Dockerfile` 明确指定使用外层演练版 Dockerfile。这样可以保留上游项目文件，同时单独维护我们已经验证过安装逻辑的演练配置。

## 四、Dockerfile 在做什么

当前 Dockerfile 的关键步骤是：

1. `FROM node:20-bookworm-slim`：使用 Node.js 20 的精简 Linux 基础镜像，和服务器当前 Node.js 20 大版本保持一致。
2. `WORKDIR /app`：后续安装和启动都在容器内 `/app` 目录进行。
3. 先复制 `package.json`、`package-lock.json`，再执行 `npm ci`：依赖文件不变时可以复用 Docker 构建缓存。
4. `npm ci --omit=dev --ignore-scripts`：严格按照锁文件安装生产依赖，同时避免 `prepare` 调用未安装的 Husky 开发依赖。
5. `COPY --chown=node:node . .`：把源码复制进镜像，并交给非 root 的 `node` 用户。
6. `CMD ["node", "app.js"]`：容器启动时运行当前已经改造过日志的入口文件。

这里使用 `npm ci` 而不是 `npm install`，是因为项目已有 `package-lock.json`。`npm ci` 更适合可重复构建：锁文件不变时，安装出来的依赖版本也保持一致。

Compose 中还设置了 `init: true`，它会在 Node.js 进程前增加一个很小的 init 进程，帮助正确转发停止信号并回收子进程。这样执行 `docker compose stop` 时，容器内进程的退出行为更规范。

当前 Compose 没有显式编写 `networks`，因为这里只有一个应用容器，不存在容器之间按服务名互相访问的需求。Compose 仍会自动创建名为 `<项目名>_default` 的 bridge 网络；等后续把多个服务放进同一套编排时，再像第二套演练一样显式声明 `app-net`。

当前也没有声明 `volumes`，因为 `music-api` 本身不保存 MySQL 这类持久数据。应用日志由 Docker 日志系统管理，后面会单独说明查看方式。

## 五、本地先做最低限度检查

以下命令在本地 PowerShell 中执行：

```powershell
cd E:\本地项目\NeteaseCloudMusicApi-4.13.8
node --check app.js
npm test
```

命令作用：

- `node --check app.js` 只检查 JavaScript 语法，不会启动服务。
- `npm test` 运行项目已有测试；如果测试依赖外部网易云接口，网络波动可能导致超时，需要结合测试输出判断，不能把网络超时和语法错误混为一谈。

再确认版本与锁文件：

```powershell
node -v
npm -v
Get-Item package.json, package-lock.json, app.js
```

## 六、把演练材料和源码打成一个压缩包

下面命令必须在 PowerShell 中执行，不要在传统的 `cmd` 窗口中执行。PowerShell 的反引号 `` ` `` 表示下一行仍属于同一条命令。

```powershell
tar -czf "$env:TEMP\music-api-docker-lab.tar.gz" `
  --exclude=node_modules `
  --exclude=.git `
  --exclude=.claude `
  -C "E:\github项目\frontend-knowledge\Docker专题\docker-labs" music-api `
  -C "E:\本地项目" NeteaseCloudMusicApi-4.13.8
```

这条命令把两个目录放进同一个压缩包：

- 当前仓库里的 `music-api` Docker 演练模板
- 本地完整的 `NeteaseCloudMusicApi-4.13.8` 源码

`node_modules` 不上传，因为它体积大，并且里面可能包含 Windows 环境相关内容。Linux 容器会在构建镜像时重新安装 Linux 版本依赖。

检查压缩包是否生成，并查看前 30 个文件：

```powershell
Get-Item "$env:TEMP\music-api-docker-lab.tar.gz"
tar -tzf "$env:TEMP\music-api-docker-lab.tar.gz" | Select-Object -First 30
```

列表中应该同时看到：

```text
music-api/docker-compose.yml
music-api/Dockerfile
NeteaseCloudMusicApi-4.13.8/app.js
NeteaseCloudMusicApi-4.13.8/package-lock.json
```

## 七、只输入一次密码上传服务器

仍然在本地 PowerShell 执行，整条命令写在一行即可：

```powershell
scp "$env:TEMP\music-api-docker-lab.tar.gz" ubuntu@YOUR_SERVER_IP:/tmp/
```

这次只上传一个压缩包，因此只需要完成一次 SSH 密码验证。

## 八、服务器解压和整理目录

以下命令在 Linux 服务器执行：

```bash
mkdir -p /tmp/music-api-lab-upload
tar -xzf /tmp/music-api-docker-lab.tar.gz -C /tmp/music-api-lab-upload
mv /tmp/music-api-lab-upload/NeteaseCloudMusicApi-4.13.8 /tmp/music-api-lab-upload/music-api/
```

先检查上传内容，确认源码和配置都在，再替换演练目录：

```bash
find /tmp/music-api-lab-upload/music-api -maxdepth 2 -type f | sort | head -30
test -f /tmp/music-api-lab-upload/music-api/docker-compose.yml
test -f /tmp/music-api-lab-upload/music-api/Dockerfile
test -f /tmp/music-api-lab-upload/music-api/NeteaseCloudMusicApi-4.13.8/app.js
test -f /tmp/music-api-lab-upload/music-api/NeteaseCloudMusicApi-4.13.8/package-lock.json
```

如果四条 `test` 都没有输出，表示文件存在。然后执行：

```bash
sudo mkdir -p /opt/docker-labs
sudo chown ubuntu:ubuntu /opt/docker-labs

if [ -d /opt/docker-labs/music-api ]; then
  mv /opt/docker-labs/music-api "/opt/docker-labs/music-api.bak-$(date +%Y%m%d-%H%M%S)"
fi

mv /tmp/music-api-lab-upload/music-api /opt/docker-labs/music-api
chown -R ubuntu:ubuntu /opt/docker-labs/music-api
```

这里不是直接删除旧目录，而是先带时间戳备份。后续如果新材料有问题，可以停止新容器后把备份目录改回去。

## 九、准备环境变量

在服务器执行：

```bash
cd /opt/docker-labs/music-api
cp .env.example .env
nano .env
```

当前内容保持为：

```env
MUSIC_API_HOST_PORT=3002
CORS_ALLOW_ORIGIN=*
NODE_IMAGE=node:20-bookworm-slim
```

这里的 `3002` 是宿主机端口。容器内服务仍监听 `3000`，Compose 会建立 `3002 -> 3000` 的端口映射。

`CORS_ALLOW_ORIGIN` 会传给 `server.js`，用于设置响应头 `Access-Control-Allow-Origin`：

- 不配置或配置为空时，应用默认使用 `*`，保持当前允许任意来源访问的行为。
- 需要限制来源时，可以改为一个完整来源，例如 `http://YOUR_SERVER_IP:8083`。
- 浏览器的 `Access-Control-Allow-Origin` 不支持用逗号拼接多个来源；后续需要白名单时，应在服务端根据请求的 `Origin` 动态匹配，不能直接写成 `https://a.example.com,https://b.example.com`。

本次演练先保留：

```env
CORS_ALLOW_ORIGIN=*
```

`NODE_IMAGE` 默认使用 Docker Hub 的官方镜像。如果当前网络访问 Docker Hub 的授权域名超时，可以先测试国内镜像代理：

```powershell
docker pull docker.m.daocloud.io/library/node:20-bookworm-slim
```

确认拉取成功后，把 `.env` 临时改为：

```env
NODE_IMAGE=docker.m.daocloud.io/library/node:20-bookworm-slim
```

这是构建基础镜像来源的配置，不会改变应用代码，也不会影响容器内 Node.js 的版本。

启动前确认端口没有被占用：

```bash
sudo ss -lntp | grep ':3002 ' || true
```

没有输出才表示当前没有进程监听 `3002`。如果有输出，先查清占用者，不要直接停止不认识的服务。

## 十、启动前先验证 Compose 配置

```bash
cd /opt/docker-labs/music-api
docker compose config
```

这个命令不会启动容器，它会：

- 读取当前目录的 `docker-compose.yml`
- 自动读取当前目录的 `.env`
- 替换 `${MUSIC_API_HOST_PORT}` 和 `${CORS_ALLOW_ORIGIN}`
- 检查 YAML 和 Compose 配置是否能被解析

重点确认最终端口显示为 `3002:3000`，构建上下文指向 `NeteaseCloudMusicApi-4.13.8`。

## 十一、在 Windows 本地构建镜像

如果只是想先在本地验证镜像构建，可以在 PowerShell 执行：

```powershell
docker build --progress plain `
  --build-arg NODE_IMAGE=docker.m.daocloud.io/library/node:20-bookworm-slim `
  -f E:\github项目\frontend-knowledge\Docker专题\docker-labs\music-api\Dockerfile `
  -t siye-music-api:4.13.8 `
  E:\本地项目\NeteaseCloudMusicApi-4.13.8
```

这里最后一个路径是 Docker 构建上下文，必须指向完整的 NeteaseCloudMusicApi 源码目录。`-f` 指定的是本次演练使用的 Dockerfile，`-t` 为生成的本地镜像命名。

如果本地 Docker Hub 网络已经恢复，可以去掉 `--build-arg NODE_IMAGE=...`，使用 Dockerfile 默认的官方镜像。

## 十二、在 Linux 服务器使用 Compose 构建并启动

```bash
cd /opt/docker-labs/music-api
docker compose up -d --build
docker compose ps
```

这条 `up -d --build` 会依次完成：

1. Compose 读取 `.env` 和 `docker-compose.yml`。
2. Docker 读取 `NeteaseCloudMusicApi-4.13.8/.dockerignore`，排除不需要发送到构建引擎的文件。
3. Docker 根据外层 `Dockerfile` 拉取 Node.js 20 基础镜像。
4. 镜像内执行 `npm ci`，安装 Linux 生产依赖。
5. 源码被复制进镜像，生成本次 `music-api` 镜像。
6. 创建并启动名为 `lab3-music-api` 的容器。
7. 把宿主机 `3002` 映射到容器 `3000`。
8. 后台健康检查通过 TCP 连接确认容器内 `3000` 已经监听。

第一次构建需要拉基础镜像和安装依赖，通常比后续构建慢。

## 十三、分层验证，不要只看容器显示 Up

### 1. 查看启动日志

```bash
docker compose logs --tail=100 music-api
```

应该看到 `music-api` 的启动日志，并且没有持续重启或 `MODULE_NOT_FOUND`。

### 2. 查看健康状态

```bash
docker compose ps
docker inspect --format '{{.State.Status}} {{.State.Health.Status}} {{.RestartCount}}' lab3-music-api
```

期望结果是：

```text
running healthy 0
```

### 3. 在服务器本机请求真实接口

```bash
curl --fail --max-time 30 "http://127.0.0.1:3002/search?keywords=test&limit=1&type=1"
```

这一步验证的不只是端口监听，还包括 Express 路由、项目模块和外部音乐接口调用。

### 4. 确认原 systemd 服务仍可用

```bash
systemctl is-active music-api
curl --fail --max-time 30 "http://127.0.0.1:3000/search?keywords=test&limit=1&type=1"
```

Docker 版成功不等于可以忽略原服务；本次演练要求两个入口都可用。

### 5. 从本地电脑访问 Docker 版

本地 PowerShell 执行：

```powershell
curl.exe --fail --max-time 30 "http://YOUR_SERVER_IP:3002/search?keywords=test&limit=1&type=1"
```

如果服务器本机 `127.0.0.1:3002` 成功，但公网 IP 失败，优先检查腾讯云安全组和服务器防火墙是否允许 TCP `3002`，不要先怀疑容器代码。

## 十四、本地前端联调

需要联调时，只把本地前端音乐 API 基地址临时切换为：

```text
http://YOUR_SERVER_IP:3002
```

联调完成后切回当前主测试入口：

```text
http://YOUR_SERVER_IP:3000
```

本次不修改 `music-api.siyes.cn` 的 Nginx 反向代理目标。域名入口继续指向已经验证过的 `systemd` 版本，避免 Docker 学习过程影响现有链路。

## 十五、日志在哪里看

Docker 版 `music-api` 的标准输出默认由 Docker 管理：

```bash
cd /opt/docker-labs/music-api
docker compose logs -f --tail=100 music-api
```

当前 `/var/log/siye/music-api.log` 仍然是 `systemd` 版本的日志。Docker 版日志不会自动写入这个文件，因此当前 `linux-server` 日志查询页也不会自动显示 Docker 版请求。

这是两套运行方式的日志边界，不是日志丢失。后续学习集中式日志时，再考虑统一采集 Docker 和 systemd 日志。

## 十六、常用排查命令

```bash
cd /opt/docker-labs/music-api
docker compose ps
docker compose logs --tail=200 music-api
docker compose images
docker inspect lab3-music-api
docker stats lab3-music-api
```

如果修改了 `app.js`、`package-lock.json` 或 Dockerfile，需要重新构建：

```bash
docker compose up -d --build --force-recreate
docker compose ps
```

`restart` 只会重新启动旧容器，不会把修改后的宿主机源码复制进已有镜像，所以源码变化后不能只执行 `docker compose restart`。

## 十七、停止、恢复和清理

只停止容器，保留容器和镜像：

```bash
docker compose stop
```

重新启动已停止的容器：

```bash
docker compose start
```

删除当前 Compose 创建的容器和网络，保留镜像：

```bash
docker compose down
```

再次创建：

```bash
docker compose up -d
```

这套 `music-api` 没有数据库卷，因此不存在 `down -v` 删除业务数据的问题。不过仍然不建议养成随手加 `-v` 的习惯，因为在包含 MySQL 的 Compose 项目里，它会删除数据卷。

## 十八、完成标准

只有下面各项都满足，才把第三套演练记为完成：

- `docker compose config` 通过
- `lab3-music-api` 为 `running healthy`，重启次数为 `0`
- 服务器本机 `127.0.0.1:3002/search` 返回成功
- 本地电脑 `YOUR_SERVER_IP:3002/search` 返回成功
- 本地前端切到 `3002` 后可以完成一次真实搜索
- 原 `music-api.service` 仍为 `active`
- 原 `127.0.0.1:3000/search` 仍返回成功

完成后再把实际验证结果同步到 `AGENTS.md`，不要在真实验证前写成“已完成”。

## 十九、实际验证记录

2026-07-14 已完成以下验证：

- Windows Docker Desktop 本地构建 `siye-music-api:4.13.8` 成功。
- Linux 服务器部署目录为 `/opt/docker-labs/music-api`。
- 容器名为 `lab3-music-api`，状态为 `running`，重启次数为 `0`。
- 服务器端口映射为 `3002 -> 3000`，现有 systemd 版本继续使用宿主机 `3000`。
- 容器启动日志时间为中国本地时间，启动流程无报错。
- 本地 `siyeWorld` 通过 `http://YOUR_SERVER_IP:3002/search` 请求返回 `200 OK`。
- 浏览器响应头包含 `Access-Control-Allow-Origin: *`，CORS 配置生效。
