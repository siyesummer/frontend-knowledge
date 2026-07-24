import assert from 'node:assert/strict'
import test from 'node:test'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { loadPublicPolicy } from '../public-policy.js'

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..')

test('public knowledge policy keeps tutorials and blocks internal deployment material', async () => {
  const policy = await loadPublicPolicy(repoRoot)

  assert.equal(policy.isPublic('前端知识点/01-JavaScript基础.md'), true)
  assert.equal(policy.isPublic('Docker专题/Docker命令说明.md'), true)
  assert.equal(policy.isPublic('AGENTS.md'), false)
  assert.equal(policy.isPublic('Docker专题/Docker演练/siye-stack/docker-compose.yml'), false)
  assert.equal(policy.isPublic('Docker专题/正式部署/siye-stack/README.md'), false)
  assert.equal(policy.isPublic('Linux部署/README.md'), false)
  assert.equal(policy.isPublic('md-viewer/server/index.js'), false)
})

test('public knowledge policy also blocks nested files requested with Windows separators', async () => {
  const policy = await loadPublicPolicy(repoRoot)

  assert.equal(policy.isPublic('Docker专题\\正式部署\\siye-stack\\edge\\compose.yml'), false)
})
