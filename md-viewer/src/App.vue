<template>
  <aside class="sidebar">
    <div class="sidebar-header">
      <span class="sidebar-title">📁 {{ tree?.name || 'loading...' }}</span>
      <button
        class="theme-toggle"
        :title="theme === 'dark' ? '切换到亮色' : '切换到暗色'"
        @click="toggleTheme"
      >
        {{ theme === 'dark' ? '☀️' : '🌙' }}
      </button>
      <span class="ws-status" :class="wsState">
        <span class="dot"></span>
        {{ wsLabel }}
      </span>
    </div>
    <FileTree
      :root="tree"
      :active-path="currentFile?.path"
      :changed-paths="changedPaths"
      @pick="openFile"
    />
  </aside>

  <Viewer :file="currentFile" :theme="theme" />
</template>

<script setup>
import { ref, reactive, onMounted, onBeforeUnmount, provide, watch } from 'vue'
import FileTree from './components/FileTree.vue'
import Viewer from './components/Viewer.vue'

const tree = ref(null)
const currentFile = ref(null)
const changedPaths = reactive(new Set())
const wsState = ref('connecting')   // connecting | connected | error
const wsLabel = ref('连接中')

// ============ 主题 ============
const THEME_KEY = 'mdviewer:theme'
function getInitialTheme() {
  const saved = localStorage.getItem(THEME_KEY)
  if (saved === 'dark' || saved === 'light') return saved
  return window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
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
    const res = await fetch('/api/tree')
    tree.value = await res.json()
  } catch (e) {
    console.error(e)
  }
}

async function openFile(node) {
  try {
    const res = await fetch('/api/file?path=' + encodeURIComponent(node.path))
    if (!res.ok) {
      const err = await res.json().catch(() => ({}))
      throw new Error(err.error || res.statusText)
    }
    currentFile.value = await res.json()
  } catch (e) {
    console.error(e)
    alert('文件加载失败：' + e.message)
  }
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
