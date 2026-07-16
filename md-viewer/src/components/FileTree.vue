<template>
  <div class="tree-wrap">
    <Node
      v-if="filteredRoot"
      :node="filteredRoot"
      :depth="0"
      :active-path="activePath"
      :changed-paths="changedPaths"
      :expanded-paths="expandedPaths"
      :force-open="hasQuery"
      @pick="emit('pick', $event)"
      @toggle="toggleDirectory"
    />
    <div v-else class="tree-empty">
      没有找到“{{ query }}”
    </div>
  </div>
</template>

<script setup>
import { computed, nextTick, reactive, watch } from 'vue'
import Node from './FileTreeNode.vue'

const props = defineProps({
  root: Object,
  activePath: String,
  changedPaths: Set,
  query: { type: String, default: '' }
})
const emit = defineEmits(['pick'])

const expandedPaths = reactive(new Set())
const normalizedQuery = computed(() => props.query.trim().toLocaleLowerCase())
const hasQuery = computed(() => Boolean(normalizedQuery.value))

const filteredRoot = computed(() => {
  if (!props.root || !hasQuery.value) return props.root
  return filterNode(props.root, normalizedQuery.value)
})

watch(
  () => props.root,
  root => {
    if (root?.path != null) expandedPaths.add(root.path)
  },
  { immediate: true }
)

function filterNode(node, query) {
  const selfMatches = node.name.toLocaleLowerCase().includes(query)
    || node.path.toLocaleLowerCase().includes(query)

  if (node.type === 'file') return selfMatches ? node : null
  if (selfMatches) return node

  const children = (node.children || [])
    .map(child => filterNode(child, query))
    .filter(Boolean)

  if (children.length === 0) return null
  return { ...node, children }
}

function toggleDirectory(path) {
  if (expandedPaths.has(path)) expandedPaths.delete(path)
  else expandedPaths.add(path)
}

function collapseAll() {
  expandedPaths.clear()
  if (props.root?.path != null) expandedPaths.add(props.root.path)
}

async function revealActive() {
  if (!props.activePath) return
  const segments = props.activePath.split('/')
  expandedPaths.add(props.root?.path || '')
  for (let index = 1; index < segments.length; index++) {
    expandedPaths.add(segments.slice(0, index).join('/'))
  }

  await nextTick()
  const rows = document.querySelectorAll('.tree-wrap .node-row')
  const row = [...rows].find(element => element.dataset.path === props.activePath)
  row?.scrollIntoView({ block: 'center', behavior: 'smooth' })
}

defineExpose({ collapseAll, revealActive })
</script>
