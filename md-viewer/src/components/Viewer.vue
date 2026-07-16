<template>
  <div class="main">
    <div class="main-header" v-if="file">
      <span class="crumb">{{ file.path }}</span>
      <span class="meta" v-if="file.size != null">{{ formatSize(file.size) }} · {{ formatTime(file.mtime) }}</span>
    </div>
    <div class="viewer" ref="viewerRef">
      <div v-if="!file" class="empty">从左侧选择一个 Markdown、代码或配置文件</div>

      <!-- md 文件：TOC + 内容 -->
      <template v-else-if="file.ext === '.md'">
        <div class="md-layout">
          <MarkdownToc :source="file.content" :container="viewerRef" />
          <MarkdownView :source="file.content" :theme="theme" class="md-content" />
        </div>
      </template>

      <!-- 代码文件 -->
      <CodeView v-else :source="file.content" :lang="fileToLang(file)" :theme="theme" />
    </div>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue'
import MarkdownView from './MarkdownView.vue'
import MarkdownToc from './MarkdownToc.vue'
import CodeView from './CodeView.vue'

const props = defineProps({ file: Object, theme: String })
const viewerRef = ref(null)

// 切换文件时，目录和内容区域回到顶部
watch(() => props.file?.path, () => {
  if (!viewerRef.value) return
  const toc = viewerRef.value.querySelector('.toc')
  const content = viewerRef.value.querySelector('.md-content')
  if (toc) toc.scrollTop = 0
  if (content) content.scrollTop = 0
})

function fileToLang(file) {
  const fileName = (file?.path || '').split('/').pop().toLowerCase()
  const ext = (file?.ext || '').toLowerCase()

  if (fileName === 'dockerfile' || fileName === 'containerfile' || ext === '.dockerfile') return 'dockerfile'
  if (fileName === 'makefile') return 'plaintext'
  if (fileName === '.env' || fileName.startsWith('.env.') || ext === '.env' || ext === '.example') return 'ini'
  if (ext === '.ts' || ext === '.tsx') return 'typescript'
  if (['.js', '.jsx', '.mjs', '.cjs'].includes(ext)) return 'javascript'
  if (ext === '.json' || ext === '.jsonc') return 'json'
  if (ext === '.html' || ext === '.htm' || ext === '.vue') return 'html'
  if (ext === '.css') return 'css'
  if (ext === '.scss' || ext === '.sass') return 'scss'
  if (ext === '.less') return 'less'
  if (ext === '.yml' || ext === '.yaml') return 'yaml'
  if (ext === '.xml' || ext === '.svg') return 'xml'
  if (ext === '.sql') return 'sql'
  if (['.sh', '.bash', '.zsh'].includes(ext)) return 'shell'
  if (ext === '.ps1') return 'powershell'
  if (ext === '.bat' || ext === '.cmd') return 'bat'
  if (['.ini', '.properties', '.toml'].includes(ext)) return 'ini'
  return 'plaintext'
}

function formatSize(n) {
  if (n < 1024) return n + ' B'
  if (n < 1024 * 1024) return (n / 1024).toFixed(1) + ' KB'
  return (n / 1024 / 1024).toFixed(2) + ' MB'
}
function formatTime(ms) {
  if (!ms) return ''
  const d = new Date(ms)
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`
}
</script>
