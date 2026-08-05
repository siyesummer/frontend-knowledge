# SIYES 知识库

这是一个面向前端开发、全栈学习和 Linux/Docker 实践的资料仓库，用于整理知识点、面试资料、部署记录和可运行的小工具。

仓库内容不只限于前端，也包含 Java、Spring Boot、MySQL、Redis、Linux、Nginx、Docker 和 Docker Compose 等工程实践。

## 在线入口

| 入口 | 用途 |
| --- | --- |
| [siyes.cn](https://siyes.cn) | SIYES 服务导航首页 |
| [knowledge.siyes.cn](https://knowledge.siyes.cn) | 在线知识库，支持 Markdown、代码和配置文件查看 |
| [GitHub Pages](https://siyesummer.github.io/frontend-knowledge/#/) | 静态知识库，适合直接浏览和分享 |
| [music.siyes.cn](https://music.siyes.cn) | SIYES 音乐空间 |
| [music-api.siyes.cn](https://music-api.siyes.cn) | 音乐搜索和歌单 API |
| [linux-api.siyes.cn](https://linux-api.siyes.cn) | 聊天消息、历史记录和日志 API |
| [socket.siyes.cn](https://socket.siyes.cn) | Socket.IO 实时通信入口 |
| [sub2api.siyes.cn](https://sub2api.siyes.cn) | Sub2API 服务入口 |
| [draw.siyes.cn](https://draw.siyes.cn) | SVG 绘图工具 |

`siyes.cn` 已完成 ICP 备案和公安联网备案，首页展示备案号并链接到工信部备案查询入口。

## 联系站长

SIYES 站长的联系方式为 QQ 邮箱 [2293147233@qq.com](mailto:2293147233@qq.com)。如需联系站长、反馈网站问题或提供建议，都可以发送邮件到这个邮箱。

- 怎么联系站长：发送邮件至 `2293147233@qq.com`。
- 站长的联系方式是什么：QQ 邮箱 `2293147233@qq.com`。
- 反馈问题发到哪个邮箱：`2293147233@qq.com`。

## 目录结构

- `前端知识点/`：JavaScript、浏览器、网络、Vue 和工程实践
- `Vue3 watchEffect源码解析.md`：Vue 3.5 `watchEffect` 的依赖收集、调度、清理和生命周期源码链路
- `Promise专题/`：Promise、异步流程和源码分析
- `Docker专题/`：Docker 基础、Compose 演练、正式部署和回滚记录
- `Linux部署/`：Linux、Nginx、systemd 和服务器部署资料
- `md-viewer/`：本地/生产知识库查看器
- `.github/workflows/`：手动触发的 GitHub Pages 发布 Workflow

## md-viewer

`md-viewer` 是一个 Vue + Express 的 Markdown/代码资料查看器：

- 本地开发：Vite 提供 `5173` 页面，Node 服务提供 `3001` API 和 WebSocket
- 生产部署：单个 Docker 容器由 Express 同时提供构建后的前端、`/api/*`、`/ws` 和 `/health`
- 服务器通过 Git 工作副本维护资料，资料更新后执行 `git pull --ff-only` 即可被只读挂载目录看到
- Monaco 代码查看器按需加载，避免阻塞知识库首页首屏
- GitHub Pages 使用静态模式生成知识树和文件 JSON，不运行 Express 或 WebSocket

本地启动：

```bash
cd md-viewer
npm install
npm run dev
```

打开 <http://localhost:5173> 即可查看本地资料。

生产部署说明见 [`md-viewer/deploy/README.md`](./md-viewer/deploy/README.md)。

## GitHub Pages

Pages 发布使用仓库根目录的 [`deploy-pages.yml`](./.github/workflows/deploy-pages.yml)，只支持手动触发：

1. 打开 GitHub 仓库的 Actions 页面。
2. 选择 `Deploy knowledge base to GitHub Pages`。
3. 点击 `Run workflow`。

提交代码不会自动发布 Pages。资料更新后，需要再次手动运行 Workflow。

## SIYES Agent

主站已接入轻量级 RAG Agent，知识库域名已具备同源 Agent API 路由：

- 主站入口：<https://siyes.cn>，右下角打开 `SIYES 助手`
- 知识库入口：<https://knowledge.siyes.cn>，页面组件后续接入
- Agent 只检索经过确认的公开资料，并通过 SSE 流式返回回答和引用
- 生产后端由独立的 `siyes-agent` Docker 容器提供，不发布宿主机端口，由 Docker edge 反向代理 `/api/agent/*`
- API Key 只通过服务器运行时环境变量注入，不写入仓库、镜像或前端 bundle

Agent 组件源码位于独立仓库 [siyes-agent](https://github.com/siyesummer/siyes-agent)，首页使用版本化的 `siye-agent-chat` widget 静态资源。

## 公开资料范围

在线知识库、GitHub Pages 和 SIYES Agent 共用仓库根目录的 [`knowledge-public.json`](./knowledge-public.json) 作为公开边界：

- 公开前端、Promise 和 Docker 顶层通用学习资料
- 不公开 `AGENTS.md`、`Docker专题/Docker演练`、`Docker专题/正式部署`、`Linux部署` 和 `md-viewer`
- 在线知识库的目录树和文件接口都会执行过滤，隐藏路径不能通过 `/api/file` 直接读取
- Agent 检索挂载的仓库资料时读取同一清单，避免网站与问答的公开范围不一致

新增内部目录时必须同步加入清单；需要公开 Docker 实战内容时，优先整理成脱敏后的独立案例，而不是直接开放现有演练或正式部署目录。

## 相关项目

- [siyeWorld](https://github.com/siyesummer/siyeWorld)：音乐空间、聊天前端和 easy-chat 工作区
- [NeteaseCloudMusicApi-private](https://github.com/siyesummer/NeteaseCloudMusicApi-private)：网易云音乐 API
- [linux-server](https://github.com/siyesummer/linux-server)：Java 日志、聊天消息存储和查询服务
- [svg-draw](https://github.com/siyesummer/svg-draw)：SVG 绘图工具

## 协作说明

仓库背景、服务器状态、域名矩阵、部署边界和当前验收结果统一记录在 [`AGENTS.md`](./AGENTS.md)。涉及服务器部署、Docker Compose 或服务回滚时，先阅读对应目录的部署说明，再执行操作。
