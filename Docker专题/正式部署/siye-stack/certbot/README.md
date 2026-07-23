# Certbot DNSPod 自动续期 Hook

这组脚本用于续期 `/etc/letsencrypt/live/siyes-production/` 的 `siyes.cn + *.siyes.cn` 证书。

- `certbot-dnspod-auth`：通过 DNSPod API 创建 `_acme-challenge` TXT。
- `certbot-dnspod-cleanup`：按 API 返回的 record ID 删除本次 TXT。
- `reload-siye-edge`：证书真正续期后执行 `nginx -t` 并平滑重载 `siye-prod-edge-nginx`。
- `install-hooks.sh`：校验 `/etc/letsencrypt/dnspod.env` 权限并安装三个 Hook。

上传包不包含 DNSPod Token。服务器必须预先创建权限为 `600 root:root` 的 `/etc/letsencrypt/dnspod.env`：

```bash
DNSPOD_LOGIN_TOKEN='ID,Token'
DNSPOD_DOMAIN='siyes.cn'
DNSPOD_PROPAGATION_SECONDS='120'
```

安装：

```bash
sudo bash install-hooks.sh
```

不要直接执行认证或清理 Hook。它们依赖 Certbot 注入的 `CERTBOT_DOMAIN`、`CERTBOT_VALIDATION` 和 `CERTBOT_REMAINING_CHALLENGES`。
