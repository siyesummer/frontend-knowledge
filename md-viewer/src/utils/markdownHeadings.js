export function slugifyHeading(text) {
  return text
    .toLowerCase()
    .replace(/[^\w\u4e00-\u9fff\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '')
}

export function extractHeadingText(rawText) {
  return (rawText || '').replace(/<[^>]+>/g, '').trim()
}

export function createUniqueHeadingIdFactory() {
  const counts = new Map()

  return text => {
    const base = slugifyHeading(text) || 'h'
    const index = counts.get(base) || 0
    counts.set(base, index + 1)
    return index === 0 ? base : `${base}-${index}`
  }
}

export function parseMarkdownHeadings(source) {
  const lines = (source || '').split('\n')
  const results = []
  const nextId = createUniqueHeadingIdFactory()

  for (const line of lines) {
    const match = line.match(/^(#{1,6})\s+(.+?)(?:\s*\{#[\w-]+\})?\s*$/)
    if (!match) continue

    const level = match[1].length
    const text = extractHeadingText(match[2])
    results.push({
      level,
      text,
      id: nextId(text)
    })
  }

  return results
}
