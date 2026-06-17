<template>
  <div class="tree-wrap">
    <Node v-if="root" :node="root" :depth="0" :active-path="activePath" :changed-paths="changedPaths" @pick="emit('pick', $event)" />
  </div>
</template>

<script setup>
import Node from './FileTreeNode.vue'

defineProps({
  root: Object,
  activePath: String,
  changedPaths: Set
})
const emit = defineEmits(['pick'])
</script>
