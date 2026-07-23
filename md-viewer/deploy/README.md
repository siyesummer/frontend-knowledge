# knowledge.siyes.cn 生产部署

该目录用于把 `md-viewer` 部署为单个生产容器。容器同时提供前端静态文件、`/api/*` 和 `/ws`，只加入现有 `siye-prod-edge-net`，不发布宿主机端口。

## 首次启动

服务器仓库固定放在 `/opt/frontend-knowledge`：

```bash
sudo install -d -o ubuntu -g ubuntu -m 755 /opt/frontend-knowledge
sudo -u ubuntu git clone \
  https://github.com/siyesummer/frontend-knowledge.git \
  /opt/frontend-knowledge

cd /opt/frontend-knowledge/md-viewer/deploy
cp .env.example .env
chmod 600 .env

sudo docker network inspect siye-prod-edge-net >/dev/null
sudo docker compose --env-file .env -f compose.yml config --quiet
sudo docker compose --env-file .env -f compose.yml build
sudo docker compose --env-file .env -f compose.yml up -d
```

检查容器和应用：

```bash
sudo docker inspect \
  --format 'name={{.Name}} status={{.State.Status}} health={{.State.Health.Status}}' \
  siye-prod-knowledge

sudo docker exec siye-prod-knowledge \
  node -e "fetch('http://127.0.0.1:3001/health').then(async r => { console.log(await r.text()); process.exit(r.ok ? 0 : 1) }).catch(err => { console.error(err); process.exit(1) })"
```

## 启用 `knowledge.siyes.cn`

应用容器健康后，再更新正式 edge 的配置。配置源文件位于仓库的 `Docker专题/正式部署/siye-stack/edge/nginx/`，服务器生效目录通常为 `/opt/siye-production/edge/nginx/`。

本次配置包含：

- `upstreams.conf` 新增 `knowledge:3001` 的 `knowledge_upstream`
- `sites-http.conf` 和 `sites-https.conf` 将 `knowledge.siyes.cn` 从 `503 pending` 改为代理
- `/ws` 使用独立的长连接超时，普通页面和 API 使用普通代理超时

替换前先备份服务器当前 edge 配置，然后执行：

```bash
sudo docker exec siye-prod-edge-nginx nginx -t
sudo docker exec siye-prod-edge-nginx nginx -s reload
```

验证入口：

```bash
curl --fail --silent --show-error https://knowledge.siyes.cn/health
curl --fail --silent --show-error https://knowledge.siyes.cn/api/tree | head -c 500
echo
```

如果 edge 配置验证失败，恢复备份的三个 Nginx 配置文件，再重复 `nginx -t` 和平滑重载；不要停止整个正式 Docker 栈。

## 日常更新

只更新知识资料时，容器能通过只读挂载和 chokidar 直接看到 `git pull` 产生的文件变化：

```bash
cd /opt/frontend-knowledge
git pull --ff-only origin main
```

修改 `md-viewer` 前端、Node 服务或依赖后，需要重建容器：

```bash
cd /opt/frontend-knowledge
git pull --ff-only origin main

cd md-viewer/deploy
sudo docker compose --env-file .env -f compose.yml build
sudo docker compose --env-file .env -f compose.yml up -d
```

不要对正式服务器执行无差别的 `docker system prune` 或 `docker volume prune`。
