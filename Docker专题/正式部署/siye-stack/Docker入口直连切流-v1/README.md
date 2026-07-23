# Docker edge 直接占用公网 80/443

当前正式链路是：

```text
浏览器 -> 宿主机 Nginx :80/:443 -> 127.0.0.1:18443 -> Docker edge -> Docker 服务
```

本包用于最后一步切换：让 Docker edge 直接监听公网 `0.0.0.0:80` 和 `0.0.0.0:443`，然后停止并禁用宿主机 `nginx.service`。

切换会有一个很短的端口交接窗口。脚本先验证候选 Compose 配置，再停止宿主机 Nginx；验证失败会自动恢复原来的 `127.0.0.1:18080/18443` 配置并重新启动宿主机 Nginx。

## 重要边界

- 不删除 `/etc/nginx`、`sites-available`、证书或宿主机 Nginx 软件。
- 不修改 Docker 业务容器、数据库、旧 MySQL 或旧数据。
- Certbot 仍由宿主机 `certbot.timer` 执行；续期 Hook 直接重载 `siye-prod-edge-nginx`。
- Docker edge 必须继续挂载整个 `/etc/letsencrypt`，不能只挂载 `live/siyes-production`。
- 当前 DNS 只有 A 记录时，`0.0.0.0:80/443` 足够；如果以后新增 AAAA 记录，需要另行确认 IPv6 监听方案。

## 上传和校验

在 Windows PowerShell 执行：

```powershell
scp -r "E:\本地项目\frontend-knowledge\Docker专题\正式部署\siye-stack\docker-edge-direct-cutover" `
  ubuntu@203.0.113.10:/tmp/
```

服务器执行：

```bash
cd /tmp/docker-edge-direct-cutover
chmod 700 *.sh
sha256sum -c SHA256SUMS
bash -n common.sh prepare.sh cutover.sh rollback.sh
```

## 第一阶段：只预检

```bash
cd /tmp/docker-edge-direct-cutover
sudo ./prepare.sh
```

预检不会停止、重载或禁用宿主机 Nginx，也不会修改 `/opt/siye-production/edge/.env`。

预期会验证：

- 当前宿主机 Nginx 配置和状态正常。
- Docker edge 当前 `127.0.0.1:18443` HTTPS 路由、证书、HTTP 跳转和 Socket.IO 正常。
- 将要使用的 `0.0.0.0:80/443` Compose 配置可以解析。

## 第二阶段：直接切换

确认 `prepare.sh` 输出正常后执行：

```bash
cd /tmp/docker-edge-direct-cutover
sudo ./cutover.sh
```

切换成功后：

```text
Docker edge -> 0.0.0.0:80/443
宿主机 nginx.service -> stopped/disabled
旧 18080/18443 -> 不再监听
```

切换备份位于：

```text
/opt/siye-production/backups/docker-edge-direct-cutover/YYYYMMDD-HHMMSS
```

## 手动回滚

```bash
cd /tmp/docker-edge-direct-cutover
sudo ./rollback.sh \
  /opt/siye-production/backups/docker-edge-direct-cutover/YYYYMMDD-HHMMSS
```

回滚会恢复 edge 的 `127.0.0.1:18080/18443`，重新启用并启动宿主机 Nginx；原配置和证书不会删除。
