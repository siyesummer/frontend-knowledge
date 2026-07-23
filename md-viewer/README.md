# MD Viewer

一个本地知识库查看工具：左侧直接展示仓库内的知识分类，右侧查看 Markdown、代码、脚本及部署配置等文本文件，并在文件被修改时**自动刷新**。

## ✨ 特性

- 📁 **左侧文件树**：递归展示仓库内所有支持的文件
- 🔎 **快速定位**：支持文件/目录搜索、全部收起和定位当前文件
- ↔️ **可调侧栏**：拖拽调整文件树宽度并自动记忆，也可临时隐藏侧栏
- 📝 **Markdown 渲染**：`markdown-it` + `highlight.js` 代码高亮（github-dark 主题）
- 📜 **代码与配置文件**：Monaco Editor 只读模式，支持 JS / TS / Vue / JSON / YAML / SQL / Shell / PowerShell / Dockerfile / `.env` / Nginx 配置等
- 🔄 **实时同步**：`chokidar` 监听文件变化，WebSocket 推送，**文件保存即刷新**
- 🟢 **变更高亮**：变更文件在文件树中短暂闪烁
- 🔌 **断线自动重连**

## 🧱 技术栈

| 端 | 技术 |
|----|------|
| 前端 | Vue 3 + Vite + markdown-it + highlight.js + Monaco Editor |
| 后端 | Express + chokidar + ws (WebSocket) |
| 实时同步 | chokidar 监听 → WebSocket 推送 → 前端按需重载 |

## 🚀 启动

> 要求：Node.js ≥ 18，npm ≥ 9

```bash
cd "<仓库目录>\md-viewer"
npm install
npm run dev
```

启动后会同时跑：
- **后端 API**：http://localhost:3001（提供 `/api/tree` `/api/file` 和 `/ws`）
- **前端 UI**：http://localhost:5173（Vite 自动代理 `/api` 和 `/ws` 到 3001）

打开浏览器访问 **http://localhost:5173** 即可。

### 单独启动

```bash
npm run dev:server   # 只跑后端
npm run dev:web      # 只跑前端（需要后端在跑）
```

### 生产 Docker 部署

生产环境不启动 Vite `5173`。Dockerfile 在构建阶段执行 `npm run build`，再由同一个 Node/Express 容器提供 `src/dist`、`/api/*` 和 `/ws`。容器只加入正式 Docker edge 网络，不发布宿主机端口，公网请求由 Docker edge 转发到容器内部 `3001`。

完整的服务器首次部署、edge 路由、更新和回滚步骤见 [deploy/README.md](./deploy/README.md)。

## GitHub Pages 发布

仓库提供 `.github/workflows/deploy-pages.yml`，只支持在 GitHub Actions 页面手动触发，不会在提交代码时自动发布。

首次发布前，在 GitHub 仓库中打开 `Settings -> Pages`，将 `Build and deployment` 的 `Source` 设置为 `GitHub Actions`。之后按以下步骤发布：

1. 打开仓库的 `Actions` 页面。
2. 选择 `Deploy knowledge base to GitHub Pages`。
3. 点击 `Run workflow`，选择需要发布的分支后确认运行。
4. 等待 `build` 和 `deploy` 两个任务完成，通过任务输出或仓库 `Pages` 设置页打开站点。

Pages 不运行 Express 和 WebSocket 服务。工作流会在构建时生成静态文件树和文件内容，页面仍可浏览、搜索和渲染知识资料，但不具备本地模式的文件实时刷新能力。

静态数据只读取 Git 已跟踪文件，以及未被 `.gitignore` 忽略的新文件；被忽略的本地 `.env`、构建产物和其他敏感配置不会进入 Pages 制品。发布前仍需检查准备提交的文件，不能把密钥、密码、Token 或真实服务器地址提交到仓库。

如需在本地检查 Pages 构建结果：

```bash
cd "<仓库目录>/md-viewer"
npm ci
npm run build:pages
npm run preview
```

## 📂 工程结构

```
md-viewer/
├── package.json
├── vite.config.js
├── scripts/
│   └── generate-static-data.mjs # 生成 Pages 静态知识数据
├── server/
│   └── index.js              # Express + WS + chokidar
└── src/
    ├── index.html
    ├── main.js
    ├── style.css
    ├── App.vue               # 主布局 + 业务编排
    └── components/
        ├── FileTree.vue      # 文件树容器
        ├── FileTreeNode.vue  # 递归节点
        ├── Viewer.vue        # 右侧分发器（md vs code）
        ├── MarkdownView.vue  # markdown 渲染
        └── CodeView.vue      # Monaco 编辑器
```

## ⚙️ 配置

服务端常量在 `server/index.js` 顶部：

```js
const ROOT = path.resolve(process.env.KNOWLEDGE_ROOT || path.resolve(__dirname, '..', '..'))
const PORT = Number(process.env.MD_VIEWER_PORT || 3001) // 后端端口，可临时覆盖
const ALLOWED_EXT = new Set([/* 支持的文本文件扩展名 */])
const ALLOWED_NAMES = new Set([/* Dockerfile、.gitignore 等特殊文件名 */])
const IGNORED_DIRS = new Set(['node_modules', '.git', '.vscode', '.idea', 'dist', 'md-viewer'])
```

按需修改即可。比如想只展示某个子目录，把 `ROOT` 指过去就行。

如果本机 `3001` 已被占用，可只为当前终端临时指定其他端口：

```powershell
$env:MD_VIEWER_PORT=3101
npm run dev
```

服务端和 Vite 代理会同时读取该变量，因此网页端仍可正常请求 API 和 WebSocket。

## 🛡️ 安全

- 后端用 `safeJoin` 防止路径穿越（`../../etc/passwd` 之类）
- 只允许读取白名单文本类型和明确的特殊文件名，真实 `.env` 和二进制文件不会出现在文件树中
- 本地 Express 服务用于 Vite 代理和 WebSocket；生产环境必须使用 `deploy/` 中的 Docker 配置，并由 edge 统一提供 HTTPS
- 生产容器只读挂载知识库目录，容器不能通过 API 修改宿主机 Git 工作副本
- GitHub Pages 使用独立静态模式，不部署 Express 和 WebSocket 服务

## 🔍 同步原理

```
文件改动
   │
   ▼
chokidar 监听到 add/change/unlink/addDir/unlinkDir
   │
   ▼
后端 broadcast({ type, path, ext, isFile })
   │
   ▼
前端 WebSocket onmessage:
  ├─ 目录/新增/删除 → 重新拉取 /api/tree
  ├─ 当前文件被修改 → 重新拉取 /api/file?path=...
  └─ 文件树短暂闪烁高亮
```

## 📝 已知限制

- Monaco 在首次加载时会拉取 worker 文件，速度取决于网络
- 文件超大（几 MB）时 Monaco 可能略卡
- 不支持二进制文件（图片等）—— 只展示文本类
