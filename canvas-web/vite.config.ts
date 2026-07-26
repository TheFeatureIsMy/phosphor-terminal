import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { viteSingleFile } from 'vite-plugin-singlefile'

export default defineConfig({
  // Inline all JS/CSS into a single index.html. The macOS app loads the canvas
  // via loadFileURL (file://), where ES-module + crossorigin assets are blocked
  // by CORS. A single self-contained HTML emits no sub-resource requests, so it
  // renders reliably from file:// without any private WKWebView flags.
  plugins: [react(), viteSingleFile()],
  base: './',
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    emptyOutDir: true,
  },
  test: {
    globals: true,
    environment: 'happy-dom',
  },
})
