import express from 'express'
import cors from 'cors'
import fs from 'fs/promises'
import path from 'path'
import http from 'http'
import { WebSocketServer } from 'ws'
import chokidar from 'chokidar'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

// 本地开发默认读取仓库根目录，生产容器通过 KNOWLEDGE_ROOT 指向只读挂载目录。
const ROOT = path.resolve(
  process.env.KNOWLEDGE_ROOT || path.resolve(__dirname, '..', '..')
)
const PUBLIC_DIR = path.resolve(__dirname, '..', 'src', 'dist')
const SELF_DIR = path.basename(path.resolve(__dirname, '..'))  // 'md-viewer'

const PORT = Number(process.env.MD_VIEWER_PORT || 3001)
const ALLOWED_EXT = new Set([
  '.md', '.mdx', '.txt', '.log',
  '.js', '.jsx', '.mjs', '.cjs', '.ts', '.tsx', '.vue',
  '.json', '.jsonc', '.html', '.htm', '.css', '.scss', '.sass', '.less',
  '.yml', '.yaml', '.xml', '.svg', '.sql',
  '.sh', '.bash', '.zsh', '.ps1', '.bat', '.cmd',
  '.conf', '.config', '.ini', '.properties', '.toml',
  '.example', '.template', '.dockerfile'
])
const ALLOWED_NAMES = new Set([
  'dockerfile', 'containerfile', 'makefile', 'license',
  '.gitignore', '.gitattributes', '.dockerignore',
  '.editorconfig', '.npmrc', '.yarnrc', '.nvmrc'
])
const IGNORED_DIRS = new Set(['node_modules', '.git', '.vscode', '.idea', 'dist', SELF_DIR])

const app = express()
app.use(cors())
app.use(express.json())

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'frontend-knowledge' })
})

/**
 * 把绝对路径转成相对 ROOT 的安全路径
 */
function toRelative(abs) {
  return path.relative(ROOT, abs).split(path.sep).join('/')
}

/**
 * 拒绝越权访问 ROOT 之外的文件
 */
function safeJoin(relPath) {
  const abs = path.resolve(ROOT, relPath || '.')
  const relative = path.relative(ROOT, abs)
  if (relative.startsWith('..') || path.isAbsolute(relative)) {
    throw new Error('Path traversal blocked')
  }
  return abs
}

/**
 * 只允许已知文本文件，避免把 jar、压缩包等二进制文件读进浏览器。
 */
function isSupportedFile(fileName) {
  const lowerName = fileName.toLowerCase()
  return ALLOWED_NAMES.has(lowerName) || ALLOWED_EXT.has(path.extname(lowerName))
}

/**
 * 隐藏依赖、构建产物和点号目录，但允许查看 .env.example 等受支持的点号文件。
 */
function shouldIgnoreWatchedPath(watchedPath) {
  const relative = path.relative(ROOT, watchedPath)
  if (!relative || relative === '.') return false

  const segments = relative.split(path.sep)
  if (segments.some(segment => IGNORED_DIRS.has(segment))) return true
  if (segments.slice(0, -1).some(segment => segment.startsWith('.'))) return true

  const base = segments.at(-1)
  return base.startsWith('.') && !isSupportedFile(base)
}

/**
 * 递归读取目录树
 */
async function readTree(dir = ROOT) {
  const name = path.basename(dir)
  const stat = await fs.stat(dir)
  if (!stat.isDirectory()) {
    return {
      name,
      path: toRelative(dir),
      type: 'file',
      ext: path.extname(name).toLowerCase()
    }
  }
  if (IGNORED_DIRS.has(name) && dir !== ROOT) return null

  const entries = await fs.readdir(dir, { withFileTypes: true })
  const children = []
  for (const e of entries) {
    if (IGNORED_DIRS.has(e.name)) continue
    if (e.isDirectory() && e.name.startsWith('.')) continue
    if (e.isFile() && !isSupportedFile(e.name)) continue
    const child = await readTree(path.join(dir, e.name))
    if (!child) continue
    children.push(child)
  }
  // 文件夹优先 + 按名排序
  children.sort((a, b) => {
    if (a.type !== b.type) return a.type === 'dir' ? -1 : 1
    return a.name.localeCompare(b.name, 'zh-CN')
  })
  return {
    name: dir === ROOT ? path.basename(ROOT) : name,
    path: toRelative(dir),
    type: 'dir',
    children
  }
}

app.get('/api/tree', async (req, res) => {
  try {
    const tree = await readTree()
    res.json(tree)
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

app.get('/api/file', async (req, res) => {
  try {
    const rel = req.query.path || ''
    if (!rel) return res.status(400).json({ error: 'path required' })
    const abs = safeJoin(rel)
    const stat = await fs.stat(abs)
    if (!stat.isFile()) return res.status(400).json({ error: 'not a file' })
    const ext = path.extname(abs).toLowerCase()
    if (!isSupportedFile(path.basename(abs))) {
      return res.status(403).json({ error: 'file type not allowed' })
    }
    const content = await fs.readFile(abs, 'utf-8')
    res.json({ path: rel, ext, content, size: stat.size, mtime: stat.mtimeMs })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// 只有生产容器直接提供 Vite 构建产物，本地开发页面由 5173 的 Vite 服务提供。
if (process.env.NODE_ENV === 'production') {
  // Vite gives hashed files stable names; cache them aggressively while the
  // HTML entry point remains revalidated on every deployment.
  app.use('/assets', express.static(path.join(PUBLIC_DIR, 'assets'), {
    maxAge: '1y',
    immutable: true
  }))
  app.use('/monacoeditorwork', express.static(path.join(PUBLIC_DIR, 'monacoeditorwork'), {
    maxAge: '1h'
  }))
  app.use(express.static(PUBLIC_DIR, { index: 'index.html' }))
}

const server = http.createServer(app)
const wss = new WebSocketServer({ server, path: '/ws' })

function broadcast(msg) {
  const data = JSON.stringify(msg)
  for (const client of wss.clients) {
    if (client.readyState === 1) client.send(data)
  }
}

wss.on('connection', ws => {
  ws.send(JSON.stringify({ type: 'hello', root: path.basename(ROOT) }))
})

// 监听文件变化
const watcher = chokidar.watch(ROOT, {
  ignored: shouldIgnoreWatchedPath,
  ignoreInitial: true,
  persistent: true,
  awaitWriteFinish: { stabilityThreshold: 200, pollInterval: 100 }
})

const notify = (type) => (abs) => {
  const ext = path.extname(abs).toLowerCase()
  // 目录变更也通知（重新拉树）
  const isFile = isSupportedFile(path.basename(abs))
  broadcast({
    type,
    path: toRelative(abs),
    ext,
    isFile
  })
}

watcher
  .on('add', notify('add'))
  .on('change', notify('change'))
  .on('unlink', notify('unlink'))
  .on('addDir', notify('addDir'))
  .on('unlinkDir', notify('unlinkDir'))
  .on('error', err => console.error('[watcher]', err))

server.listen(PORT, '0.0.0.0', () => {
  console.log(`\n  📁 md-viewer server`)
  console.log(`  ─ root:    ${ROOT}`)
  console.log(`  ─ http:    http://0.0.0.0:${PORT}/api/tree`)
  console.log(`  ─ ws:      ws://0.0.0.0:${PORT}/ws`)
  console.log(`  ─ web ui:  http://localhost:5173  (run npm run dev:web)\n`)
})
