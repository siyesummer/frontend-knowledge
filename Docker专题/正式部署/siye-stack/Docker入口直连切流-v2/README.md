# Docker edge 直占公网 80/443 v2

这个包先同步 Docker edge 缺失的 `knowledge.siyes.cn` 配置，再把公网入口从宿主机 Nginx 切到 Docker edge。

当前链路：

```text
浏览器 -> 宿主机 Nginx :80/:443 -> 127.0.0.1:18443 -> Docker edge
```

目标链路：

```text
浏览器 -> Docker edge :80/:443 -> Docker 业务容器
```

## 执行顺序

1. `install-edge-config.sh`：隔离校验并安装 `sites-https.conf`，只重建并行 Docker edge；宿主机 Nginx 始终保持运行。
2. `prepare.sh`：只读验证当前链路与公网端口候选配置。
3. `cutover.sh`：备份状态、停止宿主机 Nginx、让 Docker edge 直占 `80/443` 并完整验收。
4. `rollback.sh`：需要时恢复 `127.0.0.1:18080/18443` 和宿主机 Nginx。

所有脚本都不删除 `/etc/nginx`、证书、数据库、旧服务目录或数据卷。Certbot 仍由宿主机定时器运行，续期部署 Hook 继续直接重载 `siye-prod-edge-nginx`。

## 上传后校验

```bash
cd /tmp/siye-docker-edge-direct-cutover-v2
chmod 700 *.sh
chmod 600 README.md SHA256SUMS sites-https.conf
sha256sum -c SHA256SUMS
bash -n common.sh install-edge-config.sh prepare.sh cutover.sh rollback.sh
```

## 第一步：补齐 Docker edge Host

```bash
sudo ./install-edge-config.sh
```

成功后宿主机 Nginx仍占用公网 `80/443`，Docker edge 仍绑定 `127.0.0.1:18080/18443`。

## 第二步：重新预检

```bash
sudo ./prepare.sh
```

## 第三步：正式切换

仅在预检全部通过后执行：

```bash
sudo ./cutover.sh
```

成功后宿主机 `nginx.service` 为 `stopped/disabled`，Docker edge 直接绑定 `0.0.0.0:80/443`。

## 回滚

使用 `cutover.sh` 输出的备份目录：

```bash
sudo ./rollback.sh \
  /opt/siye-production/backups/docker-edge-direct-cutover/YYYYMMDD-HHMMSS
```
