# linux-server + MySQL 纯 Docker run 演练步骤

这份文档是当前 `mysql + linux-server` Docker Compose 演练版的“纯 `docker run` 对照版”。

目标不是替代 Compose，而是帮助你理解：

- 如果不用 `docker compose`
- 只用 `docker run`
- 一套多容器服务到底要手动做哪些事

当前这份步骤，等价于当前目录下这套 Compose 配置：

- [docker-compose.yml](E:/本地项目/frontend-knowledge/Docker专题/Docker演练/linux-server-mysql/docker-compose.yml)
- [Dockerfile](E:/本地项目/frontend-knowledge/Docker专题/Docker演练/linux-server-mysql/Dockerfile)

## 一、先理解这份文档在做什么

如果用 `docker compose up -d --build`，Compose 会帮你自动处理这些事：

- 创建网络
- 创建数据卷
- 构建 `linux-server` 镜像
- 启动 `mysql`
- 启动 `linux-server`
- 传环境变量
- 做端口映射
- 让 `linux-server` 通过服务名 `mysql` 连数据库

如果改成纯 `docker run`，这些你都要自己手动补上。

## 二、当前约定

为了不影响你已经跑通的现有服务，当前还是用这组演练端口：

- 宿主机 `3307 -> 容器 MySQL 3306`
- 宿主机 `8082 -> 容器 linux-server 8081`

当前目标目录和文件仍然使用：

- `/opt/docker-labs/linux-server-mysql`
- `linux-server-0.0.1-SNAPSHOT.jar`
- `Dockerfile`

## 三、进入演练目录

```bash
cd /opt/docker-labs/linux-server-mysql
```

建议先确认当前目录里有这些文件：

```bash
ls -la
```

至少应看到：

- `Dockerfile`
- `linux-server-0.0.1-SNAPSHOT.jar`

## 四、先清理可能存在的旧演练资源

如果之前已经跑过一次，为了避免旧容器、旧网络、旧卷干扰，建议先清理。

### 1. 删除旧容器

```bash
docker rm -f lab-linux-server 2>/dev/null || true
docker rm -f lab-mysql 2>/dev/null || true
```

### 2. 删除旧网络

```bash
docker network rm linux-server-lab 2>/dev/null || true
```

### 3. 说明

- 如果你不想删掉旧 MySQL 数据，就不要删除数据卷
- 如果你想完全重来，再执行下面这条

```bash
docker volume rm mysql_data 2>/dev/null || true
```

## 五、创建网络

```bash
docker network create linux-server-lab
```

这一步的作用是：

- 让 `lab-mysql` 和 `lab-linux-server` 在同一个容器网络里
- 后面 `linux-server` 就可以直接通过主机名 `mysql` 访问数据库

## 六、创建数据卷

```bash
docker volume create mysql_data
```

这一步的作用是：

- 把 MySQL 数据持久化到 Docker 卷里
- 即使容器删掉，只要卷还在，数据就还在

### 1. 为什么删掉容器后数据还能在

这里要先区分“容器”和“卷”不是同一个东西。

你可以先这样理解：

- 容器像一个运行中的应用壳
- 卷像一个单独存放数据的硬盘空间

如果不挂卷，MySQL 默认把数据写在容器自己的文件系统里。

这时如果你执行：

```bash
docker rm -f lab-mysql
```

容器被删除，容器内部那层文件系统通常也一起没了，数据库数据就容易跟着丢。

但如果你挂了这条卷：

```bash
-v mysql_data:/var/lib/mysql
```

就表示：

- `mysql_data` 是 Docker 管理的持久化卷
- `/var/lib/mysql` 是 MySQL 真正存放数据库文件的目录

于是 MySQL 虽然看起来是在往容器里的 `/var/lib/mysql` 写数据，但实际上这些数据被写到了 `mysql_data` 这个卷里。

所以后面即使你删掉 `lab-mysql` 这个容器，只要没有删掉 `mysql_data`，数据仍然还在。

### 2. 为什么新容器还能继续读到旧数据

因为你删除的只是旧容器，不是卷本身。

如果后面再起一个新容器，仍然挂同一个卷：

```bash
docker run -d \
  --name lab-mysql-2 \
  -v mysql_data:/var/lib/mysql \
  mysql:8.0.39
```

那新容器会继续读取 `mysql_data` 里已经存在的数据库文件。

所以关键不是“旧容器记住了数据”，而是：

- 旧容器把数据写进卷
- 新容器继续挂这个卷
- 新容器自然就能读到旧数据

### 3. 什么情况下数据会真的丢

常见有这几种：

1. 根本没挂卷，数据本来就只在容器里
2. 把卷删了
3. 起新容器时换了另一个卷名
4. 挂载错了目录，不是 MySQL 真正的数据目录

比如下面这条命令会直接删除卷：

```bash
docker volume rm mysql_data
```

如果你用的是 Docker Compose，下面这条也会删除卷：

```bash
docker compose down -v
```

这里的 `-v` 很关键，表示把这套编排关联的数据卷一起删掉。

### 4. 为什么 MySQL 特别需要卷

因为 MySQL 最重要的不是“容器跑起来了”，而是：

- 数据库还在不在
- 表还在不在
- 聊天消息还在不在

容器可以随时重建，但数据库数据必须能保留。

所以数据库类服务在 Docker 里几乎都要做持久化存储。

### 5. 你当前这套里，卷实际保存的是什么

当前这套演练里：

- `siye_chat_docker_lab` 数据库
- `chat_message` 表
- 你写进去的聊天历史数据

这些最终都落在 `mysql_data` 对应的持久化卷里。

## 七、启动 MySQL 容器

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
  --restart unless-stopped \
  mysql:8.0.39
```

这一步对应 Compose 里的：

- `image: mysql:8.0.39`
- `environment`
- `ports`
- `volumes`
- `restart`

补充理解：

- `--restart unless-stopped` 表示给容器设置自动重启策略
- 容器如果异常退出，Docker 会尽量自动把它重新拉起来
- 服务器重启后，Docker 也会尽量把它重新启动
- 但如果你是手动执行 `docker stop` 把它停掉，Docker 会尊重这个动作，不会默认强行再起

### 1. 启动后检查状态

```bash
docker ps
docker logs -f lab-mysql
```

如果只是想看最近日志，不一直跟着刷，可以用：

```bash
docker logs --tail 50 lab-mysql
```

## 八、等待 MySQL 可用

Compose 版里有健康检查和依赖等待，纯 `docker run` 版这里需要你手动确认。

可以直接执行：

```bash
docker exec lab-mysql mysqladmin ping -h 127.0.0.1 -uroot -p你的root密码
```

如果返回类似：

```text
mysqld is alive
```

说明 MySQL 已经可以用了。

如果还没起来，就稍等几秒再执行一次。

## 九、构建 linux-server 镜像

```bash
docker build -t linux-server:0.0.1 .
```

这一步会读取当前目录的 [Dockerfile](E:/本地项目/frontend-knowledge/Docker专题/Docker演练/linux-server-mysql/Dockerfile)，把 `linux-server-0.0.1-SNAPSHOT.jar` 打进镜像里。

构建完成后可以检查：

```bash
docker images
```

## 十、启动 linux-server 容器

```bash
docker run -d \
  --name lab-linux-server \
  --network linux-server-lab \
  -e TZ=Asia/Shanghai \
  -e JAVA_TOOL_OPTIONS=-Duser.timezone=Asia/Shanghai \
  -e SPRING_DATASOURCE_URL='jdbc:mysql://lab-mysql:3306/siye_chat_docker_lab?useUnicode=true&characterEncoding=utf8&serverTimezone=Asia/Shanghai&useSSL=false&allowPublicKeyRetrieval=true' \
  -e SPRING_DATASOURCE_USERNAME=siye_chat_lab \
  -e SPRING_DATASOURCE_PASSWORD=你的业务密码 \
  -e SPRING_PROFILES_ACTIVE=docker-lab \
  -p 8082:8081 \
  -v /var/log/siye:/var/log/siye:ro \
  --restart unless-stopped \
  linux-server:0.0.1
```

这一步对应 Compose 里的：

- `build`
- `environment`
- `ports`
- `volumes`
- `restart`

这里的 `--restart unless-stopped` 和 MySQL 那边一样，适合这种希望长期常驻运行、但又不想在你手动停掉后立刻反复拉起的服务。

注意这里 JDBC 地址写的是：

```text
jdbc:mysql://lab-mysql:3306/siye_chat_docker_lab...
```

这里的 `lab-mysql` 不是公网地址，而是你前面用 `--name lab-mysql` 启动出来的 MySQL 容器名。

在用户自定义 Docker 网络里：

- `lab-mysql` 这种容器名，其他容器通常可以直接解析
- 所以 `lab-linux-server` 可以通过 `lab-mysql:3306` 访问 MySQL

补充说明：

- 在 `docker compose` 里，写 `mysql:3306` 是合理的，因为 Compose 默认会给服务名 `mysql` 创建网络内可解析地址
- 但在这份“纯 docker run”文档里，前面启动的容器名是 `lab-mysql`，没有额外声明 `mysql` 这个网络别名，所以这里写成 `lab-mysql:3306` 更严谨
- 如果你非常想继续写 `mysql:3306`，那前面启动 MySQL 时要额外加 `--network-alias mysql`

## 十一、检查两个容器状态

```bash
docker ps
```

也可以分别看日志：

```bash
docker logs --tail 50 lab-mysql
docker logs --tail 50 lab-linux-server
```

如果想持续跟日志：

```bash
docker logs -f lab-linux-server
```

## 十二、接口验证

### 1. 先看日志查询

```bash
curl "http://127.0.0.1:8082/api/logs/query?service=all&page=1&pageSize=10"
```

### 2. 再写一条聊天测试消息

```bash
curl -X POST "http://127.0.0.1:8082/api/chat/messages" \
  -H "Content-Type: application/json" \
  -d '{
    "roomCode": "public-room",
    "messageId": "docker-run-msg-001",
    "senderId": "docker-run-user-001",
    "userName": "docker-run",
    "content": "Docker run 演练测试消息",
    "sendTime": "2026-07-10 21:00:00",
    "type": "USER"
  }'
```

### 3. 再查聊天历史

```bash
curl "http://127.0.0.1:8082/api/chat/messages?roomCode=public-room&pageSize=10"
curl "http://127.0.0.1:8082/api/logs/query?service=chat-history&page=1&pageSize=10"
```

如果都能看到刚写入的消息，说明这套纯 `docker run` 链路也已经打通。

## 十三、查看数据库

```bash
docker exec -it lab-mysql sh
mysql -uroot -p"$MYSQL_ROOT_PASSWORD"
```

进入 MySQL 后可以执行：

```sql
SHOW DATABASES;
USE siye_chat_docker_lab;
SHOW TABLES;
SELECT * FROM chat_message;
```

## 十四、停止和删除

### 1. 停止容器

```bash
docker stop lab-linux-server
docker stop lab-mysql
```

### 2. 删除容器

```bash
docker rm lab-linux-server
docker rm lab-mysql
```

### 3. 删除网络

```bash
docker network rm linux-server-lab
```

### 4. 如果想彻底清空数据库数据，再删卷

```bash
docker volume rm mysql_data
```

## 十五、这份纯 docker run 步骤暴露出的核心区别

你跑完这一套之后，会很容易看出 Compose 帮你省掉了什么：

### 1. Compose 帮你集中保存配置

纯 `docker run`：

- 所有参数都堆在命令行里

Compose：

- 配置集中写在 `docker-compose.yml`

### 2. Compose 更适合多容器项目

纯 `docker run`：

- 你要自己记住先起谁、后起谁
- 要自己建网络、建卷

Compose：

- 一条命令起整套服务

### 3. Compose 更适合长期维护

纯 `docker run`：

- 临时实验很好
- 但正式项目里命令长、容易漏、难复用

Compose：

- 更适合团队协作
- 更适合文档化
- 更适合反复部署

## 十六、当前阶段怎么理解两种方式

对你现在这个阶段，最实用的理解是：

1. 学 `docker run`，理解容器启动的底层构成。
2. 学 `docker compose`，理解项目级多容器编排。
3. 后续真正做服务部署时，优先掌握 Compose。

所以这两种方式不是互相替代，而是：

- `docker run` 帮你理解本质
- `docker compose` 帮你管理真实项目
