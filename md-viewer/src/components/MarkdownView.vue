<template>
  <div class="markdown-body" v-html="html"></div>
</template>

<script setup>
import { computed, watch } from 'vue'
import MarkdownIt from 'markdown-it'
import hljs from 'highlight.js'
import darkHljs from 'highlight.js/styles/github-dark.css?inline'
import lightHljs from 'highlight.js/styles/github.css?inline'
import { createUniqueHeadingIdFactory, extractHeadingText } from '../utils/markdownHeadings'

const props = defineProps({
  source: String,
  theme: { type: String, default: 'light' }
})

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

const defaultHeadingOpen =
  md.renderer.rules.heading_open ||
  function (tokens, idx, options, env, self) {
    return self.renderToken(tokens, idx, options)
  }

md.renderer.rules.heading_open = (tokens, idx, options, env, self) => {
  const token = tokens[idx]
  let i = idx + 1

  while (i < tokens.length && tokens[i].type !== 'heading_close') {
    if (tokens[i].type === 'inline') {
      const text = extractHeadingText(tokens[i].content)
      const nextId = env?.nextHeadingId || (() => 'h')
      token.attrSet('id', nextId(text))
      break
    }
    i++
  }

  return defaultHeadingOpen(tokens, idx, options, env, self)
}

const html = computed(() =>
  md.render(props.source || '', {
    nextHeadingId: createUniqueHeadingIdFactory()
  })
)

function applyHljsTheme(theme) {
  const id = 'hljs-theme'
  let el = document.getElementById(id)
  if (!el) {
    el = document.createElement('style')
    el.id = id
    document.head.appendChild(el)
  }
  el.textContent = theme === 'dark' ? darkHljs : lightHljs
}

watch(() => props.theme, applyHljsTheme, { immediate: true })
</script>
