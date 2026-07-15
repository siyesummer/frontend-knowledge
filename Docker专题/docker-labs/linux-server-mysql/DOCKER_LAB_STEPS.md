# linux-server + MySQL Docker Compose 服务器演练步骤

## 一、目标

在 Linux 服务器上单独开一套 Docker 演练环境：

- 一个 `MySQL` 容器
- 一个 `linux-server` 容器

并且满足：

- 不影响当前已经跑通的 `systemd + 目录部署` 服务
- 使用新端口做演练
- `linux-server` 容器仍然可以读取宿主机的 `/var/log/siye` 日志

## 二、当前演练端口规划

- 宿主机 `3307` -> 容器 `3306`（MySQL）
- 宿主机 `8082` -> 容器 `8081`（linux-server）

当前不要占用：

- `3306`：当前宿主机 MySQL
- `3030`：当前 `easy-chat`
- `8081`：当前 `systemd` 方式运行的 `linux-server`

## 三、当前材料位置

当前演练材料统一放在当前仓库的 `Docker专题` 目录下：

- `Docker专题/docker-labs/linux-server-mysql/Dockerfile`
- `Docker专题/docker-labs/linux-server-mysql/docker-compose.yml`
- `Docker专题/docker-labs/linux-server-mysql/.env.example`
- `Docker专题/docker-labs/linux-server-mysql/DOCKER_LAB_STEPS.md`

### 3.1 如果只改了一个文件，怎么单独上传

如果当前只改了某一个文件，比如：

- `docker-compose.yml`

那么不需要把整个目录重新上传，可以直接单文件替换。

本地 PowerShell：

```powershell
scp "E:\github项目\frontend-knowledge\Docker专题\docker-labs\linux-server-mysql\docker-compose.yml" ubuntu@YOUR_SERVER_IP:/tmp/docker-compose.yml
```

服务器执行：

```bash
cp /opt/docker-labs/linux-server-mysql/docker-compose.yml /opt/docker-labs/linux-server-mysql/docker-compose.yml.bak
mv /tmp/docker-compose.yml /opt/docker-labs/linux-server-mysql/docker-compose.yml
```

如果这个文件改动会影响容器编排或运行参数，比如：

- `docker-compose.yml`
- `Dockerfile`
- `.env`

那么替换完成后需要重新创建容器：

```bash
cd /opt/docker-labs/linux-server-mysql
docker compose up -d --build --force-recreate
docker compose ps
```

补充说明：

- 单文件上传适合小范围修正，不必每次都重新上传整个目录
- 覆盖前先备份旧文件，是为了后面出问题时可以快速回退
- `docker-compose.yml`、`Dockerfile`、`.env` 这类文件改完后，通常不能只看文件落盘，还要让容器重新吃到新配置

## 四、本地准备 jar

### 1. 这一步是干什么的

这里是在为 `linux-server` 这个 Java 项目生成可部署的 `jar` 包。

- `mvn test`：先跑测试，提前确认代码没有被改坏
- `mvn package -DskipTests`：正式打包，产出可部署的 `jar`

最终会生成类似这个文件：

- `E:\本地项目\java-project\linux-server\target\linux-server-0.0.1-SNAPSHOT.jar`

### 2. 为什么命令里没写项目路径也能打包

因为 Maven 默认是对“当前所在目录”执行的。

它会看你执行命令时所在的目录里有没有 `pom.xml`。如果当前目录就是：

- `E:\本地项目\java-project\linux-server`

那它就会把这个目录当成 `linux-server` 项目来处理。

### 2.1 工具名和命令名为什么不一样

这里很容易让前端同学误会，因为很多工具的“产品名”和“命令行执行名”本来就不是一回事。

常见对照可以先这样记：

- `Maven` 是工具名，命令是 `mvn`
- `Java` 是语言 / 运行环境名，运行命令是 `java`
- `Java Compiler` 是编译器概念，编译命令是 `javac`
- `Docker` 是工具名，命令是 `docker`
- `Docker Compose` 现在常用命令是 `docker compose`
- `MySQL` 是数据库名，命令行客户端常用命令是 `mysql`

你可以把它理解成：

- 工具名更像产品名
- 命令名更像终端里真正输入的可执行程序名

所以这里不要写成：

```powershell
maven test
```

而要写成：

```powershell
mvn test
```

### 3. 方式一：先进入项目目录，再执行 Maven

这种方式更像前端里先 `cd` 到项目目录，再执行 `npm run build`。

```powershell
cd E:\本地项目\java-project\linux-server
mvn test
mvn package -DskipTests
```

适用场景：

- 你已经在这个项目目录里操作
- 临时手动打包
- 想先建立“当前目录 + `pom.xml`”这个基本认知

### 4. 方式二：不切目录，直接用 `-f` 指定 `pom.xml`

这种方式更明确，也更适合写到部署文档里，避免在错误目录下误执行。

```powershell
mvn -f E:\本地项目\java-project\linux-server\pom.xml test
mvn -f E:\本地项目\java-project\linux-server\pom.xml package -DskipTests
```

适用场景：

- 写部署文档
- 复制给别人直接执行
- 你同时开了多个项目，不想搞混当前目录

### 5. 当前更推荐哪一种

对你现在这个阶段，推荐优先记住这两个结论：

1. 想理解 Maven 怎么找项目，用“先进入目录再执行”。
2. 想让命令更严谨、更不容易出错，用“`-f` 指定 `pom.xml`”。

如果 Maven 已经全局安装到环境变量里，这两种写法都可以；如果是写正式步骤文档，当前更推荐第二种。

### 6. 打包完成后复制 jar 到当前 Docker 演练目录

```powershell
Copy-Item "E:\本地项目\java-project\linux-server\target\linux-server-0.0.1-SNAPSHOT.jar" "E:\github项目\frontend-knowledge\Docker专题\docker-labs\linux-server-mysql\linux-server-0.0.1-SNAPSHOT.jar" -Force
```

## 五、准备环境变量文件

把：

- `Docker专题/docker-labs/linux-server-mysql/.env.example`

复制成：

- `Docker专题/docker-labs/linux-server-mysql/.env`

示例：

```env
MYSQL_ROOT_PASSWORD=REPLACE_WITH_ROOT_PASSWORD
MYSQL_DATABASE=siye_chat_docker_lab
MYSQL_USER=siye_chat_lab
MYSQL_PASSWORD=REPLACE_WITH_APP_PASSWORD
MYSQL_HOST_PORT=3307
LINUX_SERVER_HOST_PORT=8082
```

## 六、上传演练目录到 Linux 服务器

建议上传到：

- `/opt/docker-labs/linux-server-mysql`

本地 PowerShell：

```powershell
scp -r "E:\github项目\frontend-knowledge\Docker专题\docker-labs\linux-server-mysql" ubuntu@YOUR_SERVER_IP:/tmp/
```

服务器执行：

```bash
sudo mkdir -p /opt/docker-labs
sudo chown ubuntu:ubuntu /opt/docker-labs
sudo rm -rf /opt/docker-labs/linux-server-mysql
sudo mv /tmp/linux-server-mysql /opt/docker-labs/
sudo chown -R ubuntu:ubuntu /opt/docker-labs/linux-server-mysql
```

说明：

- `mkdir` 用 `sudo` 创建目录后，目录初始属主通常是 `root`
- 提前执行 `chown ubuntu:ubuntu /opt/docker-labs`，可以减少后续 `ubuntu` 用户在这个演练目录下操作时的权限问题

## 七、服务器安装 Docker 和 Compose

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-v2
sudo systemctl enable docker
sudo systemctl start docker
sudo systemctl status docker --no-pager
```

把当前用户加入 `docker` 组：

```bash
sudo usermod -aG docker ubuntu
newgrp docker
```

验证：

```bash
docker -v
docker compose version
```

## 八、启动演练环境

```bash
cd /opt/docker-labs/linux-server-mysql
docker compose config
docker compose up -d --build
docker compose ps
```

如果你更新了当前目录里的 `docker-compose.yml`，并且需要让容器重新吃到新的时区配置，可以执行：

```bash
cd /opt/docker-labs/linux-server-mysql
docker compose up -d --build --force-recreate
docker compose ps
```

补充说明：

- 当前 Docker 演练版已经增加了 `TZ=Asia/Shanghai`
- `linux-server` 容器额外增加了 `JAVA_TOOL_OPTIONS=-Duser.timezone=Asia/Shanghai`
- 这样做的目的是让 `generatedAt`、数据库时间和容器内时间统一为中国本地时间

查看日志：

```bash
docker compose logs -f
docker compose logs -f mysql
docker compose logs -f linux-server
```

### 8.1 如果拉取 MySQL 镜像超时

如果看到类似下面的错误：

```text
failed to resolve reference "docker.io/library/mysql:8.0.39"
dial tcp ...:443: i/o timeout
```

这通常不是 `docker-compose.yml` 写错了，而是服务器当前访问 Docker Hub 超时。

可以按这个顺序处理：

1. 先确认是不是拉取镜像网络超时

```bash
docker pull mysql:8.0.39
```

2. 给 Docker 配置镜像加速器

先在云厂商控制台或你当前可用的镜像源平台拿到一个有效的 Docker 镜像加速地址，再写入：

```bash
sudo mkdir -p /etc/docker
sudo nano /etc/docker/daemon.json
```

写成类似这样：

```json
{
  "registry-mirrors": [
    "你的镜像加速地址"
  ]
}
```

3. 重启 Docker

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

4. 重新验证

```bash
docker -v
docker compose version
docker pull mysql:8.0.39
```

5. 镜像拉取成功后再重新启动编排

```bash
cd /opt/docker-labs/linux-server-mysql
docker compose up -d --build
docker compose ps
```

补充说明：

- 这类报错本质上是“镜像仓库访问问题”，不是应用代码问题
- 在国内云服务器上做 Docker 演练时，提前准备镜像加速器通常是默认动作

## 九、接口验证

```bash
curl "http://127.0.0.1:8082/api/chat/messages?roomCode=public-room&pageSize=10"
curl "http://127.0.0.1:8082/api/logs/query?service=all&page=1&pageSize=10"
curl "http://127.0.0.1:8082/api/logs/query?service=chat-history&page=1&pageSize=10"
```

如果这里出现下面这种情况：

- `service=all` 能查到日志
- `api/chat/messages` 返回空数组
- `service=chat-history` 也返回空数组

通常是正常现象，说明：

- Docker 版 `linux-server` 已经能读取宿主机 `/var/log/siye`
- Docker 版自己连接的是独立演练库 `siye_chat_docker_lab`
- 当前这个演练库里还没有聊天消息

这时可以主动写入一条测试消息，补完整个 `chat-history` 验证链路：

```bash
curl -X POST "http://127.0.0.1:8082/api/chat/messages" \
  -H "Content-Type: application/json" \
  -d '{
    "roomCode": "public-room",
    "messageId": "docker-lab-msg-001",
    "senderId": "docker-lab-user-001",
    "userName": "docker-lab",
    "content": "Docker 演练测试消息",
    "sendTime": "2026-07-10 20:45:00",
    "type": "USER"
  }'
```

补充说明：

- `messageId` 在同一个 `roomCode` 下要唯一
- 如果重复执行同一个 `messageId`，接口通常会返回已存在的那条消息
- 如果想写入新消息，把 `messageId` 改成新的值，比如 `docker-lab-msg-002`

写入成功后，再执行：

```bash
curl "http://127.0.0.1:8082/api/chat/messages?roomCode=public-room&pageSize=10"
curl "http://127.0.0.1:8082/api/logs/query?service=chat-history&page=1&pageSize=10"
```

验证 Docker 里的 MySQL：

```bash
docker compose exec mysql mysql -uroot -p
```

进入后可执行：

```sql
SHOW DATABASES;
USE siye_chat_docker_lab;
SHOW TABLES;
SELECT COUNT(*) FROM chat_message;
```

### 9.1 如果提示输入密码后仍然报 `using password: NO`

如果你执行：

```bash
docker compose exec mysql mysql -uroot -p
```

然后看到：

```text
ERROR 1045 (28000): Access denied for user 'root'@'localhost' (using password: NO)
```

这通常说明：

- 不是 MySQL 容器坏了
- 不是 root 用户不存在
- 而是这次登录实际上没有带上有效密码

这里的关键是：

- `using password: NO` 表示 MySQL 认为你这次没有真正提供密码

在当前 Docker 演练场景里，更稳的验证方式是直接让容器内部展开环境变量：

```bash
docker compose exec mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW DATABASES;"'
```

如果能看到数据库列表，就说明：

- MySQL root 密码正确
- 容器内 MySQL 正常可用
- `siye_chat_docker_lab` 已经成功创建

补充说明：

- 你看到 `Using a password on the command line interface can be insecure.` 只是警告，不是错误
- 在当前学习演练环境里这样验证是可以接受的
- 在正式生产环境里，一般会避免把密码直接明文写在命令行参数里

## 十、停止和清理

```bash
docker compose stop
docker compose down
docker compose down -v
```

说明：

- `down -v` 会删除 Docker 演练环境里的 MySQL 数据
- 不会影响当前宿主机上通过 `systemd` 运行的正式/练习服务

补充理解：

- 当前 MySQL 数据之所以在删除容器后还能保留，是因为 Compose 里把数据挂到了卷 `mysql_data`
- 容器和卷不是同一个东西：删容器不等于删卷
- 只要卷还在，后面重新创建 MySQL 容器并继续挂同一个卷，数据库文件就还能读到
- 真正会把这套 Docker 演练版数据库清空的，通常是 `docker compose down -v` 或单独删除对应卷

## 十一、当前阶段定位

这套 Docker 演练环境的定位是：

- 学习 Docker / Docker Compose
- 对比“目录部署版”和“容器版”的差异
- 不取代当前已经跑通的 `systemd + 目录部署`

## 十二、下一步建议

这套 `mysql + linux-server` 跑通之后，再按顺序做：

1. 给 `easy-chat` 增加 Docker 版
2. 再考虑 `music-api`
3. 最后再考虑 `nginx`
