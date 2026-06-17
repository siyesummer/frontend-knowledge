<template>
  <div class="node">
    <div
      class="node-row"
      :class="{
        active: !isDir && activePath === node.path,
        changed: changedPaths && changedPaths.has(node.path)
      }"
      :style="{ paddingLeft: (4 + depth * 14) + 'px' }"
      @click="onClick"
    >
      <span class="arrow">
        <template v-if="isDir">{{ open ? '▾' : '▸' }}</template>
      </span>
      <span class="icon">{{ icon }}</span>
      <span class="name">{{ node.name }}</span>
    </div>
    <div v-if="isDir && open" class="node-children">
      <Node
        v-for="child in node.children"
        :key="child.path"
        :node="child"
        :depth="depth + 1"
        :active-path="activePath"
        :changed-paths="changedPaths"
        @pick="$emit('pick', $event)"
      />
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'

const props = defineProps({
  node: Object,
  depth: Number,
  activePath: String,
  changedPaths: Set
})
const emit = defineEmits(['pick'])

const isDir = computed(() => props.node.type === 'dir')
const open = ref(props.depth < 1)   // 默认展开第一层

const icon = computed(() => {
  if (isDir.value) return open.value ? '📂' : '📁'
  const ext = (props.node.ext || '').toLowerCase()
  if (ext === '.md') return '📝'
  if (ext === '.js' || ext === '.ts') return '📜'
  if (ext === '.json') return '🔧'
  if (ext === '.vue') return '🟢'
  if (ext === '.html') return '🌐'
  if (ext === '.css') return '🎨'
  return '📄'
})

function onClick() {
  if (isDir.value) {
    open.value = !open.value
  } else {
    emit('pick', props.node)
  }
}
</script>

<script>
// 自引用名字（递归组件）
export default { name: 'Node' }
</script>
