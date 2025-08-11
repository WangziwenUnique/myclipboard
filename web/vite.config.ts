import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import Sitemap from 'vite-plugin-sitemap'
import { getRoutePaths } from './src/routes'

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    react(),
    Sitemap({
      hostname: 'https://myclipboard.org', // 替换为你的实际域名
      dynamicRoutes: getRoutePaths(),
      exclude: ['/admin', '/private'], // 排除不需要索引的路由
      changefreq: 'weekly', // 默认更新频率
      priority: 1.0, // 默认优先级
      outDir: 'dist', // 输出目录
      generateRobotsTxt: true, // 自动生成 robots.txt
    }),
  ],
  assetsInclude: ['**/*.riv'],
})
