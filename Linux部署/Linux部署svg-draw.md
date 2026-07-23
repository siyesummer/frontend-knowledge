# Linux 部署 svg-draw

## 当前状态

`svg-draw` 已经在腾讯云 `Ubuntu 24.04 LTS` 服务器上完成了第一阶段部署：

- 本地打包好的 `dist` 已上传到服务器
- 站点目录已经创建完成
- Nginx 站点配置文件已创建
- Nginx 已重载并生效
- `http://draw.siyefun.top` 已可以正常访问新页面
- `https://draw.siyefun.top` 已申请并启用成功，可以正常访问

当前实际使用的信息：

- 域名：`draw.siyefun.top`
- 站点目录：`/var/www/svg-draw/dist`
- Nginx 站点配置：`/etc/nginx/sites-available/draw.siyefun.top`

下一步重点：

1. 复盘这次静态站点部署流程
2. 复盘 HTTPS 证书申请与 Nginx 自动配置过程
3. 将 Linux 服务逐个迁移到 `siyes.cn` 域名体系
4. 后续再对比 Docker 部署方式

## 迁移到 siyes.cn 域名体系

为了统一腾讯云 Linux 服务器上的访问入口，`svg-draw` 已从原 Linux 练习域名
`draw.siyefun.top` 增加了新的目标域名 `draw.siyes.cn`。

当前迁移原则是新旧配置并存，先验证新域名，再决定是否停用旧域名：

- 原域名 `draw.siyefun.top` 的配置和 HTTPS 证书暂时保留
- 新域名 `draw.siyes.cn` 使用独立的 Nginx 站点配置
- 新域名继续复用 `/var/www/svg-draw/dist` 静态文件
- ICP 备案通过后，再为 `draw.siyes.cn` 申请 HTTPS

### 新域名当前状态

- DNS：`draw.siyes.cn -> YOUR_SERVER_IP`
- Nginx 配置：`/etc/nginx/sites-available/draw.siyes.cn`
- 静态目录：`/var/www/svg-draw/dist`
- HTTP：已返回 `200 OK`
- SPA 路由：`/test-route` 已正确回退到 `index.html`
- HTTPS：等待 ICP 备案通过后配置

### 新域名 Nginx 配置

```nginx
server {
    listen 80;
    listen [::]:80;

    server_name draw.siyes.cn;

    root /var/www/svg-draw/dist;
    index index.html;

    access_log /var/log/nginx/draw.siyes.cn.access.log;
    error_log /var/log/nginx/draw.siyes.cn.error.log;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

启用新站点：

```bash
sudo ln -s /etc/nginx/sites-available/draw.siyes.cn \
  /etc/nginx/sites-enabled/draw.siyes.cn
sudo nginx -t
sudo systemctl reload nginx
```

### 新域名验证命令

检查 DNS：

```bash
nslookup draw.siyes.cn
```

检查首页响应：

```bash
curl -I http://draw.siyes.cn
```

检查首页内容：

```bash
curl -s http://draw.siyes.cn | head -n 30
```

检查前端路由回退：

```bash
curl -I http://draw.siyes.cn/test-route
```

当前已验证：

```text
draw.siyes.cn -> YOUR_SERVER_IP -> Nginx -> /var/www/svg-draw/dist
```

### 新域名 HTTPS 待办

ICP 备案通过、HTTP 公网访问稳定后，再申请证书：

```bash
sudo certbot --nginx -d draw.siyes.cn
sudo certbot renew --dry-run
```

证书申请成功后再验证：

```bash
curl -I https://draw.siyes.cn
```

### 新域名 HTTPS 首次申请结果

已实际执行：

```bash
sudo certbot --nginx -d draw.siyes.cn
```

申请失败的关键错误为：

```text
Invalid response from https://dnspod.qcloud.com/static/webblock.html?d=draw.siyes.cn
```

这说明 Let's Encrypt 的 HTTP-01 验证请求被 DNSPod 的域名访问拦截页接收，
没有到达当前服务器 `YOUR_SERVER_IP`。因此本次失败不是站点目录、Nginx
反向代理或 `certbot --nginx` 配置语法问题。

当前处理策略：

1. 暂不连续重复执行相同的 HTTP-01 申请命令
2. 等 ICP 备案和域名公网访问恢复后再次执行申请
3. 如果需要在拦截解除前签发证书，再研究 DNS-01 验证方式

## 这次部署的实际步骤

### 1. 安装 Nginx

```bash
sudo apt update
sudo apt install -y nginx
```

### 2. 创建站点目录

```bash
sudo mkdir -p /var/www/svg-draw
sudo chown -R ubuntu:ubuntu /var/www/svg-draw
```

### 3. 上传本地 dist

当前使用的是先在本地打包，再通过 `scp` 上传到服务器。

目标结果是：

```bash
/var/www/svg-draw/dist/index.html
```

上传完成后可以检查：

```bash
ls -la /var/www/svg-draw
ls -la /var/www/svg-draw/dist
```

### 4. 新建站点配置文件

Ubuntu 这台服务器的主配置文件 `/etc/nginx/nginx.conf` 中已经包含了：

```nginx
include /etc/nginx/sites-enabled/*;
```

因此更适合把具体站点单独拆到 `sites-available` 中管理，而不是直接把业务站点写进主配置。

创建配置文件：

```bash
sudo nano /etc/nginx/sites-available/draw.siyefun.top
```

配置内容：

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name draw.siyefun.top;

    root /var/www/svg-draw/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

说明：

- `server_name` 对应当前域名 `draw.siyefun.top`
- `root` 指向上传后的静态目录
- `try_files $uri $uri/ /index.html;` 用于支持前端单页应用刷新

### 5. 启用站点配置

```bash
sudo ln -s /etc/nginx/sites-available/draw.siyefun.top /etc/nginx/sites-enabled/draw.siyefun.top
```

检查配置：

```bash
sudo nginx -t
```

重载 Nginx：

```bash
sudo systemctl reload nginx
```

### 6. 配置 DNS 和安全组

已满足当前 HTTP 访问所需条件：

- `draw.siyefun.top` 已解析到当前腾讯云服务器公网 IP
- 腾讯云安全组已放行 `80` 端口

为了让 HTTPS 正常工作，还需要确认：

- 腾讯云安全组放行 `443`
- 如果启用了 `ufw`，也要同步放行 `443`

## 为什么这次是新建站点配置文件

这次没有直接改 `/etc/nginx/nginx.conf`，而是新建：

```bash
/etc/nginx/sites-available/draw.siyefun.top
```

原因是：

- 主配置文件负责全局设置
- 站点配置文件负责某个域名的具体路由规则
- Ubuntu 默认已经按 `sites-available` / `sites-enabled` 这种结构组织 Nginx
- 这种方式更适合后续继续增加 `api`、Java 服务、HTTPS 或更多子域名

可以把它理解成：

- `/etc/nginx/nginx.conf` 是总入口
- `/etc/nginx/sites-available/draw.siyefun.top` 是 `draw.siyefun.top` 这个站点自己的配置

## 为什么还要区分 sites-available 和 sites-enabled

这样设计是为了把“配置存在”和“配置生效”分开：

- `sites-available`：配置文件仓库
- `sites-enabled`：当前真正启用的站点

当前通过软链接启用：

```bash
sudo ln -s /etc/nginx/sites-available/draw.siyefun.top /etc/nginx/sites-enabled/draw.siyefun.top
```

这样以后如果想停用站点，只需要移除 `sites-enabled` 里的链接，而不是删除原始配置文件。

## HTTPS 已完成

当前 `draw.siyefun.top` 已经完成 HTTPS 配置，并可以正常访问。

本次方案使用的是免费证书思路，推荐工具链仍然是：

- `Let's Encrypt`
- `certbot`
- `python3-certbot-nginx`

可复用的典型命令如下：

安装：

```bash
sudo apt install -y certbot python3-certbot-nginx
```

申请并自动修改 Nginx 配置：

```bash
sudo certbot --nginx -d draw.siyefun.top
```

验证续期：

```bash
sudo certbot renew --dry-run
```

如果后续在其他 Linux 子域名上继续申请 HTTPS，执行前重点看：

- `draw.siyefun.top` 已经稳定解析到当前服务器
- `80` 和 `443` 端口对公网开放
- `sudo nginx -t` 当前通过

当前结果：

- `http://draw.siyefun.top` 可访问
- `https://draw.siyefun.top` 可访问
- 说明域名解析、Nginx 配置、证书申请、TLS 握手链路都已经打通

以上 HTTPS 结果针对的是历史 Linux 练习域名 `draw.siyefun.top`；新的
`draw.siyes.cn` 仍需等待 ICP 备案通过后单独申请证书。

## 常见检查命令

查看主配置：

```bash
cat /etc/nginx/nginx.conf
```

查看站点配置目录：

```bash
ls -la /etc/nginx/sites-available
ls -la /etc/nginx/sites-enabled
```

检查站点配置文件：

```bash
cat /etc/nginx/sites-available/draw.siyefun.top
```

检查新的站点配置：

```bash
cat /etc/nginx/sites-available/draw.siyes.cn
```

检查 Nginx 配置是否正确：

```bash
sudo nginx -t
```

重载 Nginx：

```bash
sudo systemctl reload nginx
```

## 这次实践已经掌握的内容

- Linux 服务器上部署前端静态站点
- 使用 `scp` 上传前端打包产物
- 理解 Nginx 主配置和站点配置的分工
- 理解 `sites-available` 和 `sites-enabled` 的作用
- 通过域名访问 Linux 上的新站点
- 在 Linux 服务器上完成免费 HTTPS 证书申请和启用
- 使用新域名并行迁移静态站点，保留旧域名作为回滚入口
- 使用 `Host`、DNS、HTTP 状态码和 SPA 路由回退验证 Nginx 站点

## 后续可继续扩展

1. 用 Docker 再部署一次 `svg-draw`，对比两种部署方式
2. 再部署一个带后端接口的项目，进入 `Nginx + Java/Spring Boot + MySQL/Redis` 的完整链路
3. 后续如果有新的 Linux 子域名，再复用这套 Nginx + Certbot 流程
