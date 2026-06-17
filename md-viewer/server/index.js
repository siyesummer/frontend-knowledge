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

// 监听的根目录 = md-viewer 的上一级（即 frontend 目录）
const ROOT = path.resolve(__dirname, '..', '..')
const SELF_DIR = path.basename(path.resolve(__dirname, '..'))  // 'md-viewer'

const PORT = 3001
const ALLOWED_EXT = new Set(['.md', '.js', '.ts', '.json', '.txt', '.html', '.css', '.vue'])
const IGNORED_DIRS = new Set(['node_modules', '.git', '.vscode', '.idea', 'dist', SELF_DIR])

const app = express()
app.use(cors())
app.use(express.json())

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
  if (!abs.startsWith(ROOT)) throw new Error('Path traversal blocked')
  return abs
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
    if (e.name.startsWith('.')) continue
    const child = await readTree(path.join(dir, e.name))
    if (!child) continue
    if (child.type === 'file') {
      const ext = path.extname(e.name).toLowerCase()
      if (!ALLOWED_EXT.has(ext)) continue
    }
    children.push(child)
  }
  // 文件夹优先 + 按名排序
  children.sort((a, b) => {
    if (a.type !== b.type) return a.type === 'dir' ? -1 : 1
    return a.name.localeCompare(b.name, 'zh-CN')
  })
  return {
    name: dir === ROOT ? 'frontend' : name,
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
    if (!ALLOWED_EXT.has(ext)) return res.status(403).json({ error: 'ext not allowed' })
    const content = await fs.readFile(abs, 'utf-8')
    res.json({ path: rel, ext, content, size: stat.size, mtime: stat.mtimeMs })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

const server = http.createServer(app)
const wss = new WebSocketServer({ server, path: '/ws' })

function broadcast(msg) {
  const data = JSON.stringify(msg)
  for (const client of wss.clients) {
    if (client.readyState === 1) client.send(data)
  }
}

wss.on('connection', ws => {
  ws.send(JSON.stringify({ type: 'hello', root: 'frontend' }))
})

// 监听文件变化
const watcher = chokidar.watch(ROOT, {
  ignored: (p) => {
    const base = path.basename(p)
    if (IGNORED_DIRS.has(base)) return true
    if (base.startsWith('.')) return true
    return false
  },
  ignoreInitial: true,
  persistent: true,
  awaitWriteFinish: { stabilityThreshold: 200, pollInterval: 100 }
})

const notify = (type) => (abs) => {
  const ext = path.extname(abs).toLowerCase()
  // 目录变更也通知（重新拉树）
  let isFile = true
  try {
    isFile = !!ext && ALLOWED_EXT.has(ext)
  } catch {}
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

server.listen(PORT, () => {
  console.log(`\n  📁 md-viewer server`)
  console.log(`  ─ root:    ${ROOT}`)
  console.log(`  ─ http:    http://localhost:${PORT}/api/tree`)
  console.log(`  ─ ws:      ws://localhost:${PORT}/ws`)
  console.log(`  ─ web ui:  http://localhost:5173  (run npm run dev:web)\n`)
})
