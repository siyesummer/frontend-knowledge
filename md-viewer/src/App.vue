<template>
  <aside
    v-if="sidebarVisible"
    class="sidebar"
    :style="{ width: sidebarWidth + 'px' }"
  >
    <div class="sidebar-header">
      <span class="sidebar-title" title="知识库">📁 知识库</span>
      <span class="ws-status" :class="wsState" :title="wsLabel">
        <span class="dot"></span>
      </span>
      <button
        class="icon-button"
        :title="theme === 'dark' ? '切换到亮色' : '切换到暗色'"
        @click="toggleTheme"
      >
        {{ theme === 'dark' ? '☀️' : '🌙' }}
      </button>
      <button class="icon-button" title="隐藏侧栏" @click="sidebarVisible = false">‹</button>
    </div>

    <div class="sidebar-tools">
      <div class="tree-search-wrap">
        <span class="tree-search-icon">⌕</span>
        <input
          v-model="treeQuery"
          class="tree-search"
          type="search"
          placeholder="搜索文件或目录"
          @keydown.esc="treeQuery = ''"
        />
        <button
          v-if="treeQuery"
          class="search-clear"
          title="清空搜索"
          @click="treeQuery = ''"
        >×</button>
      </div>
      <button class="tool-button" title="全部收起" @click="fileTreeRef?.collapseAll()">收起</button>
      <button
        class="tool-button"
        :disabled="!currentFile"
        title="定位当前文件"
        @click="fileTreeRef?.revealActive()"
      >定位</button>
    </div>

    <FileTree
      ref="fileTreeRef"
      :root="tree"
      :active-path="currentFile?.path"
      :changed-paths="changedPaths"
      :query="treeQuery"
      @pick="openFile"
    />
  </aside>

  <div
    v-if="sidebarVisible"
    class="sidebar-resizer"
    title="拖拽调整侧栏宽度"
    @pointerdown="startSidebarResize"
  ></div>

  <button
    v-else
    class="sidebar-reopen"
    title="显示文件树"
    @click="sidebarVisible = true"
  >☰</button>

  <Viewer :file="currentFile" :theme="theme" />
</template>

<script setup>
import { ref, reactive, onMounted, onBeforeUnmount, provide, watch, nextTick } from 'vue'
import FileTree from './components/FileTree.vue'
import Viewer from './components/Viewer.vue'

const tree = ref(null)
const currentFile = ref(null)
const changedPaths = reactive(new Set())
const wsState = ref('connecting')   // connecting | connected | error
const wsLabel = ref('连接中')
const fileTreeRef = ref(null)
const treeQuery = ref('')
const staticMode = import.meta.env.MODE === 'pages'
const staticDataBase = `${import.meta.env.BASE_URL}knowledge-data/`

const SIDEBAR_WIDTH_KEY = 'mdviewer:sidebar-width'
const SIDEBAR_MIN_WIDTH = 260
const SIDEBAR_MAX_WIDTH = 720
const savedSidebarWidth = Number(localStorage.getItem(SIDEBAR_WIDTH_KEY))
const sidebarWidth = ref(
  Number.isFinite(savedSidebarWidth)
    ? Math.min(SIDEBAR_MAX_WIDTH, Math.max(SIDEBAR_MIN_WIDTH, savedSidebarWidth))
    : 360
)
const sidebarVisible = ref(true)

// ============ 主题 ============
const THEME_KEY = 'mdviewer:theme'
function getInitialTheme() {
  const saved = localStorage.getItem(THEME_KEY)
  if (saved === 'dark' || saved === 'light') return saved
  return 'dark'
}
const theme = ref(getInitialTheme())
provide('theme', theme)

function applyTheme(t) {
  document.documentElement.setAttribute('data-theme', t)
  localStorage.setItem(THEME_KEY, t)
}
function toggleTheme() {
  theme.value = theme.value === 'dark' ? 'light' : 'dark'
}
watch(theme, applyTheme, { immediate: true })

let ws = null
let wsReconnectTimer = null
let treeReloadTimer = null

async function loadTree() {
  try {
    const treeUrl = staticMode ? `${staticDataBase}tree.json` : '/api/tree'
    const res = await fetch(treeUrl)
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    tree.value = await res.json()
  } catch (e) {
    console.error(e)
  }
}

async function openFile(node) {
  try {
    const fileUrl = staticMode
      ? `${staticDataBase}files/${node.dataFile}`
      : '/api/file?path=' + encodeURIComponent(node.path)
    const res = await fetch(fileUrl)
    if (!res.ok) {
      const err = await res.json().catch(() => ({}))
      throw new Error(err.error || res.statusText)
    }
    currentFile.value = await res.json()
    await nextTick()
    fileTreeRef.value?.revealActive()
  } catch (e) {
    console.error(e)
    alert('文件加载失败：' + e.message)
  }
}

function startSidebarResize(event) {
  event.preventDefault()
  const startX = event.clientX
  const startWidth = sidebarWidth.value
  document.body.classList.add('is-resizing-sidebar')

  function onPointerMove(moveEvent) {
    sidebarWidth.value = Math.min(
      SIDEBAR_MAX_WIDTH,
      Math.max(SIDEBAR_MIN_WIDTH, startWidth + moveEvent.clientX - startX)
    )
  }

  function onPointerUp() {
    localStorage.setItem(SIDEBAR_WIDTH_KEY, String(sidebarWidth.value))
    document.body.classList.remove('is-resizing-sidebar')
    window.removeEventListener('pointermove', onPointerMove)
    window.removeEventListener('pointerup', onPointerUp)
  }

  window.addEventListener('pointermove', onPointerMove)
  window.addEventListener('pointerup', onPointerUp)
}

// 节流：短时间内多次变更，只重新拉一次树
function scheduleTreeReload() {
  clearTimeout(treeReloadTimer)
  treeReloadTimer = setTimeout(loadTree, 250)
}

// 闪烁高亮一段时间
function flashChanged(path) {
  changedPaths.add(path)
  setTimeout(() => changedPaths.delete(path), 1500)
}

function connectWs() {
  if (staticMode) {
    wsState.value = 'connected'
    wsLabel.value = '静态站点'
    return
  }

  const proto = location.protocol === 'https:' ? 'wss' : 'ws'
  ws = new WebSocket(`${proto}://${location.host}/ws`)

  ws.onopen = () => {
    wsState.value = 'connected'
    wsLabel.value = '已连接'
  }
  ws.onclose = () => {
    wsState.value = 'error'
    wsLabel.value = '断开重连…'
    clearTimeout(wsReconnectTimer)
    wsReconnectTimer = setTimeout(connectWs, 2000)
  }
  ws.onerror = () => {
    wsState.value = 'error'
    wsLabel.value = '错误'
  }
  ws.onmessage = async (ev) => {
    let msg = null
    try { msg = JSON.parse(ev.data) } catch { return }
    if (msg.type === 'hello') return

    if (msg.type === 'addDir' || msg.type === 'unlinkDir' || msg.type === 'add' || msg.type === 'unlink') {
      scheduleTreeReload()
    }
    if (msg.path) flashChanged(msg.path)

    // 当前查看的文件被修改 → 重新拉取
    if (msg.type === 'change' && currentFile.value && currentFile.value.path === msg.path) {
      await openFile({ path: msg.path })
    }
    // 当前查看的文件被删除 → 关闭
    if (msg.type === 'unlink' && currentFile.value && currentFile.value.path === msg.path) {
      currentFile.value = null
    }
  }
}

onMounted(() => {
  loadTree()
  connectWs()
})

onBeforeUnmount(() => {
  clearTimeout(treeReloadTimer)
  clearTimeout(wsReconnectTimer)
  ws?.close()
})
</script>
