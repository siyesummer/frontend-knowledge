<template>
  <div class="node">
    <div
      class="node-row"
      :class="{
        active: !isDir && activePath === node.path,
        changed: changedPaths && changedPaths.has(node.path)
      }"
      :style="{ paddingLeft: (8 + depth * 14) + 'px' }"
      :data-path="node.path"
      :title="node.path || node.name"
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
        :expanded-paths="expandedPaths"
        :force-open="forceOpen"
        @pick="$emit('pick', $event)"
        @toggle="$emit('toggle', $event)"
      />
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  node: Object,
  depth: Number,
  activePath: String,
  changedPaths: Set,
  expandedPaths: Set,
  forceOpen: Boolean
})
const emit = defineEmits(['pick', 'toggle'])

const isDir = computed(() => props.node.type === 'dir')
const open = computed(() => props.forceOpen || props.expandedPaths?.has(props.node.path))

const icon = computed(() => {
  if (isDir.value) return open.value ? '📂' : '📁'
  const fileName = (props.node.name || '').toLowerCase()
  const ext = (props.node.ext || '').toLowerCase()
  if (ext === '.md') return '📝'
  if (['.js', '.jsx', '.mjs', '.cjs', '.ts', '.tsx'].includes(ext)) return '📜'
  if (ext === '.json' || ext === '.jsonc') return '🔧'
  if (ext === '.vue') return '🟢'
  if (ext === '.html') return '🌐'
  if (['.css', '.scss', '.sass', '.less'].includes(ext)) return '🎨'
  if (ext === '.yml' || ext === '.yaml') return '⚙️'
  if (fileName === 'dockerfile' || fileName === 'containerfile' || ext === '.dockerfile') return '🐳'
  if (fileName === '.env' || fileName.startsWith('.env.') || ext === '.env' || ext === '.example') return '🔐'
  if (ext === '.sql') return '🗄️'
  if (['.sh', '.bash', '.zsh', '.ps1', '.bat', '.cmd'].includes(ext)) return '⌨️'
  if (['.conf', '.config', '.ini', '.properties', '.toml', '.template'].includes(ext)) return '⚙️'
  return '📄'
})

function onClick() {
  if (isDir.value) {
    emit('toggle', props.node.path)
  } else {
    emit('pick', props.node)
  }
}
</script>

<script>
// 自引用名字（递归组件）
export default { name: 'Node' }
</script>
