// 路由类型定义
interface Route {
  path: string
  name: string
  description: string
  priority: number
  changefreq: string
}

// 应用路由配置
export const routes: Route[] = [
  // 移除根路径，让 vite-plugin-sitemap 自动处理
  // 如果需要其他路由，可以在这里添加
]

// 获取所有路由路径
export const getRoutePaths = () => routes.map(route => route.path)

// 获取路由元数据
export const getRouteMetadata = (path: string) => {
  return routes.find(route => route.path === path)
}
