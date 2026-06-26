<template>
  <div class="monaco-wrap" ref="el"></div>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount, watch } from 'vue'
import * as monaco from 'monaco-editor'

const props = defineProps({
  source: String,
  lang: String,
  theme: { type: String, default: 'light' }
})

const el = ref(null)
let editor = null

function monacoTheme(t) {
  return t === 'dark' ? 'vs-dark' : 'vs'
}

onMounted(() => {
  editor = monaco.editor.create(el.value, {
    value: props.source || '',
    language: props.lang || 'plaintext',
    theme: monacoTheme(props.theme),
    readOnly: true,
    automaticLayout: true,
    minimap: { enabled: true },
    fontSize: 15,
    lineNumbers: 'on',
    scrollBeyondLastLine: false,
    wordWrap: 'on',
    tabSize: 2,
    renderWhitespace: 'selection',
    bracketPairColorization: { enabled: true },
    guides: { bracketPairs: true },
    smoothScrolling: true,
  })
})

onBeforeUnmount(() => {
  editor?.dispose()
})

// 文件内容变化：更新 + 滚动到顶部
watch(() => props.source, (v) => {
  if (!editor) return
  editor.setValue(v || '')
  editor.setScrollTop(0)
})

// 语言变化：切换语言模式
watch(() => props.lang, (v) => {
  if (!editor) return
  const model = editor.getModel()
  if (model) monaco.editor.setModelLanguage(model, v || 'plaintext')
})

// 主题变化
watch(() => props.theme, (v) => {
  monaco.editor.setTheme(monacoTheme(v))
})
</script>
