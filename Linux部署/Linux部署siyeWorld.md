# Linux 部署 siyeWorld

## 当前目标

接下来在腾讯云 `Ubuntu 24.04 LTS` 服务器上继续部署 `siyeWorld` 项目，并逐步替代或复刻原先 Windows 服务器上的部署思路。

项目地址：
[https://github.com/siyesummer/siyeWorld](https://github.com/siyesummer/siyeWorld)

结合当前仓库中已有信息，`siyeWorld` 相关线上能力主要包括：

- 音乐播放器主站：`siyefun.top`
- 网易云音乐接口服务：`api.siyefun.top`
- Socket 服务：`siyefun.top:3030`

当前已经为 Linux 服务器解析好的练习域名：

- `music.siyefun.top`
- `music-api.siyefun.top`
- `socket.siyefun.top`

腾讯云 Linux 后续统一迁移到 `siyes.cn` 域名体系：

- `music.siyes.cn`
- `music-api.siyes.cn`
- `sub2api.siyes.cn`
- `socket.siyes.cn`

当前实际进展补充：

- `music-api.siyefun.top` 对应的 Linux API 服务已经完成基础部署验证
- 使用的项目为 `NeteaseCloudMusicApi@4.13.8`
- API 已经在服务器上成功启动，并监听 `3000` 端口
- 已通过 `curl http://127.0.0.1:3000` 验证服务本体可用
- 已通过 `curl -H "Host: music-api.siyefun.top" http://127.0.0.1/...` 验证 Nginx 反向代理链路可用
- `music-api.service` 已创建完成，并已由 `systemd` 成功托管
- 当前 `music-api` 已启用开机自启
- 腾讯云接入备案仍在审核中，因此 `music-api.siyefun.top` 的公网 HTTPS 暂未继续处理

### music-api.siyes.cn 迁移进展

新域名使用独立 Nginx 配置：

```text
/etc/nginx/sites-available/music-api.siyes.cn
```

后端服务本身没有更换，仍然使用：

```text
music-api.siyes.cn -> Nginx -> 127.0.0.1:3000 -> music-api.service
```

当前已经验证：

- `music-api.siyes.cn` 解析到 `YOUR_SERVER_IP`
- 服务器本机带 `Host: music-api.siyes.cn` 请求返回 `200`
- 通过公网域名请求 `/search?keywords=test` 返回 `200`
- 本地 `localhost:8080` 前端真实请求已经到达新域名对应的 Nginx 访问日志
- CORS 预检 `OPTIONS /user/playlist` 返回 `204`
- 随后的 `POST /user/playlist` 返回 `200` 和 JSON 数据

访问日志中的成功链路示例：

```text
OPTIONS /user/playlist?... 204
POST /user/playlist?... 200
```

`GET /search` 曾出现：

```text
499
```

Nginx 的 `499` 表示客户端在服务端完成响应前主动断开，常见原因包括前端取消请求、
搜索请求被新请求替换或客户端超时。它不表示 DNS、Nginx 站点匹配或反向代理没有生效。

当前 HTTPS 仍受 ICP 备案/DNSPod 拦截影响，证书签发待域名公网验证恢复后处理。

## 推荐部署顺序

为了降低复杂度，推荐不要一上来把整套服务一次性全搬过去，而是按三阶段推进：

1. 先部署主站前端静态资源
2. 再部署 `api.siyefun.top` 对应的后端接口服务
3. 最后部署 Socket 服务并接入 Nginx / 域名 / 端口策略

这个顺序更适合在 Linux 上学习完整链路，也更方便逐步定位问题。

## 为什么要分阶段

`siyeWorld` 和 `svg-draw` 不同，`svg-draw` 基本只是静态站点，而 `siyeWorld` 目前至少涉及三类能力：

- 静态前端页面
- API 服务
- 长连接 / Socket 服务

如果一次性迁移，问题来源会混在一起，不利于学习和排查。

## 第一阶段：部署主站前端

这一阶段的目标是：

- 先让 Linux 服务器可以对外访问一个新的 `siyeWorld` 前端页面
- 先验证 Linux 下的构建产物部署、Nginx 站点配置、HTTPS 流程

### 推荐域名策略

由于当前 `siyefun.top` 可能仍承载旧线上服务，当前建议先使用已经解析到 Linux 的练习域名进行验证：

- `music.siyefun.top`
- `music-api.siyefun.top`
- `socket.siyefun.top`

建议用途：

- `music.siyefun.top`：先用于 `siyeWorld` 前端静态站点
- `music-api.siyefun.top`：后续用于 Linux 上的 API 服务
- `socket.siyefun.top`：后续用于 Linux 上的 Socket 服务验证

等 Linux 侧完整验证稳定后，再决定是否切换正式域名。

### 前提条件

- 本地已经能构建出 `siyeWorld` 前端产物
- 已有一个新的二级域名解析到腾讯云 Ubuntu 服务器
- 腾讯云安全组已放行 `80` 和 `443`
- Nginx 已在服务器上安装完成

### 推荐目录

```bash
/var/www/siyeWorld
```

如果只是前端产物，可按下面结构：

```bash
/var/www/siyeWorld/dist
```

### 基础部署思路

和 `svg-draw` 很像：

1. 本地打包前端
2. 通过 `scp` 上传 `dist`
3. 在 `/etc/nginx/sites-available/` 新建站点配置
4. 通过 `sites-enabled` 启用
5. 先跑通 HTTP，再申请 HTTPS

### 站点配置示例

当前前端推荐直接使用 `music.siyefun.top`：

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name music.siyefun.top;

    root /var/www/siyeWorld/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

如果项目是单页应用，这里的 `try_files` 仍然很重要。

## 第二阶段：部署 API 服务

根据仓库中的历史信息，原有接口域名为：

```text
api.siyefun.top
```

本地私有配置中也使用了类似的 Nginx 规则；公开仓库只保留脱敏后的示例：

```nginx
server {
    listen 80;
    server_name api.siyefun.top;

    location / {
        proxy_pass http://localhost:3000;
    }
}
```

这说明旧环境中的 API 大概率是：

- 由某个本地服务进程监听 `3000`
- 再由 Nginx 做反向代理对外暴露

### Linux 侧推荐思路

如果你准备把 API 也迁到 Linux，推荐继续保持这种结构：

- 应用进程监听本机端口，例如 `127.0.0.1:3000`
- Nginx 监听 `api.siyefun.top`
- 由 Nginx 统一处理 HTTPS、域名和代理头

### Nginx 反向代理示例

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name music-api.siyefun.top;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 这一步要额外掌握

- 服务如何启动
- 服务如何后台常驻
- 服务挂了如何重启
- 日志如何查看

如果该 API 仍是 Node 项目，后续就会自然进入：

- `node`
- `npm`
- `pm2` 或 `systemd`

这一步比静态站点更接近真实后端部署。

### 当前这次 API 实际部署记录

当前采用的项目：

- `NeteaseCloudMusicApi@4.13.8`

当前服务器目录：

```bash
/opt/music-api/NeteaseCloudMusicApi-4.13.8
```

当前 `package.json` 中已确认的启动命令：

```json
"start": "node app.js"
```

因此当前可用启动方式为：

```bash
cd /opt/music-api/NeteaseCloudMusicApi-4.13.8
npm start
```

### 当前已完成的 API 验证

已确认 Node 进程监听：

```bash
ss -lntp | grep 3000
```

已得到类似结果：

```text
LISTEN ... *:3000 ...
```

已验证服务本体可用：

```bash
curl http://127.0.0.1:3000
```

已验证真实接口可用：

```bash
curl "http://127.0.0.1:3000/search?keywords=海阔天空"
```

已验证 Nginx 反向代理链路可用：

```bash
curl -H "Host: music-api.siyefun.top" http://127.0.0.1/search?keywords=海阔天空
```

当前返回结果示例：

```json
{"result":{"songCount":0},"code":200}
```

这说明当前已经跑通：

```text
music-api.siyefun.top -> Nginx -> 127.0.0.1:3000 -> NeteaseCloudMusicApi
```

### 当前 API 服务状态

当前 `systemd` 服务名：

```bash
music-api.service
```

当前已确认：

- `sudo systemctl status music-api` 显示 `active (running)`
- `sudo systemctl is-enabled music-api` 显示 `enabled`
- 启动日志中可见：

```text
server running @ http://localhost:3000
```

- `sudo nginx -t` 已通过

这说明当前 API 服务已经不是临时手动运行状态，而是已经切换为 Linux 服务器上的正式常驻服务。

### 当前 API 站点配置示例

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name music-api.siyefun.top;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## API 常驻化建议

由于当前服务器 Node 环境通过 `nvm` 安装，建议后续使用 `systemd + node app.js` 常驻，而不是长期手动开着 `npm start` 窗口。

当前服务器 `node` 路径已经确认：

```bash
/home/ubuntu/.nvm/versions/node/v20.0.0/bin/node
```

推荐的 `systemd` 配置文件：

文件位置：

```bash
/etc/systemd/system/music-api.service
```

内容示例：

```ini
[Unit]
Description=music-api
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/music-api/NeteaseCloudMusicApi-4.13.8
ExecStart=/home/ubuntu/.nvm/versions/node/v20.0.0/bin/node app.js
Restart=always
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
```

生效方式：

```bash
sudo systemctl daemon-reload
sudo systemctl enable music-api
sudo systemctl start music-api
sudo systemctl status music-api
```

日志查看：

```bash
journalctl -u music-api -f
```

如果 `systemd` 启动成功，再停止原先手动执行的 `npm start` 进程即可。

### 当前阶段结论

`music-api.siyefun.top` 这条 Linux API 迁移线，当前已经完成的核心闭环包括：

1. 项目代码上传到 Linux 服务器
2. Node 环境与依赖可正常运行
3. `NeteaseCloudMusicApi@4.13.8` 服务本体跑通
4. `127.0.0.1:3000` 端口跑通
5. Nginx 反向代理跑通
6. `systemd` 常驻和开机自启跑通

当前剩余事项主要是：

1. 腾讯云接入备案审核通过
2. 为 `music-api.siyefun.top` 申请并启用 HTTPS
3. 进行公网最终验证

## 第三阶段：部署 Socket 服务

当前已知旧环境中存在：

```text
siyefun.top:3030
```

这说明历史上 Socket 服务可能是直接监听对外端口 `3030`。

当前补充情况：

- `socket.siyefun.top` 已经解析到 Linux 服务器
- 这为后续把 Socket 服务从“端口直连”逐步过渡到“独立子域名接入”提供了条件
- 本次已确认 Socket 服务对应项目可从 `siyeWorld` 中单独拆出，作为独立服务部署
- 当前采用的服务目录为 `/opt/easy-chat`
- 当前主要测试入口仍是 `YOUR_SERVER_IP:3030`

### Linux 侧建议

这一步建议先不要急着照搬“公网直接暴露 3030”。

更推荐分两种学习路径：

1. 先保留 `3030` 端口直连，快速跑通
2. 后续再研究是否通过 Nginx 反向代理 WebSocket，统一走 `443`

### 先跑通时的重点

- 服务进程是否真的监听 `3030`
- 腾讯云安全组是否放行 `3030`
- 如果启用了 `ufw`，是否同步放行 `3030`

### 后续更接近生产的思路

如果 Socket 基于 WebSocket，后续更推荐研究：

- `https://siyefun.top/socket`
- 或 `wss://...`
- 由 Nginx 统一做反向代理

如果当前希望先快速验证单独子域名，也可以优先研究：

- `socket.siyefun.top`
- `ws://socket.siyefun.top`
- 后续备案与 HTTPS 条件满足后再升级到 `wss://socket.siyefun.top`

这样会更接近真实线上部署方式，也能减少额外暴露的公网端口。

### 当前这次 Socket 实际部署记录

当前采用的项目：

- `siyeWorld/packages/easy-chat`

本地源码位置：

```text
E:\本地项目\siyeWorld\packages\easy-chat
```

当前 Linux 服务器目录：

```bash
/opt/easy-chat
```

当前 `package.json` 中已确认的启动命令：

```json
"start-server": "node server.js"
```

因此当前可用启动方式为：

```bash
cd /opt/easy-chat
npm run start-server
```

### 当前 Socket 配置记录

当前服务器配置文件：

```bash
/opt/easy-chat/config/index.js
```

当前关键配置为：

```js
const LISTENING_PORT = '3030';
const SERVER_HOST = 'YOUR_SERVER_IP';

module.exports = {
  LISTENING_PORT,
  CONNECT_URL: `http://${SERVER_HOST}:${LISTENING_PORT}`,
  SOCKET_ORIGIN: `http://${SERVER_HOST}:8080`,
};
```

这里的重点是：

- 服务端当前仍以公网 IP `YOUR_SERVER_IP` 为主要联调入口
- `CONNECT_URL` 当前使用 `http://...`，方便 `socket.io-client` 直接连接
- 后续如果要切到 `socket.siyefun.top`，这里需要连同本地前端配置一起切换

### 当前已完成的 Socket 验证

已确认服务启动成功，启动日志可见：

```text
listening on *:3030
socket.io代理到listening on *:http://YOUR_SERVER_IP:3030
```

已确认端口监听：

```bash
ss -lntp | grep 3030
```

已确认本地 `siyeWorld` 前端能够连到 Linux Socket 服务，`journalctl` 中可见类似日志：

```text
socket.io client connected: <socket-id>
socket.io链接成功
```

这说明当前已经跑通：

```text
本地 siyeWorld 前端 -> YOUR_SERVER_IP:3030 -> /opt/easy-chat Socket 服务
```

### 当前 Socket 服务状态

当前 `systemd` 服务名：

```bash
easy-chat.service
```

当前已确认：

- `sudo systemctl status easy-chat` 显示 `active (running)`
- `sudo systemctl enable easy-chat` 已完成开机自启
- 启动进程为 `/home/ubuntu/.nvm/versions/node/v20.0.0/bin/node server.js`
- `journalctl -u easy-chat -f` 可持续观察连接日志

这说明当前 Socket 服务已经从手动前台运行，切换为 Linux 服务器上的正式常驻服务。

### socket.siyes.cn 新域名迁移结果

为统一腾讯云 Linux 服务器域名，Socket 服务新增了独立站点：

```text
socket.siyes.cn -> Nginx -> 127.0.0.1:3030 -> easy-chat.service
```

新站点配置文件：

```bash
/etc/nginx/sites-available/socket.siyes.cn
```

当前 Nginx 配置需要保留 Socket.IO/WebSocket 代理头：

```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_buffering off;
proxy_read_timeout 600s;
proxy_send_timeout 600s;
```

当前已完成验证：

- `socket.siyes.cn` 已解析到 `YOUR_SERVER_IP`
- `curl http://127.0.0.1/health -H "Host: socket.siyes.cn"` 返回 `200`
- `curl http://socket.siyes.cn/health` 返回 `200`
- `/socket.io/?EIO=4&transport=polling` 返回 `200`
- Engine.IO 返回 `sid`，并声明支持 `websocket` 升级

Socket.IO 握手响应示例：

```text
0{"sid":"...","upgrades":["websocket"],"pingInterval":25000,"pingTimeout":5000}
```

这说明新域名的 HTTP 代理和 Socket.IO polling 握手已经跑通。下一步是将本地
`siyeWorld` 前端的 `CONNECT_URL` 从本地/公网 IP 切换为：

```text
http://socket.siyes.cn
```

备案通过、域名访问拦截解除后，再为 `socket.siyes.cn` 申请 HTTPS。届时前端地址
切换为 `https://socket.siyes.cn`，Socket.IO 会自动使用安全 WebSocket。

### Socket 域名公网拦截结果

本地浏览器通过 `socket.siyes.cn` 发起 Socket.IO polling 请求时，实际返回：

```text
HTTP 302
Location: https://dnspod.qcloud.com/static/webblock.html?d=socket.siyes.cn
```

这表示请求在 DNSPod/备案访问层被拦截，没有进入当前服务器的 Nginx。
服务器内部使用 `Host: socket.siyes.cn` 的测试仍然返回 `200`，只能证明服务器
本地链路正确，不能绕过公网域名的备案拦截。

备案完成前，本地前端临时使用：

```text
http://YOUR_SERVER_IP:3030
```

本地浏览器通过 IP 直连时，Socket.IO polling 请求已验证返回：

```text
POST /socket.io/?EIO=4&transport=polling... 200 OK
```

响应中包含 `Access-Control-Allow-Origin: *`，说明跨域请求未被浏览器拦截。
由于请求地址带有 `:3030`，这次测试是直接访问 Node 服务，绕过了 Nginx 和域名
备案拦截，只能证明 `easy-chat` 的公网端口和 Socket.IO 服务本体可用。

备案通过后再切换回：

```text
http://socket.siyes.cn
```

### 当前 Socket 域名接入状态

当前已经完成：

- `/etc/nginx/sites-available/socket.siyefun.top` 站点配置已创建
- 已创建到 `/etc/nginx/sites-enabled/socket.siyefun.top` 的软链接
- `sudo nginx -t` 已通过
- `sudo systemctl reload nginx` 已执行

但当前暂不切换为正式入口，原因是：

- `socket.siyefun.top` 对应域名当前仍受备案/访问拦截影响
- 即使 Nginx 代理已预配置，也不适合现在作为主要联调入口

因此当前阶段建议保持：

1. 服务内部继续监听 `3030`
2. 本地前端继续先连 `YOUR_SERVER_IP:3030`
3. 等域名公网访问恢复正常后，再切换到 `socket.siyefun.top`
4. 后续再进一步升级到 HTTPS/WSS

### 当前阶段结论

`easy-chat` 这条 Linux Socket 迁移线，当前已经完成的核心闭环包括：

1. 从 `siyeWorld` 中识别并拆出独立 Socket 服务
2. 将项目上传到 Linux 服务器 `/opt/easy-chat`
3. 通过 `npm run start-server` 跑通服务本体
4. 验证 `3030` 端口监听正常
5. 使用本地前端联调确认真实连接成功
6. 完成 `easy-chat.service` 的 `systemd` 常驻和开机自启
7. 提前完成 `socket.siyefun.top` 的 Nginx 代理预配置

当前剩余事项主要是：

1. 等待 `socket.siyefun.top` 域名侧访问恢复正常
2. 将本地与服务端连接地址从 IP 切换到域名
3. 视备案与证书条件补齐 HTTPS / WSS

## 推荐的 Linux 迁移策略

对你当前阶段，我建议这样安排：

1. 先在 Linux 上部署 `siyeWorld` 前端静态页
2. 用 `music.siyefun.top` 先验证完整 HTTP / HTTPS 流程
3. 再确定 API 项目的启动方式和依赖
4. 把 API 部署到 Linux 并通过 `music-api.siyefun.top` 验证
5. 最后再处理 Socket 服务

## 这次最值得先确认的事情

在真正开始动手前，建议你先明确下面三件事：

1. `siyeWorld` 前端本地是否已经可以成功打包
2. API 服务的源码、启动命令、运行时环境是否已经清楚
3. Socket 服务是独立项目、独立进程，还是 `siyeWorld` 项目内的一部分

## 当前最适合的下一步

最建议你先做的是：

1. 确定一个新的 Linux 练习域名
2. 先只部署 `siyeWorld` 前端到 `music.siyefun.top`
3. 跑通 `music.siyefun.top` 的 Nginx + HTTPS
4. 当前 `music-api.siyefun.top` 的 API 基础链路和 `systemd` 常驻都已跑通，下一步优先等待备案通过后补 HTTPS
5. 再继续 `music.siyefun.top` 前端主站或 Socket 服务

## 后续文档可继续补充

这份文档后续可以继续补充：

- `siyeWorld` 前端真实部署路径
- 当前 Linux 前端域名 `music.siyefun.top`
- 当前 Linux API 域名 `music-api.siyefun.top`
- 当前 Linux Socket 域名 `socket.siyefun.top`
- API 启动命令
- API `systemd` 常驻方式
- API HTTPS 启用时间点与备案状态
- Socket 启动命令
- `systemd` / `pm2` 管理方式
- 最终的 Nginx 配置
