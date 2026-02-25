//
//  AppDelegate.swift
//  MulTab
//
//  Created by Alan Mok on 2025/12/30.
//

import SwiftUI
import AppKit

import Combine

/// 应用代理
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties
    private let hotkeyManager = HotkeyManager.shared
    private let windowManager = WindowManager.shared
    private let permissionManager = PermissionManager.shared
    private let preferencesManager = PreferencesManager.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var statusItem: NSStatusItem!
    private var switcherWindow: NSWindow?
    private var switcherHostingView: NSHostingView<WindowSwitcherView>?
    private var switcherViewModel: SwitcherViewModel?
    private var isShowingSwitcher = false
    private var localMonitor: Any?
    
    // 记录触发切换器时的前台应用
    private var targetAppPID: pid_t?
    private var targetAppBundleID: String?
    
    // MARK: - Lifecycle
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupApp()
        checkPermissions()
        registerHotkeys()
        setupLocalMonitor()
        observeHotkeyChanges()
        observeMenuBarIconChanges()
        
        // 启动时显示偏好设置窗口
        showPreferences()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregisterHotkey()
        hotkeyManager.stopSystemHotkeyInterception()
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    /// 用户再次双击应用时调用（应用已在运行）
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPreferences()
        return true
    }
    
    // MARK: - Setup
    private func setupApp() {
        // 隐藏 Dock 图标
        NSApp.setActivationPolicy(.accessory)
        
        // 始终创建状态栏图标，通过 isVisible 控制显隐
        setupStatusBar()
        statusItem.isVisible = !preferencesManager.hideMenuBarIcon
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // 使用自定义图标
            if let icon = NSImage(named: "MulTabIcon") {
                icon.size = NSSize(width: 18, height: 18)
                icon.isTemplate = true  // 使图标适应系统主题（亮色/暗色）
                button.image = icon
            } else {
                // 备用：使用系统图标
                button.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "MulTab")
            }
        }
        
        let menu = NSMenu()
        // menu.addItem(NSMenuItem(title: "Test Window Detection", action: #selector(testWindowDetection), keyEquivalent: "t"))
        // menu.addItem(NSMenuItem.separator())
        
        // Hotkey 选择子菜单
        let hotkeyMenuItem = NSMenuItem(title: "Hotkey", action: nil, keyEquivalent: "")
        let hotkeySubmenu = NSMenu()
        
        let cmdTabItem = NSMenuItem(title: "⌘ Command + Tab", action: #selector(selectCommandTab), keyEquivalent: "")
        cmdTabItem.tag = 0
        hotkeySubmenu.addItem(cmdTabItem)
        
        let optTabItem = NSMenuItem(title: "⌥ Option + Tab", action: #selector(selectOptionTab), keyEquivalent: "")
        optTabItem.tag = 1
        hotkeySubmenu.addItem(optTabItem)
        
        hotkeyMenuItem.submenu = hotkeySubmenu
        menu.addItem(hotkeyMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About MulTab", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        // 设置菜单代理以更新选中状态
        menu.delegate = self
        
        statusItem.menu = menu
    }
    
    private func updateStatusItemVisibility() {
        // 确保 statusItem 存在
        if statusItem == nil {
            setupStatusBar()
        }
        statusItem.isVisible = !preferencesManager.hideMenuBarIcon
    }
    
    @objc private func testWindowDetection() {
        print("\n🔍 Testing window detection...")
        
        let hasAccess = permissionManager.hasAccessibility
        print("📋 Accessibility permission: \(hasAccess ? "✅ Granted" : "❌ Not granted")")
        
        if !hasAccess {
            permissionManager.requestAccessibility()
            return
        }
        
        let result = windowManager.getAllWindows()
        
        switch result {
        case .success(let windows):
            print("\n✅ Found \(windows.count) windows:")
            for (index, window) in windows.enumerated() {
                print("  [\(index)] \(window.appName): \(window.title)")
            }
        case .failure(let error):
            print("❌ Failed to get windows: \(error)")
        }
        
        print("\n--- End of test ---\n")
    }
    
    private func checkPermissions() {
        permissionManager.updatePermissionStatus()
        
        if !permissionManager.hasAccessibility {
            showPermissionAlert()
        }
    }
    
    private func registerHotkeys() {
        let hotkeyType = preferencesManager.hotkeyType
        let modifier = hotkeyType.modifier
        
        let result = hotkeyManager.registerHotkey(
            keyCode: KeyCode.tab.rawValue,
            modifiers: modifier.carbon,
            onPress: { [weak self] reverse in
                self?.handleHotkeyPressed(reverse: reverse)
            },
            onRelease: { [weak self] in
                self?.handleHotkeyReleased()
            }
        )
        
        switch result {
        case .success:
            print("✅ Hotkey registered successfully: \(hotkeyType.displayName)")
            // 如果使用 Command+Tab，需要屏蔽系统热键
            if hotkeyType == .commandTab {
                hotkeyManager.startSystemHotkeyInterception()
            }
        case .failure(let error):
            print("❌ Failed to register hotkey: \(error)")
            
            // 如果 Command+Tab 失败（通常是权限问题），自动回退到 Option+Tab
            if hotkeyType == .commandTab {
                print("🔄 Falling back to Option+Tab mode...")
                preferencesManager.hotkeyType = .optionTab
                
                // 尝试用 Option+Tab 重新注册
                let fallbackResult = hotkeyManager.registerHotkey(
                    keyCode: KeyCode.tab.rawValue,
                    modifiers: ModifierKey.option.carbon,
                    onPress: { [weak self] reverse in
                        self?.handleHotkeyPressed(reverse: reverse)
                    },
                    onRelease: { [weak self] in
                        self?.handleHotkeyReleased()
                    }
                )
                
                switch fallbackResult {
                case .success:
                    print("✅ Fallback hotkey registered: Option+Tab")
                    showCommandTabPermissionAlert()
                case .failure(let fallbackError):
                    print("❌ Fallback also failed: \(fallbackError)")
                    showHotkeyError(fallbackError)
                }
            } else {
                showHotkeyError(error)
            }
        }
    }
    
    private func setupLocalMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self, self.isShowingSwitcher else { return event }
            
            if event.type == .keyDown {
                if event.keyCode == KeyCode.tab.rawValue {
                    if event.modifierFlags.contains(.shift) {
                        self.switcherSelectPrevious()
                    } else {
                        self.switcherSelectNext()
                    }
                    return nil
                }
                
                if event.keyCode == KeyCode.escape.rawValue {
                    self.hideSwitcher(activate: false)
                    return nil
                }
            }
            
            if event.type == .flagsChanged {
                let hotkeyType = self.preferencesManager.hotkeyType
                let shouldHide: Bool
                switch hotkeyType {
                case .optionTab:
                    shouldHide = !event.modifierFlags.contains(.option)
                case .commandTab:
                    shouldHide = !event.modifierFlags.contains(.command)
                }
                if shouldHide && self.isShowingSwitcher {
                    self.hideSwitcher(activate: true)
                    return nil
                }
            }
            
            return event
        }
    }
    
    // MARK: - Hotkey Handlers
    private func handleHotkeyPressed(reverse: Bool) {
        guard permissionManager.hasAccessibility else {
            permissionManager.requestAccessibility()
            return
        }
        
        if isShowingSwitcher {
            if reverse {
                switcherSelectPrevious()
            } else {
                switcherSelectNext()
            }
        } else {
            showSwitcher()
        }
    }
    
    private func handleHotkeyReleased() {
        // 由 localMonitor 处理
    }
    
    // MARK: - Switcher Control
    private func switcherSelectNext() {
        guard let viewModel = switcherViewModel else {
            print("⚠️ No viewModel available")
            return
        }
        viewModel.selectNext()
        print("➡️ Selected next: index \(viewModel.selectedIndex)")
    }
    
    private func switcherSelectPrevious() {
        guard let viewModel = switcherViewModel else {
            print("⚠️ No viewModel available")
            return
        }
        viewModel.selectPrevious()
        print("⬅️ Selected previous: index \(viewModel.selectedIndex)")
    }
    
    private func showSwitcher() {
        guard !isShowingSwitcher else { return }
        
        // 记录触发时的前台应用（但实际上我们总是获取当前应用的窗口）
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            targetAppPID = frontApp.processIdentifier
            targetAppBundleID = frontApp.bundleIdentifier
            print("📱 Recording front app: \(frontApp.localizedName ?? "Unknown") PID:\(frontApp.processIdentifier)")
        }
        
        // 记录当前最前面的窗口到历史记录
        windowManager.recordCurrentFrontWindow()
        
        isShowingSwitcher = true
        
        // 获取屏幕信息
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        
        // 窗口尺寸（与 SwiftUI 中的 maxWidth 和 viewHeight 保持一致）
        let windowWidth: CGFloat = 900
        let windowHeight: CGFloat = 150
        
        // 窗口位置：居中于屏幕顶部（紧贴菜单栏/Notch下方）
        let windowX = screenFrame.minX + (screenFrame.width - windowWidth) / 2
        let windowY = screenFrame.maxY - windowHeight
        
        // 创建共享的 ViewModel
        let viewModel = SwitcherViewModel()
        self.switcherViewModel = viewModel
        
        // 创建切换器视图
        let switcherView = WindowSwitcherView(
            viewModel: viewModel,
            onDismiss: { [weak self] in
                self?.hideSwitcher(activate: false)
            },
            onActivate: { [weak self] in
                self?.isShowingSwitcher = false
            }
        )
        
        // 创建或更新窗口
        if switcherWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight),
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.isReleasedWhenClosed = false
            window.ignoresMouseEvents = false
            
            switcherWindow = window
        }
        
        switcherHostingView = NSHostingView(rootView: switcherView)
        switcherWindow?.contentView = switcherHostingView
        switcherWindow?.setFrame(NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight), display: true)
        switcherWindow?.makeKeyAndOrderFront(nil)
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func hideSwitcher(activate: Bool) {
        guard isShowingSwitcher else { return }
        
        if activate, let viewModel = switcherViewModel {
            _ = viewModel.activateSelectedWindow()
            print("✅ Activated window at index \(viewModel.selectedIndex)")
        }
        
        isShowingSwitcher = false
        switcherViewModel = nil
        switcherWindow?.orderOut(nil)
    }
    
    // MARK: - Alerts
    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "MulTab needs accessibility permission to switch between windows. Please grant permission in System Settings."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        
        if alert.runModal() == .alertFirstButtonReturn {
            permissionManager.openSystemSettings(for: .accessibility)
        }
    }
    
    private func showHotkeyError(_ error: HotkeyError) {
        let alert = NSAlert()
        alert.messageText = "Failed to Register Hotkey"
        alert.informativeText = "Could not register the global hotkey. Error: \(error)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showCommandTabPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Command+Tab Requires Additional Permission"
        alert.informativeText = "Command+Tab mode requires accessibility permission to intercept system hotkeys. MulTab has switched to Option+Tab mode.\n\nTo use Command+Tab, please grant accessibility permission and restart MulTab."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    // MARK: - Menu Actions
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "MulTab\n\nby Alan Mok"
        let hotkeyDisplay = preferencesManager.hotkeyType.displayName
        alert.informativeText = "A lightweight window switcher for macOS.\n\nVersion 2.2.25\n\n「\(hotkeyDisplay)」 to switch windows."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func selectCommandTab() {
        preferencesManager.hotkeyType = .commandTab
    }
    
    @objc private func selectOptionTab() {
        preferencesManager.hotkeyType = .optionTab
    }
    
    private func observeHotkeyChanges() {
        preferencesManager.hotkeyTypeDidChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newType in
                guard let self = self else { return }
                print("🔄 Hotkey changed to: \(newType.displayName)")
                
                // 先停止系统热键拦截
                self.hotkeyManager.stopSystemHotkeyInterception()
                
                // 重新注册热键
                let result = self.hotkeyManager.reregisterHotkey(
                    keyCode: KeyCode.tab.rawValue,
                    modifiers: newType.modifier.carbon,
                    onPress: { [weak self] reverse in
                        self?.handleHotkeyPressed(reverse: reverse)
                    },
                    onRelease: { [weak self] in
                        self?.handleHotkeyReleased()
                    }
                )
                
                switch result {
                case .success:
                    print("✅ Hotkey re-registered: \(newType.displayName)")
                    if newType == .commandTab {
                        self.hotkeyManager.startSystemHotkeyInterception()
                    }
                case .failure(let error):
                    print("❌ Failed to re-register hotkey: \(error)")
                    
                    // 如果 Command+Tab 失败，自动回退到 Option+Tab
                    if newType == .commandTab {
                        print("🔄 Falling back to Option+Tab mode...")
                        // 直接设置，不触发再次的 hotkeyTypeDidChange
                        UserDefaults.standard.set(HotkeyType.optionTab.rawValue, forKey: "hotkeyType")
                        
                        let fallbackResult = self.hotkeyManager.reregisterHotkey(
                            keyCode: KeyCode.tab.rawValue,
                            modifiers: ModifierKey.option.carbon,
                            onPress: { [weak self] reverse in
                                self?.handleHotkeyPressed(reverse: reverse)
                            },
                            onRelease: { [weak self] in
                                self?.handleHotkeyReleased()
                            }
                        )
                        
                        if case .success = fallbackResult {
                            print("✅ Fallback to Option+Tab successful")
                            self.showCommandTabPermissionAlert()
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func observeMenuBarIconChanges() {
        // 直接监听 @Published 属性，比手动 PassthroughSubject 更可靠
        preferencesManager.$hideMenuBarIcon
            .dropFirst() // 跳过初始值
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusItemVisibility()
            }
            .store(in: &cancellables)
    }
    
    @objc private func showPreferences() {
        PreferencesWindowController.shared.showWindow()
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - NSMenuDelegate
extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // 更新 Hotkey 子菜单的勾选状态
        for item in menu.items {
            if item.title == "Hotkey", let submenu = item.submenu {
                for subItem in submenu.items {
                    if subItem.tag == 0 {
                        // Command + Tab
                        subItem.state = preferencesManager.hotkeyType == .commandTab ? .on : .off
                    } else if subItem.tag == 1 {
                        // Option + Tab
                        subItem.state = preferencesManager.hotkeyType == .optionTab ? .on : .off
                    }
                }
            }
        }
    }
}
