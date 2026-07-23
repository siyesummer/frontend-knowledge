# Docker 镜像从构建到运行生效链路

## 一、这篇文档解决什么问题

本文结合 `siye-world:0.0.2` 的真实发布与升级，说明下面这条链路为什么能够工作：

```text
修改 Dockerfile 和 Nginx 配置
  -> GitHub Actions 构建镜像
  -> Docker Hub 保存镜像
  -> Linux 拉取新版本
  -> Docker Compose 重建 siye-world
  -> 重建 edge-nginx
  -> 浏览器访问到新文件和新配置
```

本文默认读者以自己的前端开发经验为基础，正在学习 Docker、Linux、Nginx、CI/CD 和发布运维。

本次更新的服务是 Docker 中的 `siye-world`，不是 `siye-music`，也不是 systemd 的 `music-api.service`。备案和域名审核阶段，现有 systemd Linux 服务及配置始终保持不变。

## 二、先建立整体分层

```text
Git 源码仓库
  决定将要发布的代码和构建规则
        |
        v
GitHub Actions
  计算版本、执行校验、调用 Docker 构建
        |
        v
Dockerfile
  把前端 dist、Nginx 配置和版本文件制作成镜像
        |
        v
Docker Hub
  保存带版本标签和 digest 的不可变镜像制品
        |
        v
Linux .env + Docker Compose
  决定服务器运行哪个镜像版本
        |
        v
siye-world 容器
  使用镜像内的 Nginx 提供静态页面和 release.json
        |
        v
edge-nginx 容器
  通过统一入口把浏览器请求转发给 siye-world
        |
        v
浏览器
  看到最终运行容器提供的页面和版本信息
```

每一层的职责不同。只完成其中一层，不代表新版本已经上线。

## 三、从前端工程的视角理解镜像和容器

可以先用熟悉的前端概念做类比：

| Docker 概念 | 类似的前端概念 | 说明 |
| --- | --- | --- |
| 源码 | Vue 项目源码 | 可以继续修改，还不是发布制品 |
| `yarn build` 生成的 `dist` | 前端静态制品 | 已编译，但还没有完整运行环境 |
| Dockerfile | 自动化打包说明 | 规定怎样把 dist、Nginx 和配置放进发布包 |
| Docker 镜像 | 不可变版本化发布包 | 同时包含静态文件、Nginx 和启动规则 |
| Docker 容器 | 发布包的运行实例 | 真正对外提供服务的进程和文件系统 |
| Docker Hub | 制品仓库/CDN | 保存并分发不同版本镜像 |
| Compose `.env` | 部署环境的版本清单 | 决定服务器使用哪个镜像标签 |

镜像和容器最容易混淆：

```text
镜像：静态模板，不运行
容器：根据镜像创建的运行实例
```

服务器拉取新镜像后，旧容器不会自动变成新版本。必须重新创建容器，才能使用新镜像中的文件。

## 四、GitHub Actions 如何产生 0.0.2

`Release siye-world image` Workflow 先读取已有 Tag：

```text
siye-world-image-v0.0.1
```

选择 `patch` 后计算：

```text
0.0.1 -> 0.0.2
```

Workflow 再把版本和源码提交传给 Docker 构建：

```yaml
build-args: |
  APP_VERSION=${{ steps.version.outputs.version }}
  APP_REVISION=${{ github.sha }}
```

本次实际值为：

```text
APP_VERSION=0.0.2
APP_REVISION=0b0c4932ea21fcedc2139f5e89679a27fee5cd20
```

这里的 `${{ ... }}` 由 GitHub Actions 在运行 Workflow 时替换，不是在 Linux 服务器上解析。

## 五、Dockerfile 在什么时候执行

Dockerfile 只在构建镜像时执行。本次构建发生在 GitHub Actions；本地验证时也曾由 Docker Desktop 执行。

Linux 正式部署只执行 `docker pull`，不执行 Dockerfile，也不重新编译前端。

### 1. 多阶段构建

`siye-world` Dockerfile 包含两个阶段：

```text
builder 阶段
  Node.js + yarn build -> /app/dist

最终阶段
  Nginx + dist + default.conf + release.json
```

builder 阶段只负责安装依赖和构建 Vue。最终镜像不需要保留 Node.js、源码和完整依赖，因此镜像更小、职责更清晰。

### 2. ARG 是构建时参数

```dockerfile
ARG APP_VERSION=dev
ARG APP_REVISION=unknown
```

`ARG` 只在 `docker build` 过程中存在。它和容器运行时的 `environment:`、`.env` 不是一回事。

如果 Workflow 不传值，本地构建会使用：

```text
APP_VERSION=dev
APP_REVISION=unknown
```

正式 Workflow 会覆盖为真实版本和 commit。

### 3. LABEL 写入镜像元数据

```dockerfile
LABEL org.opencontainers.image.title="siye-world" \
    org.opencontainers.image.version="${APP_VERSION}" \
    org.opencontainers.image.revision="${APP_REVISION}"
```

这部分不会创建网页文件，而是写入镜像 OCI Metadata，可以通过下面的命令读取：

```bash
docker image inspect siyesummer/siye-world:0.0.2
```

本次镜像标签为：

```text
org.opencontainers.image.version=0.0.2
org.opencontainers.image.revision=0b0c4932ea21fcedc2139f5e89679a27fee5cd20
```

### 4. COPY 把文件放进镜像

```dockerfile
COPY deploy/siye-world/default.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist /usr/share/nginx/html
```

第一条把前端容器自己的 Nginx 配置放进镜像。

第二条把 builder 阶段生成的 Vue `dist` 放到 Nginx 静态目录。

这两个文件来源都在 Git 仓库中。只有重新构建镜像，修改后的内容才会进入新镜像。

### 5. RUN 在镜像层中生成 release.json

```dockerfile
RUN printf '{"service":"siye-world","version":"%s","revision":"%s"}\n' \
    "$APP_VERSION" \
    "$APP_REVISION" \
    > /usr/share/nginx/html/release.json
```

这条命令也在镜像构建阶段执行。生成的文件被保存到镜像层：

```text
/usr/share/nginx/html/release.json
```

文件不是在 Linux 宿主机生成的，也不是容器启动时临时生成的。它随镜像一起推送和拉取。

本次内容为：

```json
{"service":"siye-world","version":"0.0.2","revision":"0b0c4932ea21fcedc2139f5e89679a27fee5cd20"}
```

## 六、镜像层为什么能把文件带到 Linux

Docker 构建会把 Dockerfile 中每个有效步骤转化为镜像层。可以简化理解为：

```text
Nginx 基础镜像层
  + default.conf 配置层
  + Vue dist 文件层
  + release.json 文件层
  = siye-world:0.0.2
```

GitHub Actions 把这些镜像层推送到 Docker Hub。Linux 执行：

```bash
docker pull siyesummer/siye-world:0.0.2
```

Docker 会下载并校验这些层，在本机恢复同一个镜像。因此不需要把 `release.json` 单独上传到服务器。

镜像的 digest 是内容寻址标识。本次 `0.0.2` 的 Linux amd64 digest 为：

```text
sha256:6ba3a44ba6f939f6aaffdebab8633b1983111f6221720472c4b5a2fb44aa6c43
```

它与 `0.0.1` 的 digest 不同，证明不是给同一镜像换了一个标签。

## 七、为什么 docker pull 后旧页面不会自动变化

`docker pull` 只把镜像下载到服务器：

```text
本地镜像列表：同时存在 0.0.1 和 0.0.2
运行容器：仍然根据 0.0.1 创建
```

这也是为什么拉取 `0.0.2` 后检查运行容器，仍然看到：

```text
image=siyesummer/siye-world:0.0.1
```

必须修改演练目录 `.env`：

```dotenv
SIYE_WORLD_IMAGE=siyesummer/siye-world:0.0.2
```

然后重新创建目标容器：

```bash
docker compose \
  --env-file .env \
  -f compose.release-drill.yml \
  up -d \
  --no-build \
  --pull never \
  --no-deps \
  --force-recreate \
  siye-world
```

参数含义：

| 参数 | 作用 |
| --- | --- |
| `--no-build` | Linux 不执行 Dockerfile，不现场构建源码 |
| `--pull never` | 使用已经确认过的本地固定版本镜像 |
| `--no-deps` | 不操作 MySQL、后端和其他依赖服务 |
| `--force-recreate` | 删除旧容器并按当前镜像重新创建 |
| `siye-world` | 只操作前端 Docker 服务 |

新容器的根文件系统来自 `0.0.2` 镜像，所以容器启动后自然包含 `release.json` 和新的 `default.conf`。

## 八、为什么 Nginx 配置生效了

本套环境中存在两个 Nginx，它们不是同一个容器。

### 1. siye-world 内部 Nginx

来源：

```text
E:\本地项目\siyeWorld\deploy\siye-world\default.conf
```

进入镜像的位置：

```text
/etc/nginx/conf.d/default.conf
```

职责：

- 提供 Vue 静态资源
- 提供 `/health`
- 提供 `/release.json`
- 为 Vue Router history 模式提供 SPA 回退

`release.json` 的配置是：

```nginx
location = /release.json {
    access_log off;
    add_header Cache-Control "no-store" always;
    try_files $uri =404;
}
```

含义：

- `location =`：只精确匹配 `/release.json`
- `try_files $uri =404`：文件必须真实存在，不存在就返回 404
- `Cache-Control: no-store`：浏览器和代理不能缓存旧版本信息
- 精确路由优先于下面的 `location /`，不会错误回退到 `index.html`

前端容器被重建后，新 Nginx 进程启动并读取镜像内的新配置，因此配置生效。

### 2. edge-nginx 网关

来源：

```text
/opt/docker-labs/siye-release-drill/nginx/edge.conf
```

它通过 Compose 只读挂载进网关容器：

```yaml
volumes:
  - ./nginx/edge.conf:/etc/nginx/conf.d/default.conf:ro
```

职责：

```text
/                  -> siye-world:80
/music-api/*       -> music-api:3000
/socket.io/*       -> easy-chat:3030
/api/*             -> linux-server:8081
```

它不直接保存 Vue `dist`，也不生成 `release.json`，只负责统一入口和反向代理。

## 九、浏览器访问 release.json 的真实路径

浏览器请求：

```text
http://203.0.113.10:8090/release.json
```

实际链路：

```text
浏览器
  -> 腾讯云安全组和宿主机 8090
  -> drill7-edge-nginx:80
  -> edge.conf 的 location /
  -> Docker DNS 服务名 siye-world:80
  -> drill7-siye-world 内部 Nginx
  -> default.conf 的 location = /release.json
  -> /usr/share/nginx/html/release.json
  -> 返回版本 JSON
```

浏览器最终看到 `0.0.2`，证明上面每一环都使用了新版本。

## 十、为什么重建 siye-world 后还要重建 edge-nginx

Docker Compose 网络为容器提供服务名 DNS：

```text
siye-world -> 当前前端容器 IP
```

但是 Nginx 使用静态 `proxy_pass http://siye-world:80` 时，通常在启动或重新加载配置时解析服务名，并继续使用解析到的地址。

重建 `siye-world` 后，容器 IP 可能变化：

```text
旧 siye-world -> 172.25.0.6
新 siye-world -> 172.25.0.x
```

如果 edge-nginx 仍缓存旧 IP，请求就会出现：

```text
502 Bad Gateway
connect() failed while connecting to upstream
```

阶段 5 已真实遇到该问题。当时三个后端容器都健康，但 edge-nginx 仍连接重建前的旧 IP。

正确顺序是：

```text
1. 重建目标容器
2. 等待目标容器 healthy
3. 从容器网络直接验证目标服务
4. 只重建 edge-nginx
5. 验证统一入口
```

网关命令：

```bash
docker compose \
  --env-file .env \
  -f compose.release-drill.yml \
  up -d \
  --no-build \
  --pull never \
  --no-deps \
  --force-recreate \
  edge-nginx
```

重建后，新的 Nginx 进程重新读取配置并重新解析 Docker DNS，因此能够连接新前端容器。

## 十一、不同配置怎样才能生效

| 修改内容 | 是否需要重新构建镜像 | 是否需要重建容器 | 说明 |
| --- | --- | --- | --- |
| Vue 源码 | 是 | 是 | 先生成新 dist，再进入新镜像 |
| `.env.production` 中的 `VUE_APP_*` | 是 | 是 | 值在前端构建时编译进 JavaScript |
| siye-world Dockerfile | 是 | 是 | Dockerfile 只在镜像构建时执行 |
| siye-world `default.conf` | 是 | 是 | 该配置通过 `COPY` 进入镜像 |
| `APP_VERSION/APP_REVISION` | 是 | 是 | 属于构建参数，写入镜像标签和文件 |
| Compose `.env` 中的镜像版本 | 否 | 是 | 只决定用哪个已有镜像创建容器 |
| 宿主机挂载的 `edge.conf` | 否 | 需要 reload 或重建网关 | 文件在宿主机，Nginx 进程不会自动重新读取 |
| systemd 服务或配置 | 不属于 Docker 演练 | 禁止操作 | 备案审核期间属于不可变保护对象 |

最常见的误区是把“文件已经修改”误认为“运行进程已经使用新文件”。是否生效取决于文件属于源码、镜像、挂载配置还是运行时环境。

## 十二、镜像文件与容器可写层

容器文件系统可以简化成：

```text
只读镜像层
  + 容器自己的可写层
  + 可选 Volume/Bind Mount
```

`release.json` 位于只读镜像层：

- 删除容器后，容器实例消失
- 镜像仍保留时，重新创建容器仍会得到同一个文件
- 切换回 `0.0.1` 后，该旧镜像没有 `release.json`
- 它不属于 MySQL Volume，也不会影响数据库持久化

如果在运行容器内手工修改该文件，修改只存在于当前容器可写层，重建容器后会丢失。因此正式修改必须回到 Dockerfile，重新发布新版本。

## 十三、升级与回滚为什么只改镜像版本

升级：

```dotenv
SIYE_WORLD_IMAGE=siyesummer/siye-world:0.0.2
```

回滚：

```dotenv
SIYE_WORLD_IMAGE=siyesummer/siye-world:0.0.1
```

然后分别重建：

```text
siye-world -> 等待 healthy -> edge-nginx
```

由于镜像标签被冻结，`0.0.1` 和 `0.0.2` 都是可追溯的发布制品。回滚不是把新镜像中的文件手工删除，而是重新用旧镜像创建容器。

本次前端是无状态服务，回滚不会修改 MySQL Volume。阶段 6 还会验证：在 `0.0.2` 期间写入的聊天消息，回滚到 `0.0.1` 后仍然存在且只有一条。

## 十四、常见误区

### 误区 1：Dockerfile 在容器启动时执行

错误。Dockerfile 在 `docker build` 时执行；容器启动只运行镜像配置的入口程序。

### 误区 2：docker pull 会自动更新正在运行的容器

错误。pull 只下载镜像，旧容器仍然使用创建它时的旧镜像。

### 误区 3：修改 Compose `.env` 后容器自动变化

错误。Compose 需要再次执行 `up`，必要时使用 `--force-recreate`。

### 误区 4：两个 Nginx 使用同一份配置

错误。`siye-world` 使用镜像内的 `default.conf`，edge-nginx 使用宿主机只读挂载的 `edge.conf`。

### 误区 5：502 说明新前端容器没有启动

不一定。目标容器可能健康，但网关仍缓存旧容器 IP。应先检查目标容器直连和 Docker 网络，再刷新网关。

### 误区 6：可以通过修改 systemd 解决 Docker 演练问题

错误。两条链路必须并行隔离。Docker 故障只能修复或回滚 Docker 环境，不能修改稳定的 systemd 主链路来迁就演练。

## 十五、本次 0.0.2 的完整证据

```text
源码 commit：0b0c4932ea21fcedc2139f5e89679a27fee5cd20
镜像标签：siyesummer/siye-world:0.0.2
镜像 digest：sha256:6ba3a44ba6f939f6aaffdebab8633b1983111f6221720472c4b5a2fb44aa6c43
容器状态：running / healthy / RestartCount=0
版本接口：/release.json -> version=0.0.2
缓存策略：Cache-Control: no-store
统一入口：http://203.0.113.10:8090
```

这组证据同时证明了源码、Workflow、Dockerfile、Docker Hub、Linux 镜像、运行容器、Nginx 代理和浏览器链路已经对齐。

## 十六、推荐排查顺序

遇到发布问题时，按层排查：

```text
1. Git commit 是否正确
2. GitHub Actions 是否成功
3. Docker Hub 标签和 digest 是否存在
4. Linux 是否 pull 到正确镜像
5. Compose config 是否解析出正确版本
6. 容器 .Config.Image 和 .Image 是否正确
7. 容器是否 healthy/0
8. 容器内部文件和接口是否正确
9. edge-nginx 是否解析到新容器
10. 服务器本机统一入口是否成功
11. 浏览器真实请求和 CORS 是否成功
```

不要一看到浏览器错误就直接修改最底层服务。先确认错误发生在哪一层，再操作该层对应的制品或容器。

## 十七、Dockerfile 完整说明

当前 `siye-world` Dockerfile 可以按下面的结构理解：

```dockerfile
# 允许本地构建时替换基础镜像，GitHub Actions 使用默认值或明确的构建环境
ARG NODE_IMAGE=node:20-bookworm-slim
ARG NGINX_IMAGE=nginx:1.27-alpine

# ---------- builder 阶段 ----------
# BUILDPLATFORM 表示构建工具运行的平台，便于 Buildx 做多架构构建
FROM --platform=$BUILDPLATFORM ${NODE_IMAGE} AS builder

WORKDIR /app

# 先复制依赖清单，让 Docker 能缓存 yarn install 层
COPY package.json yarn.lock ./
COPY packages/siye-core/package.json packages/siye-core/package.json
COPY packages/siye-music/package.json packages/siye-music/package.json
COPY packages/easy-chat/package.json packages/easy-chat/package.json

# 国内本地构建使用淘宝镜像下载依赖
RUN yarn config set registry https://registry.npmmirror.com \
    && yarn install --frozen-lockfile --network-timeout 600000 --network-concurrency 4

# 复制构建配置、生产环境文件和源码
COPY babel.config.js prettier.config.js vue.config.js .eslintrc.js ./
COPY .env.production ./
COPY public ./public
COPY src ./src
COPY packages ./packages

# 使用 .env.production 构建 Vue dist
RUN yarn build

# ---------- final 阶段 ----------
# 这里重新 FROM Nginx，意味着最终镜像从一个全新的文件系统开始
FROM ${NGINX_IMAGE}

# 版本参数只在构建阶段可用
ARG APP_VERSION=dev
ARG APP_REVISION=unknown

# 把版本和源码 commit 写入镜像元数据
LABEL org.opencontainers.image.title="siye-world" \
    org.opencontainers.image.version="${APP_VERSION}" \
    org.opencontainers.image.revision="${APP_REVISION}"

# 复制最终容器需要的 Nginx 配置
COPY deploy/siye-world/default.conf /etc/nginx/conf.d/default.conf

# 只从 builder 阶段复制编译后的前端制品
COPY --from=builder /app/dist /usr/share/nginx/html

# 生成可查询的版本文件
RUN printf '{"service":"siye-world","version":"%s","revision":"%s"}\n' \
    "$APP_VERSION" \
    "$APP_REVISION" \
    > /usr/share/nginx/html/release.json

EXPOSE 80

# 容器健康检查，不等于业务接口的完整验收
HEALTHCHECK --interval=10s --timeout=5s --retries=10 --start-period=10s \
  CMD wget -q -O /dev/null http://127.0.0.1/health || exit 1
```

### 1. 最前面的 `ARG`

```dockerfile
ARG NODE_IMAGE=node:20-bookworm-slim
ARG NGINX_IMAGE=nginx:1.27-alpine
```

这是 Dockerfile 的构建参数，允许构建者替换 Node.js 和 Nginx 基础镜像。例如国内本地构建时使用：

```powershell
docker build `
  --build-arg NODE_IMAGE=docker.m.daocloud.io/library/node:20-bookworm-slim `
  --build-arg NGINX_IMAGE=docker.m.daocloud.io/library/nginx:1.27-alpine `
  -f deploy/siye-world/Dockerfile `
  -t siye-world:local .
```

它们只影响构建时使用的基础镜像，不会成为前端浏览器能够读取的配置。

### 2. `FROM ... AS builder`

```dockerfile
FROM --platform=$BUILDPLATFORM ${NODE_IMAGE} AS builder
```

这条指令创建名为 `builder` 的第一阶段。这个阶段拥有：

- Node.js
- Yarn
- `package.json` 和 `yarn.lock`
- `node_modules`
- Vue 源码
- 构建配置
- 生产环境文件

它的唯一任务是运行：

```bash
yarn build
```

并得到：

```text
/app/dist
```

`AS builder` 是一个阶段名称，后面的 `COPY --from=builder` 会通过这个名字引用它。

### 3. 为什么先复制 package.json

Docker 会按指令生成缓存层。如果源码没有变化，但依赖清单没有变化，下面这层可以复用：

```dockerfile
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile ...
```

只有依赖清单改变时才需要重新安装依赖。这样可以缩短本地构建和 GitHub Actions 构建时间。

这只是构建缓存优化，不代表 `package.json` 会进入最终镜像。

### 4. `COPY .env.production ./`

这个文件会被 builder 阶段的 Vue CLI 读取。比如当前演练地址：

```dotenv
VUE_APP_MUSIC_API_BASE_URL=http://203.0.113.10:8090/music-api
```

构建完成后，这些 `VUE_APP_*` 值会被编译进浏览器 JavaScript。容器启动时并不会重新读取 `.env.production`。

因此修改前端 API 地址时，必须重新构建并发布新的前端镜像，不能只在 Linux 上修改服务器 `.env` 来改变已经编译的浏览器地址。

### 5. `COPY public`、`COPY src`、`COPY packages`

这些命令把前端构建所需的源码和静态资源复制到 `builder` 阶段：

```dockerfile
COPY public ./public
COPY src ./src
COPY packages ./packages
```

它们只服务于 `yarn build`。是否进入最终镜像，取决于 final 阶段有没有再次 `COPY` 它们；当前 final 阶段没有这样做。

### 6. `RUN yarn build`

这一步通常会生成：

```text
dist/
  index.html
  css/*.css
  js/*.js
  static/*
```

这已经是浏览器可以加载的静态制品，不再需要 Node.js、Yarn 或 Vue CLI。

## 十八、为什么源码没有进入最终镜像

关键原因是多阶段构建的这两行：

```dockerfile
FROM ${NGINX_IMAGE}
COPY --from=builder /app/dist /usr/share/nginx/html
```

第二个 `FROM` 会开始一个新的 final 阶段。它不会自动继承 builder 阶段的文件系统，只会从 Nginx 基础镜像开始。

### 1. `FROM` 是否会“重置”最终产物

不应该简单理解为“只要出现 `FROM`，最终镜像就被清空”。更准确的规则是：

> 每个 `FROM` 都会开始一个新的构建阶段，这个阶段以 `FROM` 指定的镜像或前一个阶段为基础。

例如：

```dockerfile
FROM node:20 AS builder
RUN npm run build

FROM nginx:1.27-alpine
```

第二个阶段使用一个独立的 Nginx 基础镜像，因此看起来像“重置”：

- 文件系统从 Nginx 镜像开始
- Node.js、npm、`/app` 和 `node_modules` 不会自动继承
- builder 的 `ENV`、`WORKDIR`、`USER`、`CMD` 和 `ENTRYPOINT` 也不会自动传递
- Nginx 基础镜像自己的文件和启动配置会成为新阶段的基础

但是 builder 阶段并没有被删除。后续仍然可以显式读取它：

```dockerfile
COPY --from=builder /app/dist /usr/share/nginx/html
```

这行只把 builder 中的 `/app/dist` 复制到 Nginx 阶段。

如果 `FROM` 指向前面已经命名的阶段，结果就不同：

```dockerfile
FROM node:20 AS builder
RUN npm install

FROM builder AS final
```

这里的 final 阶段会继承 builder 的完整文件系统，因为它明确以 builder 为基础，并不是从另一个独立镜像重新开始。

还可以使用完全空白的基础：

```dockerfile
FROM scratch
```

`scratch` 表示空文件系统，常用于只需要复制一个静态二进制文件的极简镜像。

可以用下表区分：

| 写法 | 新阶段的起点 |
| --- | --- |
| `FROM nginx:1.27-alpine` | Nginx 基础镜像，与之前的 Node 阶段相互独立 |
| `FROM builder` | 前面名为 builder 的完整阶段 |
| `FROM scratch` | 完全空白的文件系统 |

Docker 默认把 Dockerfile 的最后一个阶段作为最终镜像，但也可以在构建时指定其他阶段：

```bash
docker build --target builder -t siye-world:builder-test .
```

因此，更严谨的结论是：

```text
FROM 会开始新的阶段
是否像“重置”取决于它使用独立基础镜像、前一个阶段还是 scratch
默认最终产物是最后阶段，也可以通过 --target 指定其他阶段
```

最终阶段明确复制的只有：

```text
deploy/siye-world/default.conf
/app/dist
release.json（由 RUN 生成）
```

因此以下内容不会进入最终镜像：

```text
/app/src
/app/packages
/app/public 的构建中间文件
/app/node_modules
/app/package.json
/app/yarn.lock
/app/.env.production
Node.js
Yarn
Vue CLI
eslint、webpack 和构建缓存
```

### 2. Docker 不会自动复制前一阶段的全部文件

下面这种写法是显式复制：

```dockerfile
COPY --from=builder /app/dist /usr/share/nginx/html
```

它只复制 `/app/dist`。Docker 不会因为 builder 阶段存在 `/app/src`，就自动把 `/app/src` 一起复制到 final 阶段。

如果改成：

```dockerfile
COPY --from=builder /app /app
```

那才会把整个 `/app` 复制进最终镜像，源码和 `node_modules` 也可能被带进去。这会增大镜像并暴露不必要的内容，不适合当前静态前端运行方式。

### 3. final 镜像只需要 Nginx 和静态文件

前端在生产环境的运行模式是：

```text
浏览器请求静态文件
  -> Nginx 读取 /usr/share/nginx/html
  -> 返回 index.html、JS、CSS、图片和 release.json
```

生产环境不需要：

- 编译 Vue
- 安装依赖
- 执行 Yarn
- 运行 Node.js 开发服务器
- 读取源码重新构建

所以 final 阶段使用 Nginx，而不是 Node.js。

### 4. 源码没有进入镜像不代表源码没有影响镜像

源码虽然没有作为文件保存，但它已经影响了：

- 编译后的 JavaScript
- 编译后的 CSS
- `index.html`
- 静态图片和字体
- 生产环境地址
- 最终镜像 digest

可以理解成：

```text
源码文件本身没有进入 final 镜像
源码执行产生的构建结果进入了 final 镜像
```

这和前端把源码编译成 `dist` 后只部署 `dist` 是同一个思路。

### 5. 关于 source map

如果生产构建开启 source map，生成的 `.map` 文件可能包含较多源码信息。当前构建应检查 `dist` 是否生成不必要的 source map：

```powershell
Get-ChildItem -Recurse dist -Filter *.map
```

没有业务需要时，生产镜像不应包含 source map。即使没有源码文件，source map 也可能暴露源码结构。

### 6. BuildKit 缓存不等于最终镜像内容

构建机或 Docker Desktop 可能仍保留：

- builder 缓存层
- Yarn 下载缓存
- 中间阶段缓存
- Buildx GitHub Actions cache

这些缓存用于加快下一次构建，不代表它们被推送进 `siye-world:0.0.2` 的最终运行镜像。

可以区分：

```text
构建缓存：帮助构建，可能留在构建机
最终镜像：推送到 Docker Hub，服务器实际运行
容器可写层：当前容器运行期间产生
```

## 十九、如何验证源码确实没有进入 final 镜像

### 1. 查看最终镜像文件

使用临时容器查看根目录：

```bash
docker run --rm --entrypoint sh siyesummer/siye-world:0.0.2 -c \
  'ls -la /app 2>/dev/null || true; ls -la /usr/share/nginx/html | head -n 30'
```

预期：

- `/app` 不存在，或者不是源码目录
- `/usr/share/nginx/html` 存在 `index.html`、JS、CSS、`release.json`

### 2. 查看镜像历史

```bash
docker history siyesummer/siye-world:0.0.2
```

历史可以帮助判断镜像由哪些层组成，但不能单独证明每个文件不存在；文件检查和历史检查应结合使用。

### 3. 查看最终镜像大小和运行用户

```bash
docker image inspect siyesummer/siye-world:0.0.2 \
  --format 'size={{.Size}} user={{json .Config.User}} labels={{json .Config.Labels}}'
```

当前 final 镜像的运行进程是 Nginx，不需要 Node.js 作为运行时依赖。

## 二十、为什么这适合当前发布方案

当前 `siye-world` 是静态 Vue 前端，适合：

```text
GitHub Actions 构建 dist
  -> Dockerfile 将 dist 放进 Nginx 镜像
  -> Docker Hub 保存固定版本
  -> Linux 只拉取并运行镜像
```

好处是：

- 服务器不需要 Node.js 和 Yarn
- 服务器不需要源码
- 服务器不需要访问 GitHub 源码仓库
- 每个镜像版本内容固定
- 可以通过 digest 追踪真实制品
- 出现问题时可以切回旧镜像
- 源码、构建环境和运行环境边界清晰

这也是“服务器不现场构建业务源码”原则的具体实现。
