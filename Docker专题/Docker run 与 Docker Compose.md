# Docker run 与 Docker Compose

这份文档专门从“给转全栈的前端同学看的版本”出发，基于当前已经跑通的这套演练配置来讲：

- 单独 `docker run` 是怎么工作的
- `docker compose up -d --build` 到底做了什么
- 什么时候适合用 `docker run`
- 什么时候适合用 `docker compose`
- 能不能配合 Docker Hub 做更方便的部署

当前讲解基于这套实际文件：

- [docker-compose.yml](E:/本地项目/frontend-knowledge/Docker专题/Docker演练/linux-server-mysql/docker-compose.yml)
- [Dockerfile](E:/本地项目/frontend-knowledge/Docker专题/Docker演练/linux-server-mysql/Dockerfile)
- [Docker演练步骤.md](E:/本地项目/frontend-knowledge/Docker专题/Docker演练/linux-server-mysql/Docker演练步骤.md)

## 一、先记住两句话

1. `docker run` 更像“手动启动一个容器”。
2. `docker compose` 更像“按一份项目配置，一次性启动一组有关联的容器”。

如果你把它类比到前端：

- `docker run` 有点像你手写一长串启动参数去跑一个服务
- `docker compose` 有点像把启动配置写进 `vite.config.js`、`package.json`、`.env` 之后，再用一个统一命令拉起整套环境

## 二、当前这套 Docker Compose 实际用了哪些文件

你当前这套 `mysql + linux-server` 演练版，核心文件有 4 个：

### 1. `docker-compose.yml`

它负责定义：

- 有哪些服务
- 每个服务用什么镜像
- 端口怎么映射
- 环境变量怎么传
- 容器之间怎么互相访问
- 数据卷怎么挂载
- 启动顺序和健康检查

你当前定义了两个服务：

- `mysql`
- `linux-server`

### 2. `Dockerfile`

它只服务于 `linux-server` 这个 Java 应用镜像的构建。

你当前这个文件做了几件事：

1. 以 `eclipse-temurin:21-jre` 作为基础镜像
2. 设置工作目录 `/app`
3. 把 `linux-server-0.0.1-SNAPSHOT.jar` 复制进镜像
4. 暴露 `8081`
5. 通过 `java -jar /app/app.jar` 启动应用

### 3. `.env`

它负责存放“可变参数”，比如：

- MySQL root 密码
- 业务库名
- 业务账号密码
- 宿主机端口

也就是说：

- `docker-compose.yml` 是结构
- `.env` 是参数

### 4. `linux-server-0.0.1-SNAPSHOT.jar`

这是 Java 应用本体。

没有这个 `jar`，`Dockerfile` 只能构建一个空壳镜像，跑不起来你的业务服务。

## 三、`docker compose up -d --build` 详细执行过程

这条命令可以拆成 3 部分理解：

### 1. `docker compose`

表示用 Compose 编排工具来管理当前目录的多容器项目。

它默认会读取当前目录里的：

- `docker-compose.yml`
- `.env`

### 2. `up`

表示“把这套服务拉起来”。

如果容器不存在，它会：

- 创建网络
- 创建数据卷
- 创建容器
- 启动容器

如果容器已经存在，它会：

- 尝试复用已有资源
- 按当前配置重新启动或更新容器

### 3. `-d`

表示后台运行。

如果不加 `-d`，日志会一直占着当前终端。

### 4. `--build`

表示在启动前，先构建所有需要 `build:` 的服务镜像。

你的当前配置里：

- `mysql` 用的是现成镜像 `mysql:8.0.39`
- `linux-server` 用的是 `build`

所以 `--build` 主要影响的是 `linux-server`。

## 四、这条命令在你当前项目里实际做了什么

按当前 [docker-compose.yml](E:/本地项目/frontend-knowledge/Docker专题/Docker演练/linux-server-mysql/docker-compose.yml)，它大致按这个顺序执行：

1. 读取 `docker-compose.yml`
2. 读取 `.env`，把 `${MYSQL_ROOT_PASSWORD}` 这类变量替换成真实值
3. 检查 `mysql` 服务配置
4. 检查 `linux-server` 服务配置
5. 如果本地没有 `mysql:8.0.39`，就先拉取官方 MySQL 镜像
6. 因为 `linux-server` 有 `build:`，所以读取 [Dockerfile](E:/本地项目/frontend-knowledge/Docker专题/Docker演练/linux-server-mysql/Dockerfile)
7. 用当前目录 `context: .` 作为构建上下文，把 `jar` 打进镜像
8. 创建默认网络，让 `linux-server` 能用服务名 `mysql` 访问数据库
9. 创建数据卷 `mysql_data`
10. 启动 `mysql`
11. 根据健康检查等待 `mysql` 进入 `healthy`
12. 再启动 `linux-server`
13. 根据 `ports` 把宿主机端口映射出去：
    - `3307 -> 3306`
    - `8082 -> 8081`
14. 根据 `volumes` 挂载：
    - `mysql_data:/var/lib/mysql`
    - `/var/log/siye:/var/log/siye:ro`

## 五、为什么 `linux-server` 能连上 `mysql`

这是 Compose 很重要的一点。

你在 JDBC 地址里写的是：

```text
jdbc:mysql://mysql:3306/${MYSQL_DATABASE}
```

这里的 `mysql` 不是公网域名，也不是 `127.0.0.1`，而是 Compose 自动创建的服务名。

也就是说：

- `mysql` 服务启动后，会在这套 Compose 网络里拥有一个可解析的名字 `mysql`
- `linux-server` 在同一个网络里，就可以直接通过 `mysql:3306` 连过去

这就是为什么多容器项目里，Compose 比纯手工命令舒服很多。

### 5.1 为什么 `docker-compose.yml` 没写 `networks` 也能互通

因为 Compose 有默认行为：

- 如果你没有手动写 `networks:`
- Compose 会自动为当前项目创建一张默认网络
- 并把这份 `docker-compose.yml` 里的服务都接进去

所以你虽然没有显式写网络配置，但实际启动时还是会看到类似：

```text
Network linux-server-mysql_default Created
```

这里可以先这样记：

- 默认网络名通常是 `项目名_default`

你当前这套目录名是 `linux-server-mysql`，所以默认网络名就成了：

- `linux-server-mysql_default`

### 5.2 `networks: app-net: driver: bridge` 怎么解读

如果你想把网络显式写出来，可以这样写：

```yaml
services:
  mysql:
    image: mysql:8.0.39
    networks:
      - app-net

  linux-server:
    build:
      context: .
      dockerfile: Dockerfile
    networks:
      - app-net

networks:
  app-net:
    driver: bridge
```

可以这样解读：

- 最下面的 `networks:` 是“声明这套项目要创建哪些网络”
- `app-net:` 是“这张网络的名字叫 `app-net`”
- `driver: bridge` 是“这张网络使用 Docker 默认最常见的单机桥接网络模式”

上面服务里的：

```yaml
networks:
  - app-net
```

表示：

- 把这个服务接到 `app-net` 这张网络里

所以它其实分两层：

1. 先定义网络
2. 再把服务挂到这张网络上

### 5.3 当前这套为什么不必显式写

因为你当前只有两个服务：

- `mysql`
- `linux-server`

而且它们本来就需要互通，所以直接用 Compose 默认网络已经够用了。

后面如果服务变多，比如再加入：

- `easy-chat`
- `music-api`
- `nginx`

或者你开始希望“某些服务互通、某些服务隔离”，那就更适合显式写 `networks:`。

## 六、如果不用 Compose，只用 `docker run` 能不能做到

可以做到，但你要自己手动把 Compose 帮你做的事一项项补上。

### 1. 创建网络

```bash
docker network create linux-server-lab
```

### 2. 创建数据卷

```bash
docker volume create mysql_data
```

### 3. 启动 MySQL 容器

```bash
docker run -d \
  --name lab-mysql \
  --network linux-server-lab \
  -e TZ=Asia/Shanghai \
  -e MYSQL_ROOT_PASSWORD=你的root密码 \
  -e MYSQL_DATABASE=siye_chat_docker_lab \
  -e MYSQL_USER=siye_chat_lab \
  -e MYSQL_PASSWORD=你的业务密码 \
  -p 3307:3306 \
  -v mysql_data:/var/lib/mysql \
  mysql:8.0.39
```

### 4. 构建 `linux-server` 镜像

```bash
docker build -t linux-server:0.0.1 .
```

### 5. 启动 `linux-server` 容器

```bash
docker run -d \
  --name lab-linux-server \
  --network linux-server-lab \
  -e TZ=Asia/Shanghai \
  -e JAVA_TOOL_OPTIONS=-Duser.timezone=Asia/Shanghai \
  -e SPRING_DATASOURCE_URL='jdbc:mysql://mysql:3306/siye_chat_docker_lab?useUnicode=true&characterEncoding=utf8&serverTimezone=Asia/Shanghai&useSSL=false&allowPublicKeyRetrieval=true' \
  -e SPRING_DATASOURCE_USERNAME=siye_chat_lab \
  -e SPRING_DATASOURCE_PASSWORD=你的业务密码 \
  -e SPRING_PROFILES_ACTIVE=docker-lab \
  -p 8082:8081 \
  -v /var/log/siye:/var/log/siye:ro \
  linux-server:0.0.1
```

## 七、`docker run` 和 `docker compose` 的区别

### 1. 配置存放位置不同

- `docker run`：配置全写在命令行里
- `docker compose`：配置主要写在 `docker-compose.yml`

### 2. 多容器项目的管理复杂度不同

- `docker run`：你要自己管理网络、卷、启动顺序、参数
- `docker compose`：用一份 YAML 集中管理

### 3. 复用性不同

- `docker run`：适合临时测试，命令复制长且容易漏
- `docker compose`：适合项目化、团队协作、重复部署

### 4. 可读性不同

- `docker run`：一次能看懂一个容器，但命令长了以后不直观
- `docker compose`：更适合看整体架构

### 5. 修改成本不同

- `docker run`：每次改参数都要重新写命令
- `docker compose`：改 YAML 即可

## 八点一、`--restart unless-stopped` 是什么意思

这个参数是容器的自动重启策略。

可以先直接这样理解：

- 容器异常退出时，Docker 会尝试自动重启它
- 服务器重启后，Docker 也会尽量把它重新拉起来
- 但如果你是手动把容器停掉的，Docker 不会默认强行再把它拉起

也就是说，`unless-stopped` 的意思可以近似理解成：

- “除非你明确把它停掉，否则尽量让它一直活着”

### 1. 为什么当前这类服务适合它

像你现在这套里的：

- `mysql`
- `linux-server`

都属于希望长期常驻运行的服务，所以适合加自动重启策略。

但我们又不希望你为了调试手动停掉以后，它立刻自己又起来，所以 `unless-stopped` 比 `always` 更温和，也更适合当前阶段。

### 2. 常见重启策略对比

#### 不写 `--restart`

- 默认不自动重启
- 容器挂了就挂了
- 服务器重启后也不会自己起来

#### `--restart always`

- 容器挂了会自动重启
- 服务器重启后也会自动重启
- 即使你手动停掉，后面 Docker 服务重启时它也可能又起来

#### `--restart unless-stopped`

- 容器挂了会自动重启
- 服务器重启后也会自动重启
- 但如果你手动停掉，它会尊重你的操作

#### `--restart on-failure`

- 只在异常退出时重启
- 更适合某些任务型容器
- 对数据库、Web 服务这类长期运行服务不如 `unless-stopped` 常见

### 3. 怎么看一个容器当前的重启策略

```bash
docker inspect --format='{{.HostConfig.RestartPolicy.Name}}' lab-mysql
docker inspect --format='{{.HostConfig.RestartPolicy.Name}}' lab-linux-server
```

如果配置成功，通常会看到：

```text
unless-stopped
```

## 九、现在一般怎么用

当前常见情况大致是这样：

### 1. 临时试一个容器

一般用：

```bash
docker run
```

比如临时跑个 Nginx、MySQL、Redis。

### 2. 本地开发、多容器联调、小中型服务

一般用：

```bash
docker compose
```

这是你当前阶段最值得熟练掌握的方式。

### 3. 更大规模、正式生产、自动扩缩容

通常不会长期靠 Compose，而是会进入：

- Kubernetes
- 云厂商容器服务
- 更完整的 CI/CD 发布体系

## 十、能不能上传到 Docker Hub，以后部署更方便

可以，而且这是非常常见的做法。

但准确说，不是把 `docker-compose.yml` 上传到 Docker Hub，而是：

1. 把你自己的业务镜像上传到 Docker Hub
2. 服务器部署时直接拉镜像
3. Compose 文件继续保存在代码仓库或服务器上

### 1. 当前这套里谁需要上传

当前这套里：

- `mysql:8.0.39` 是官方镜像，不需要你上传
- 你真正要上传的是 `linux-server` 这个自定义镜像

### 2. 标准流程

先在本地或 CI 构建镜像：

```bash
docker build -t 你的DockerHub用户名/linux-server:0.0.1 .
```

登录 Docker Hub：

```bash
docker login
```

推送镜像：

```bash
docker push 你的DockerHub用户名/linux-server:0.0.1
```

### 3. 以后怎么部署

以后可以把 Compose 配置里的：

```yaml
build:
  context: .
  dockerfile: Dockerfile
```

改成：

```yaml
image: 你的DockerHub用户名/linux-server:0.0.1
```

然后服务器上直接：

```bash
docker compose pull
docker compose up -d
```

## 十一、Docker Hub 方式为什么更适合正式部署

因为它更接近真正的“发布产物”思路。

区别是：

### 当前你现在这套演练方式

1. 本地打 `jar`
2. 上传 `jar`
3. 服务器本地 build 镜像
4. 服务器启动容器

### 更标准的镜像发布方式

1. 本地或 CI 打 `jar`
2. 本地或 CI build 镜像
3. 推送镜像到 Docker Hub
4. 服务器只负责 pull + up

这样做的好处：

- 服务器更轻
- 部署更快
- 发布产物更统一
- 更容易回滚到旧版本镜像

## 十二、当前阶段你该怎么学

对你现在这个阶段，推荐顺序是：

1. 先继续理解 `docker run`
2. 再重点掌握 `docker compose`
3. 再理解镜像仓库和 Docker Hub
4. 最后再去接触更正式的容器发布体系

最实用的结论可以先记住：

- `docker run` 让你理解“单个容器怎么启动”
- `docker compose` 让你管理“一个项目的整套容器”
- Docker Hub 让你把“镜像发布”和“服务器部署”分开

## 十三、当前这套演练结论

你现在已经真实跑通过一套：

- `mysql + linux-server`
- Docker Compose 编排
- MySQL 数据持久化
- 宿主机日志挂载
- 前端通过公网 IP 调 Docker 接口
- `chat-history` 写入与聚合查询

所以你现在不是“只会命令”，而是已经完成了第一套完整容器化联调实践。
