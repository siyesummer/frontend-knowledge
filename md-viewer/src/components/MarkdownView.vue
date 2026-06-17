<template>
  <div class="markdown-body" v-html="html"></div>
</template>

<script setup>
import { computed, watch, nextTick, onMounted } from 'vue'
import MarkdownIt from 'markdown-it'
import hljs from 'highlight.js'

// 两套 highlight 主题 CSS，按 theme 动态切换
import darkHljs from 'highlight.js/styles/github-dark.css?inline'
import lightHljs from 'highlight.js/styles/github.css?inline'

const props = defineProps({
  source: String,
  theme: { type: String, default: 'light' }
})

function slugify(text) {
  return text
    .toLowerCase()
    .replace(/[^\w一-鿿\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '')
}

const md = new MarkdownIt({
  html: true,
  linkify: true,
  breaks: false,
  highlight(code, lang) {
    if (lang && hljs.getLanguage(lang)) {
      try {
        return `<pre class="hljs"><code>${hljs.highlight(code, { language: lang, ignoreIllegals: true }).value}</code></pre>`
      } catch {}
    }
    return `<pre class="hljs"><code>${md.utils.escapeHtml(code)}</code></pre>`
  }
})

// ★ 覆盖标题渲染规则：加上 id 属性，让 TOC 的 scrollTo 能定位
const defaultHeading = md.renderer.rules.heading_open || function (tokens, idx, options, env, self) {
  return self.renderToken(tokens, idx, options)
}
md.renderer.rules.heading_open = (tokens, idx, options, env, self) => {
  const token = tokens[idx]
  const level = token.tag
  // 向后找 inline token 拿到纯文本
  let i = idx + 1
  while (i < tokens.length && tokens[i].type !== 'heading_close') {
    if (tokens[i].type === 'inline') {
      const text = tokens[i].content.replace(/<[^>]+>/g, '').trim()
      const id = slugify(text) || 'h'
      token.attrSet('id', id)
      break
    }
    i++
  }
  return defaultHeading(tokens, idx, options, env, self)
}

const html = computed(() => md.render(props.source || ''))

// 用 <style id="hljs-theme"> 动态注入高亮主题
function applyHljsTheme(t) {
  const id = 'hljs-theme'
  let el = document.getElementById(id)
  if (!el) {
    el = document.createElement('style')
    el.id = id
    document.head.appendChild(el)
  }
  el.textContent = t === 'dark' ? darkHljs : lightHljs
}
watch(() => props.theme, applyHljsTheme, { immediate: true })
</script>
