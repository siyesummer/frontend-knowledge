# MD Viewer

一个本地小工具：左侧展示 `E:\本地项目\frontend\` 目录树，右侧查看 `.md / .js / .ts / .vue / .json / .html / .css` 等文件，并在文件被修改时**自动刷新**。

## ✨ 特性

- 📁 **左侧文件树**：递归展示 `frontend/` 下所有支持的文件
- 📝 **Markdown 渲染**：`markdown-it` + `highlight.js` 代码高亮（github-dark 主题）
- 📜 **JS / TS / JSON 等代码**：Monaco Editor 只读模式（VS Code 同款内核）
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
cd "E:\本地项目\frontend\md-viewer"
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

## 📂 工程结构

```
md-viewer/
├── package.json
├── vite.config.js
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
const ROOT = path.resolve(__dirname, '..', '..')   // 监听目录（默认是 frontend）
const PORT = 3001                                   // 后端端口
const ALLOWED_EXT = new Set(['.md', '.js', '.ts', '.json', '.txt', '.html', '.css', '.vue'])
const IGNORED_DIRS = new Set(['node_modules', '.git', '.vscode', '.idea', 'dist', 'md-viewer'])
```

按需修改即可。比如想只展示某个子目录，把 `ROOT` 指过去就行。

## 🛡️ 安全

- 后端用 `safeJoin` 防止路径穿越（`../../etc/passwd` 之类）
- 只允许读取白名单后缀
- 仅本地访问，**不要部署到公网**

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
