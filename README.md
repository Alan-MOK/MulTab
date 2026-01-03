# MulTab

<p align="center">
  <strong>优雅的 macOS 窗口切换器 - 让多窗口管理变得简单</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014.0+-blue.svg" alt="Platform">
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License">
</p>

<p align="center">
  <a href="README.enUS.md">English</a> | 简体中文
</p>

## 💡 为什么选择 MulTab？

你是否经常在多个应用窗口之间来回切换？使用 macOS 自带的 `⌘ Tab` 只能切换应用，而不是窗口。当同一个应用打开多个窗口时（比如多个 Chrome 浏览器窗口），切换起来非常麻烦。

**MulTab 解决了这个痛点**，让你可以像 `⌘ Tab` 一样轻松地在**所有窗口**之间快速切换。

## ✨ 核心功能

### 🚀 一键切换所有窗口
按下 `⌥ Tab`（Option + Tab），或者`⌘ Tab` (Command + Tab) 瞬间看到所有应用的所有窗口，不再被限制于单个应用内切换。

### 🎨 优雅的视觉体验
- **完美融入 MacBook 刘海**：弹窗从刘海区域优雅展开，就像系统原生功能一样
- **流畅动画**：精心调校的回弹动画，丝滑流畅
- **窗口预览**：每个窗口都有缩略图预览，一目了然


### 🪶 轻量级设计
- 常驻菜单栏，不占用 Dock 空间
- 低内存占用，不影响系统性能
- 完全使用 SwiftUI 构建，原生体验

## 📸 预览

*即将添加截图和演示视频*

## 💾 安装

### 方式一：下载安装包（推荐）

📦 [下载 MulTab.dmg](https://github.com/Alan-MOK/MulTab/releases/latest/download/MulTab.dmg)

下载后双击 DMG 文件，将 MulTab 拖入应用程序文件夹即可。

### 方式二：从源代码构建

如果你是开发者，可以自己编译：

```bash
# 克隆仓库
git clone https://github.com/Alan-MOK/MulTab.git
cd MulTab

# 在 Xcode 中打开
open MulTab.xcodeproj

# 按 ⌘ R 编译运行
```

## 🎯 使用指南

### 第一次启动

1. 打开 MulTab，你会在菜单栏看到它的图标
2. 应用会请求**辅助功能权限**（必需）和**屏幕录制权限**（用于窗口预览）
3. 前往 **系统设置 → 隐私与安全性** 授予权限

### 开始使用

1. 按下 `⌥ Tab` 唤起窗口切换器
2. 保持按住 `⌥` 键，继续按 `Tab` 在窗口间循环
3. 松开 `⌥` 键，自动切换到选中的窗口

就是这么简单！

## ❓ 常见问题

**Q: 为什么需要辅助功能权限？**  
A: 这是系统要求，用于枚举窗口列表和激活窗口。没有此权限，应用无法工作。

**Q: 可以修改快捷键吗？**  
A: 当前版本固定为 `⌥ Tab`，未来版本会支持自定义。

**Q: 支持哪些 macOS 版本？**  
A: 需要 macOS 14.0（Sonoma）或更新版本。

**Q: 为什么看不到窗口预览？**  
A: 需要授予屏幕录制权限。前往 **系统设置 → 隐私与安全性 → 屏幕录制**，勾选 MulTab。

**Q: 会影响系统性能吗？**  
A: 不会。MulTab 只在你按下快捷键时才工作，平时几乎不占用资源。

## 🛠 系统要求

- macOS 14.0（Sonoma）或更高版本
- 支持所有搭载刘海的 MacBook 机型（M1/M2/M3 等）

## 📝 开源协议

本项目采用 MIT 协议开源，欢迎自由使用和修改。

## 💬 反馈与支持

遇到问题或有建议？欢迎：
- 提交 [Issue](https://github.com/Alan-MOK/MulTab/issues)
- 发起 [Pull Request](https://github.com/Alan-MOK/MulTab/pulls)
- 联系作者：Alan Mok

---

<p align="center">
  如果 MulTab 帮到了你，欢迎给个 ⭐️ Star
</p>

<p align="center">Made with ❤️ for macOS Users</p>
