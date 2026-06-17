import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import monacoEditorPlugin from 'vite-plugin-monaco-editor'
import path from 'path'

export default defineConfig({
  plugins: [
    vue(),
    // ★ 自动处理 Monaco 的 worker 文件，JS/TS 等语法高亮靠这个
    (monacoEditorPlugin.default || monacoEditorPlugin)({
      languageWorkers: ['editorWorkerService', 'typescript', 'json', 'css', 'html']
    })
  ],
  root: 'src',
  publicDir: false,
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src')
    }
  },
  server: {
    port: 5173,
    proxy: {
      '/api': 'http://localhost:3001',
      '/ws': { target: 'ws://localhost:3001', ws: true }
    }
  }
})
