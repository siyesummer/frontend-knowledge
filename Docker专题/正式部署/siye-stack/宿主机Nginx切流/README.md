# 宿主机 Nginx 分阶段切换到 Docker edge

这个包保留宿主机 Nginx 对公网 `80/443` 的占用，只将已验收的 `siyes.cn` Host 代理到 Docker edge：

```text
浏览器 -> 宿主机 Nginx :80/:443 -> https://127.0.0.1:18443 -> Docker edge -> 业务容器
```

宿主机 Nginx 与 Docker edge 之间仍使用 HTTPS，并按原始 Host 执行 SNI 和证书校验。新配置会保留 Host、真实客户端 IP、转发协议和 WebSocket 升级头。

## 路由范围

下列 8 个 Host 代理到 Docker edge：

- `siyes.cn`
- `www.siyes.cn`
- `music.siyes.cn`
- `music-api.siyes.cn`
- `linux-api.siyes.cn`
- `socket.siyes.cn`
- `sub2api.siyes.cn`
- `draw.siyes.cn`

`knowledge.siyes.cn` 由宿主机 Nginx 直接返回带有有效通配符证书的 `503 pending`，不会在应用未部署时误代理到其他项目。

## 脚本边界

- `prepare.sh`：安装候选配置并做隔离语法检查；不创建 `sites-enabled` 软链接，不重载 Nginx。
- `cutover.sh`：备份 `/etc/nginx`，只禁用 4 个已知冲突软链接，启用新配置，检查、重载并验收。任何一步失败都会自动恢复原软链接。
- `rollback.sh`：使用切换时保存的状态手动回滚。

脚本不停止、重启、禁用或修改 `music-api.service`、`linux-server.service`、`easy-chat.service`；只通过 `systemctl is-active` 检查它们的状态。

v2 会在宿主机 Nginx 重载后最多等待 20 秒，直到新 worker 已经对 `siyes.cn` 提供通配符证书和正确主站内容，再执行完整验收。这避免在优雅重载的短暂交接期误命中旧 worker。

## 上传

在 Windows PowerShell 执行：

```powershell
scp "$env:TEMP\siye-host-nginx-cutover-20260721-v2.tar.gz" ubuntu@203.0.113.10:/tmp/
```

在服务器执行：

```bash
cd /tmp
sha256sum siye-host-nginx-cutover-20260721-v2.tar.gz
install -d -m 700 /tmp/siye-host-nginx-cutover-20260721-v2
tar -xzf siye-host-nginx-cutover-20260721-v2.tar.gz \
  -C /tmp/siye-host-nginx-cutover-20260721-v2
cd /tmp/siye-host-nginx-cutover-20260721-v2
chmod 700 prepare.sh cutover.sh rollback.sh
chmod 644 siyes-docker-edge.conf README.md SHA256SUMS
sha256sum -c SHA256SUMS
bash -n prepare.sh cutover.sh rollback.sh
```

## 第一阶段：只预检

首次只执行：

```bash
cd /tmp/siye-host-nginx-cutover-20260721-v2
sudo ./prepare.sh
```

这一步的预期结果是：

- 候选文件安装到 `/etc/nginx/sites-available/siyes-docker-edge`。
- `/etc/nginx/sites-enabled/siyes-docker-edge` 仍不存在。
- 宿主机 Nginx 没有重载，公网流量不变。
- 输出 4 个已知冲突软链接及当前 `server_name` 定义，供切换前人工复核。

先贴回 `prepare.sh` 的完整输出，复核通过后再执行 `cutover.sh`。

## 第二阶段：切换

仅在预检输出复核通过后执行：

```bash
cd /tmp/siye-host-nginx-cutover-20260721-v2
sudo ./cutover.sh
```

切换备份位于：

```text
/opt/siye-production/backups/host-nginx-cutover-YYYYMMDD-HHMMSS/
```

包含 `/etc/nginx` 完整归档、解析后配置、Docker edge 状态和 4 个受管软链接的原始目标。

## 手动回滚

使用最近一次切换保存的状态：

```bash
cd /tmp/siye-host-nginx-cutover-20260721-v2
sudo ./rollback.sh
```

或指定备份目录：

```bash
sudo ./rollback.sh \
  /opt/siye-production/backups/host-nginx-cutover-YYYYMMDD-HHMMSS
```

`rollback.sh` 只恢复这次切换管理的软链接，不盲目覆盖整个 `/etc/nginx`。完整归档仅用于严重故障时的人工恢复与审计。
