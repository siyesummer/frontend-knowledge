export function findFileNode(root, targetPath) {
  if (!root || !targetPath) return null
  if (root.type === 'file') return root.path === targetPath ? root : null

  for (const child of root.children || []) {
    const match = findFileNode(child, targetPath)
    if (match) return match
  }
  return null
}

export function getKnowledgePath(search) {
  const value = new URLSearchParams(search).get('path')?.trim()
  if (!value || value.startsWith('/') || value.includes('\\')) return null

  const segments = value.split('/')
  if (segments.some(segment => !segment || segment === '.' || segment === '..')) return null
  return value
}
