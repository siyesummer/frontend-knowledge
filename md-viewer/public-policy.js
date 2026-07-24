import fs from 'node:fs/promises'
import path from 'node:path'

const POLICY_FILE = 'knowledge-public.json'

function normalize(value) {
  return value.replaceAll('\\', '/').replace(/^\.\//, '').replace(/\/$/, '')
}

export async function loadPublicPolicy(root) {
  const policyPath = path.join(root, POLICY_FILE)
  const configured = JSON.parse(await fs.readFile(policyPath, 'utf8'))
  if (!Array.isArray(configured.excludedPaths) || configured.excludedPaths.some(value => typeof value !== 'string')) {
    throw new Error(`${POLICY_FILE} must contain a string array named excludedPaths`)
  }

  const excludedPaths = new Set(configured.excludedPaths.map(normalize))

  return {
    isPublic(relativePath) {
      const normalized = normalize(relativePath)
      return ![...excludedPaths].some(
        excluded => normalized === excluded || normalized.startsWith(`${excluded}/`)
      )
    }
  }
}
