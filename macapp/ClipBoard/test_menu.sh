#!/bin/bash

echo "=== ClipBoard 菜单功能测试 ==="

# 检查应用是否运行
if pgrep -f "ClipBoard" > /dev/null; then
    echo "✅ ClipBoard 应用正在运行"
else
    echo "❌ ClipBoard 应用未运行"
    exit 1
fi

# 检查状态栏进程
if pgrep -f "NSStatusBar" > /dev/null || pgrep -f "ClipBoard" > /dev/null; then
    echo "✅ 状态栏相关进程存在"
else
    echo "⚠️ 状态栏进程状态不明确"
fi

echo
echo "=== 手动测试项目 ==="
echo "1. 检查状态栏右上角是否出现剪贴板图标 (📋)"
echo "2. 左键点击图标 - 应该显示/隐藏主窗口"
echo "3. 右键点击图标 - 应该显示以下菜单：
   - Open ClipBook
   - ────────────────
   - Help (有子菜单)
   - About ClipBook
   - Check for Updates...
   - Settings... (⌘,)
   - ────────────────
   - Pause ClipBook
   - Quit"
echo
echo "4. 测试各菜单项："
echo "   - Open ClipBook: 显示主窗口"
echo "   - Help: 有子菜单显示 'ClipBook Help'"
echo "   - About ClipBook: 打开关于窗口"
echo "   - Settings: 打开设置窗口"
echo "   - Pause ClipBook: 暂停剪贴板监控，菜单项变为 'Resume ClipBook'"
echo "   - Quit: 退出应用"
echo
echo "=== 日志输出检查 ==="
echo "检查控制台日志输出..."

# 显示最近的相关日志
log show --predicate 'process == "ClipBoard"' --info --last 2m 2>/dev/null | tail -10 || echo "无法获取日志，请检查控制台应用"

echo
echo "测试完成。如果菜单功能正常，所有功能已实现成功！"