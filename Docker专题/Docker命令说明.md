# Docker命令说明

## 适用目标

这份文档用于 Docker / Docker Compose 入门阶段的命令速查，优先服务于：

- 理解 Docker 核心概念
- 在本地或 Linux 服务器上做基础演练
- 后续为 `siyeWorld`、`linux-server`、`easy-chat` 做容器化准备

## 一、先理解几个核心概念

- `镜像（image）`：应用运行所需文件和环境的打包结果
- `容器（container）`：镜像启动后的运行实例
- `仓库（registry）`：存放镜像的地方，比如 Docker Hub
- `数据卷（volume）`：容器之外持久化保存数据的方式
- `端口映射`：把容器里的端口映射到宿主机端口

## 二、常用 Docker 命令

### 1. 查看 Docker 版本

```bash
docker -v
docker version
```

### 2. 查看 Docker 基本信息

```bash
docker info
```

### 3. 拉取镜像

```bash
docker pull nginx
docker pull mysql:8.0
docker pull openjdk:21-jdk
```

说明：

- 不写标签时默认拉 `latest`
- 实际项目里更推荐显式写版本标签

### 4. 查看本地镜像

```bash
docker images
```

### 5. 删除镜像

```bash
docker rmi nginx
docker rmi 镜像ID
```

### 6. 运行容器

```bash
docker run nginx
```

常见带参数写法：

```bash
docker run -d --name my-nginx -p 8080:80 nginx
```

说明：

- `-d`：后台运行
- `--name`：指定容器名
- `-p 8080:80`：宿主机 `8080` 映射到容器 `80`

### 7. 查看运行中的容器

```bash
docker ps
```

查看所有容器：

```bash
docker ps -a
```

### 8. 停止容器

```bash
docker stop 容器名
docker stop 容器ID
```

### 9. 启动已停止容器

```bash
docker start 容器名
```

### 10. 重启容器

```bash
docker restart 容器名
```

### 11. 删除容器

```bash
docker rm 容器名
```

强制删除运行中的容器：

```bash
docker rm -f 容器名
```

### 12. 查看容器日志

```bash
docker logs 容器名
```

持续追踪：

```bash
docker logs -f 容器名
```

### 13. 进入容器内部

```bash
docker exec -it 容器名 /bin/bash
```

如果容器没有 `bash`，可用：

```bash
docker exec -it 容器名 /bin/sh
```

### 14. 查看容器详细信息

```bash
docker inspect 容器名
```

### 15. 查看容器资源使用

```bash
docker stats
```

### 16. 查看容器端口映射

```bash
docker port 容器名
```

## 三、数据卷相关命令

### 1. 创建数据卷

```bash
docker volume create mydata
```

### 2. 查看数据卷

```bash
docker volume ls
```

### 3. 查看数据卷详情

```bash
docker volume inspect mydata
```

### 4. 删除数据卷

```bash
docker volume rm mydata
```

### 5. 运行容器时挂载数据卷

```bash
docker run -d --name my-mysql -v mydata:/var/lib/mysql mysql:8.0
```

### 6. 绑定宿主机目录

```bash
docker run -d --name my-nginx -v /opt/nginx/html:/usr/share/nginx/html -p 8080:80 nginx
```

说明：

- `volume` 更偏 Docker 推荐方式
- `bind mount` 更适合你想直接映射宿主机现有目录时使用

## 四、环境变量相关

运行容器时传环境变量：

```bash
docker run -d --name my-mysql -e MYSQL_ROOT_PASSWORD=REPLACE_WITH_PASSWORD mysql:8.0
```

多个环境变量：

```bash
docker run -d --name app \
  -e SPRING_DATASOURCE_URL=jdbc:mysql://mysql:3306/test \
  -e SPRING_DATASOURCE_USERNAME=root \
  -e SPRING_DATASOURCE_PASSWORD=REPLACE_WITH_PASSWORD \
  my-app:latest
```

## 五、网络相关

### 1. 查看网络

```bash
docker network ls
```

### 2. 创建网络

```bash
docker network create mynet
```

### 3. 容器加入网络

```bash
docker run -d --name mysql --network mynet mysql:8.0
docker run -d --name app --network mynet my-app:latest
```

说明：

- 同一个网络里的容器可以直接通过容器名互相访问
- 比如 Java 服务可直接访问 `mysql:3306`

## 六、Dockerfile 基础

Dockerfile 是构建镜像的脚本文件。

一个最简单的 Java 服务 Dockerfile 示例：

```dockerfile
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY target/linux-server-0.0.1-SNAPSHOT.jar app.jar
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### 构建镜像

```bash
docker build -t linux-server:0.0.1 .
```

### 运行镜像

```bash
docker run -d --name linux-server -p 8081:8081 linux-server:0.0.1
```

## 七、Docker Compose 常用命令

当前新版本命令一般写成：

```bash
docker compose up
```

而不是旧写法：

```bash
docker-compose up
```

### 1. 启动服务

```bash
docker compose up
```

后台启动：

```bash
docker compose up -d
```

### 2. 停止服务

```bash
docker compose stop
```

### 3. 停止并删除容器、网络

```bash
docker compose down
```

### 4. 查看服务状态

```bash
docker compose ps
```

### 5. 查看日志

```bash
docker compose logs
```

持续查看：

```bash
docker compose logs -f
```

只看某个服务：

```bash
docker compose logs -f mysql
docker compose logs -f linux-server
```

### 6. 重新构建并启动

```bash
docker compose up -d --build
```

### 7. 重启某个服务

```bash
docker compose restart linux-server
```

### 8. 进入某个服务容器

```bash
docker compose exec linux-server /bin/sh
docker compose exec mysql mysql -uroot -p
```

## 八、当前阶段推荐学习顺序

结合你当前项目背景，推荐顺序：

1. 先熟悉 `docker pull / images / ps / run / stop / rm / logs / exec`
2. 再练端口映射、环境变量、数据卷
3. 再练 `Dockerfile`
4. 再学 `docker compose`
5. 最后再用 `linux-server + mysql` 做第一版容器化

## 九、结合当前项目的学习建议

当前不建议立刻把服务器上已可用的服务全部切到 Docker。

更稳的方式是：

1. 保留当前 `systemd + 目录部署` 可用版本
2. 域名好后先把现有版本完善并完成正式验证
3. 再新开一套 Docker 演练目录
4. 先从 `mysql + linux-server` 开始做 Compose
5. 再逐步把 `easy-chat`、`music-api`、`nginx` 纳入容器化

## 十、后续可继续补的专题

- Dockerfile 多阶段构建
- Docker Compose 编排 Node / Java / MySQL / Nginx
- Docker 日志与数据持久化
- 容器网络
- 镜像优化
- 私有镜像仓库
- Docker 与现有 `systemd` 部署方式对比
