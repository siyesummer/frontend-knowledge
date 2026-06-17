<template>
  <nav class="toc" v-if="items.length">
    <div class="toc-header">目录</div>
    <ul class="toc-list">
      <li
        v-for="item in items"
        :key="item.id"
        class="toc-item"
        :class="{
          'toc-h1': item.level === 1,
          'toc-h2': item.level === 2,
          'toc-h3': item.level >= 3,
          'toc-active': item.id === activeId
        }"
        :style="{ paddingLeft: Math.min((item.level - 1), 3) * 10 + 'px' }"
        @click="scrollTo(item.id)"
      >
        {{ item.text }}
      </li>
    </ul>
  </nav>
</template>

<script setup>
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue'

const props = defineProps({
  source: String,
  container: { type: Object, default: null }
})

/**
 * 从原始 markdown 中提取标题列表
 */
const items = computed(() => {
  const lines = (props.source || '').split('\n')
  const results = []
  for (const line of lines) {
    const m = line.match(/^(#{1,6})\s+(.+?)(?:\s*\{#[\w-]+\})?\s*$/)
    if (!m) continue
    const level = m[1].length
    const text = m[2].replace(/<[^>]+>/g, '').trim()
    const id = slugify(text)
    results.push({ level, text, id })
  }
  return results
})

function slugify(text) {
  return text
    .toLowerCase()
    .replace(/[^\w一-鿿\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '')
}

/**
 * 找到 .md-content 这个滚动容器，精确控制它的 scrollTop
 * 注意：Vue 3 模板中 ref 会自动 .value 解包，
 *       所以 props.container 已经是 DOM 元素本身，不要再 .value
 */
function getScrollContainer() {
  const el = props.container
  if (!el) return null
  return el.querySelector('.md-content')
}

function scrollTo(id) {
  const el = document.getElementById(id)
  const scroller = getScrollContainer()
  if (!el || !scroller) return
  const parentRect = scroller.getBoundingClientRect()
  const targetRect = el.getBoundingClientRect()
  // 计算目标元素在滚动容器内的相对偏移
  const offset = scroller.scrollTop + targetRect.top - parentRect.top - 16
  scroller.scrollTo({ top: offset, behavior: 'smooth' })
}

// ============ 监听滚动，高亮当前可见标题 ============
const activeId = ref(null)
let observer = null

onMounted(() => {
  observer = new IntersectionObserver(
    entries => {
      const firstVisible = entries.find(e => e.isIntersecting)
      if (firstVisible) {
        activeId.value = firstVisible.target.id
      }
    },
    {
      // ★ 以 .md-content 为视口基准，不是整个浏览器窗口
      rootMargin: '-16px 0px -75% 0px',
      threshold: 0
    }
  )
  watch(() => props.source, () => {
    setTimeout(attachObserver, 150)
  }, { immediate: true })
})

onBeforeUnmount(() => observer?.disconnect())

function attachObserver() {
  observer?.disconnect()
  // 找到滚动容器作为 observer 的 root
  const root = getScrollContainer()
  if (!root) return
  // 找到容器内所有带 id 的标题
  const hs = root.querySelectorAll('h1[id],h2[id],h3[id],h4[id]')
  for (const h of hs) {
    // 显式指定 root，而非全局 document
    const ob = new IntersectionObserver(
      entries => {
        const first = entries.find(e => e.isIntersecting)
        if (first) activeId.value = first.target.id
      },
      { root, rootMargin: '-16px 0px -75% 0px', threshold: 0 }
    )
    ob.observe(h)
  }
}
</script>
