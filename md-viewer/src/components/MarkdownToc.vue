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
        :style="{ paddingLeft: Math.min(item.level - 1, 3) * 10 + 'px' }"
        @click="scrollTo(item.id)"
      >
        {{ item.text }}
      </li>
    </ul>
  </nav>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { parseMarkdownHeadings } from '../utils/markdownHeadings'

const props = defineProps({
  source: String,
  container: { type: Object, default: null }
})

const items = computed(() => parseMarkdownHeadings(props.source))
const activeId = ref(null)
let observers = []

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
  const offset = scroller.scrollTop + targetRect.top - parentRect.top - 16
  scroller.scrollTo({ top: offset, behavior: 'smooth' })
}

function disconnectObservers() {
  for (const observer of observers) observer.disconnect()
  observers = []
}

function attachObservers() {
  disconnectObservers()

  const root = getScrollContainer()
  if (!root) return

  const headings = root.querySelectorAll('h1[id],h2[id],h3[id],h4[id],h5[id],h6[id]')
  for (const heading of headings) {
    const observer = new IntersectionObserver(
      entries => {
        const firstVisible = entries.find(entry => entry.isIntersecting)
        if (firstVisible) activeId.value = firstVisible.target.id
      },
      { root, rootMargin: '-16px 0px -75% 0px', threshold: 0 }
    )

    observer.observe(heading)
    observers.push(observer)
  }

  if (!activeId.value && headings.length) {
    activeId.value = headings[0].id
  }
}

onMounted(() => {
  watch(
    () => props.source,
    () => {
      activeId.value = null
      setTimeout(attachObservers, 150)
    },
    { immediate: true }
  )
})

onBeforeUnmount(disconnectObservers)
</script>
