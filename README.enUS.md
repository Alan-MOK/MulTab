# MulTab

<p align="center">
  <strong>An Elegant macOS Window Switcher - Simplifying Multi-Window Management</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014.0+-blue.svg" alt="Platform">
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License">
</p>

<p align="center">
  English | <a href="README.md">简体中文</a>
</p>


## 💡 Why MulTab?

Do you frequently switch between multiple application windows? macOS's built-in `⌘ Tab` only switches between applications, not windows. When you have multiple windows open in the same app (like multiple Chrome browser windows), switching becomes tedious.

**MulTab solves this pain point**, allowing you to effortlessly switch between **all windows** just like `⌘ Tab`.

## ✨ Core Features

### 🚀 One-Key Window Switching
Press `⌥ Tab` (Option + Tab) or `⌘ Tab` (Command + Tab) to instantly view all windows from all applications, no longer limited to switching within a single app.

### 🎨 Elegant Visual Experience
- **Perfect Notch Integration**: The switcher elegantly drops down from the notch area, just like a native system feature
- **Smooth Animations**: Carefully tuned spring animations for a silky-smooth experience
- **Window Previews**: Each window shows a thumbnail preview for easy identification

### 🪶 Lightweight Design
- Lives in the menu bar, doesn't occupy Dock space
- Low memory footprint, no impact on system performance
- Built entirely with SwiftUI for native experience

## 📸 Preview

*Screenshots and demo video coming soon*

## 💾 Installation

### Option 1: Download Installation Package (Recommended)

📦 [Download MulTab.dmg](https://github.com/Alan-MOK/MulTab/releases/latest/download/MulTab.dmg)

After downloading, double-click the DMG file and drag MulTab to your Applications folder.

### Option 2: Build from Source

If you're a developer, you can compile it yourself:

```bash
# Clone the repository
git clone https://github.com/Alan-MOK/MulTab.git
cd MulTab

# Open in Xcode
open MulTab.xcodeproj

# Press ⌘ R to build and run
```

## 🎯 Usage Guide

### First Launch

1. Open MulTab, you'll see its icon in the menu bar
2. The app will request **Accessibility permission** (required) and **Screen Recording permission** (for window previews)
3. Go to **System Settings → Privacy & Security** to grant permissions

### Getting Started

1. Press `⌥ Tab` to invoke the window switcher
2. Keep holding `⌥` and continue pressing `Tab` to cycle through windows
3. Release `⌥` to automatically switch to the selected window

It's that simple!

## ❓ FAQ

**Q: Why does it need Accessibility permission?**  
A: This is a system requirement for enumerating window lists and activating windows. Without this permission, the app cannot function.

**Q: Can I customize the hotkey?**  
A: The current version is fixed to `⌥ Tab`. Future versions will support customization.

**Q: Which macOS versions are supported?**  
A: Requires macOS 14.0 (Sonoma) or later.

**Q: Why can't I see window previews?**  
A: You need to grant Screen Recording permission. Go to **System Settings → Privacy & Security → Screen Recording** and check MulTab.

**Q: Will it affect system performance?**  
A: No. MulTab only works when you press the hotkey and uses minimal resources when idle.

## 🛠 System Requirements

- macOS 14.0 (Sonoma) or later
- Supports all MacBook models with notch (M1/M2/M3, etc.)

## 📝 License

This project is open source under the MIT License. Feel free to use and modify.

## 💬 Feedback & Support

Have issues or suggestions? Feel free to:
- Submit an [Issue](https://github.com/Alan-MOK/MulTab/issues)
- Create a [Pull Request](https://github.com/Alan-MOK/MulTab/pulls)
- Contact the author: Alan Mok

---

<p align="center">
  If MulTab helped you, please give it a ⭐️ Star
</p>

<p align="center">Made with ❤️ for macOS Users</p>
