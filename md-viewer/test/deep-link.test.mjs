import assert from 'node:assert/strict'
import test from 'node:test'
import { findFileNode, getKnowledgePath } from '../src/utils/deepLink.js'

const tree = {
  type: 'dir',
  path: '',
  children: [
    {
      type: 'dir',
      path: 'Docker专题',
      children: [
        { type: 'file', path: 'Docker专题/Docker命令说明.md', name: 'Docker命令说明.md' }
      ]
    }
  ]
}

test('reads a safe knowledge path from the query string', () => {
  assert.equal(
    getKnowledgePath('?path=Docker%E4%B8%93%E9%A2%98%2FDocker%E5%91%BD%E4%BB%A4%E8%AF%B4%E6%98%8E.md'),
    'Docker专题/Docker命令说明.md'
  )
  assert.equal(getKnowledgePath('?path=../AGENTS.md'), null)
  assert.equal(getKnowledgePath('?path=%2Fetc%2Fpasswd'), null)
})

test('finds the exact public file represented by a deep link', () => {
  assert.equal(findFileNode(tree, 'Docker专题/Docker命令说明.md')?.name, 'Docker命令说明.md')
  assert.equal(findFileNode(tree, 'Docker命令说明.md'), null)
})
