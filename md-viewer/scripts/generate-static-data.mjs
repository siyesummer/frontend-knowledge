import { createHash } from 'node:crypto'
import { execFile } from 'node:child_process'
import fs from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { promisify } from 'node:util'

const execFileAsync = promisify(execFile)
const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const viewerDir = path.resolve(scriptDir, '..')
const repoRoot = path.resolve(viewerDir, '..')
const outputDir = path.join(viewerDir, 'src', 'public', 'knowledge-data')
const filesOutputDir = path.join(outputDir, 'files')

const allowedExtensions = new Set([
  '.md', '.mdx', '.txt', '.log',
  '.js', '.jsx', '.mjs', '.cjs', '.ts', '.tsx', '.vue',
  '.json', '.jsonc', '.html', '.htm', '.css', '.scss', '.sass', '.less',
  '.yml', '.yaml', '.xml', '.svg', '.sql',
  '.sh', '.bash', '.zsh', '.ps1', '.bat', '.cmd',
  '.conf', '.config', '.ini', '.properties', '.toml',
  '.env', '.example', '.template', '.dockerfile'
])
const allowedNames = new Set([
  'dockerfile', 'containerfile', 'makefile', 'license',
  '.gitignore', '.gitattributes', '.dockerignore',
  '.editorconfig', '.npmrc', '.yarnrc', '.nvmrc'
])
const ignoredDirectories = new Set([
  'node_modules', '.git', '.vscode', '.idea', 'dist', 'md-viewer'
])

function isSupportedFile(filePath) {
  const fileName = path.posix.basename(filePath).toLowerCase()
  return allowedNames.has(fileName) || allowedExtensions.has(path.posix.extname(fileName))
}

function isVisiblePath(filePath) {
  const directories = filePath.split('/').slice(0, -1)
  return !directories.some(name => name.startsWith('.') || ignoredDirectories.has(name))
}

function getOrCreateDirectory(parent, name, relativePath) {
  let directory = parent.children.find(
    child => child.type === 'dir' && child.name === name
  )
  if (!directory) {
    directory = { name, path: relativePath, type: 'dir', children: [] }
    parent.children.push(directory)
  }
  return directory
}

function sortTree(node) {
  if (node.type !== 'dir') return
  node.children.sort((left, right) => {
    if (left.type !== right.type) return left.type === 'dir' ? -1 : 1
    return left.name.localeCompare(right.name, 'zh-CN')
  })
  node.children.forEach(sortTree)
}

async function listCommittableFiles() {
  const { stdout } = await execFileAsync(
    'git',
    [
      '-c', 'core.quotepath=false',
      'ls-files', '-z', '--cached', '--others', '--exclude-standard'
    ],
    { cwd: repoRoot, maxBuffer: 10 * 1024 * 1024 }
  )

  return stdout
    .split('\0')
    .filter(Boolean)
    .map(filePath => filePath.replaceAll('\\', '/'))
    .filter(filePath => isVisiblePath(filePath) && isSupportedFile(filePath))
    .sort((left, right) => left.localeCompare(right, 'zh-CN'))
}

async function generateStaticData() {
  await fs.rm(outputDir, { recursive: true, force: true })
  await fs.mkdir(filesOutputDir, { recursive: true })

  const tree = { name: '知识库', path: '', type: 'dir', children: [] }
  const files = await listCommittableFiles()
  let generatedCount = 0

  for (const relativePath of files) {
    const absolutePath = path.join(repoRoot, ...relativePath.split('/'))
    let stat
    try {
      stat = await fs.stat(absolutePath)
    } catch {
      continue
    }
    if (!stat.isFile()) continue

    const segments = relativePath.split('/')
    const fileName = segments.pop()
    let parent = tree
    for (let index = 0; index < segments.length; index++) {
      const directoryPath = segments.slice(0, index + 1).join('/')
      parent = getOrCreateDirectory(parent, segments[index], directoryPath)
    }

    const dataFile = `${createHash('sha256').update(relativePath).digest('hex')}.json`
    const content = await fs.readFile(absolutePath, 'utf8')
    const payload = {
      path: relativePath,
      ext: path.posix.extname(fileName).toLowerCase(),
      content,
      size: stat.size,
      mtime: stat.mtimeMs
    }

    await fs.writeFile(
      path.join(filesOutputDir, dataFile),
      JSON.stringify(payload),
      'utf8'
    )
    parent.children.push({
      name: fileName,
      path: relativePath,
      type: 'file',
      ext: payload.ext,
      dataFile
    })
    generatedCount++
  }

  sortTree(tree)
  await fs.writeFile(
    path.join(outputDir, 'tree.json'),
    JSON.stringify(tree),
    'utf8'
  )
  console.log(`Generated static knowledge data for ${generatedCount} files.`)
}

await generateStaticData()
