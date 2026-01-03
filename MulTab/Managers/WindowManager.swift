//
//  WindowManager.swift
//  MulTab
//
//  Created by Alan Mok on 2025/12/30.
//

import Foundation
import AppKit
import CoreGraphics

/// 窗口错误类型
enum WindowError: Error {
    case noWindowsFound
    case permissionDenied
    case activationFailed(reason: String)
    case captureFailed(reason: String)
}

/// 窗口管理器协议
protocol WindowManagerProtocol {
    func getCurrentAppWindows() -> Result<[WindowInfo], WindowError>
    func getAllWindows() -> Result<[WindowInfo], WindowError>
    func getWindows(forBundleID bundleID: String) -> Result<[WindowInfo], WindowError>
    func getWindows(forPID pid: pid_t) -> Result<[WindowInfo], WindowError>
    func activate(window: WindowInfo) -> Result<Void, WindowError>
    func captureThumbnail(for window: WindowInfo, maxSize: CGSize) async -> Result<NSImage, WindowError>
    func recordCurrentFrontWindow()
}

/// 窗口管理器
final class WindowManager: WindowManagerProtocol {
    static let shared = WindowManager()
    
    /// 窗口访问历史记录 - 记录每个窗口最后被激活的时间
    /// Key: CGWindowID, Value: 激活时间戳
    private var windowAccessHistory: [CGWindowID: Date] = [:]
    
    /// 记录上一个活动窗口的ID，用于在切换时更新历史
    private var lastActiveWindowID: CGWindowID?
    
    private init() {}
    
    // MARK: - Window Access History
    
    /// 记录窗口访问历史
    private func recordWindowAccess(windowID: CGWindowID) {
        windowAccessHistory[windowID] = Date()
        lastActiveWindowID = windowID
        print("📝 Recorded window access: \(windowID) at \(Date())")
    }
    
    /// 记录当前最前面的窗口（在打开切换器时调用）
    func recordCurrentFrontWindow() {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[CFString: Any]] else {
            return
        }
        
        // 需要排除的应用 Bundle ID
        let excludedBundleIDs: Set<String> = [
            "com.apple.dock",
            "com.apple.controlcenter",
            "com.apple.notificationcenterui",
            "com.apple.WindowManager"
        ]
        
        // 找到最前面的有效窗口（第一个符合条件的窗口）
        for dict in windowList {
            if let windowInfo = parseWindowInfo(from: dict, excludedBundleIDs: excludedBundleIDs) {
                // 检查这个窗口是否已经在历史记录中
                // 如果不在，或者是新的最前窗口，记录它
                if lastActiveWindowID != windowInfo.id {
                    recordWindowAccess(windowID: windowInfo.id)
                }
                break
            }
        }
    }
    
    /// 清理无效的历史记录（窗口已关闭）
    func cleanupHistory(validWindowIDs: Set<CGWindowID>) {
        let keysToRemove = windowAccessHistory.keys.filter { !validWindowIDs.contains($0) }
        for key in keysToRemove {
            windowAccessHistory.removeValue(forKey: key)
        }
    }
    
    // MARK: - Window Operations
    
    /// 获取当前应用的所有窗口
    func getCurrentAppWindows() -> Result<[WindowInfo], WindowError> {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            print("❌ No frontmost application found")
            return .failure(.noWindowsFound)
        }
        
        print("📱 Frontmost app: \(frontApp.localizedName ?? "Unknown") (PID: \(frontApp.processIdentifier), Bundle: \(frontApp.bundleIdentifier ?? "unknown"))")
        
        return getWindows(forPID: frontApp.processIdentifier)
    }
    
    /// 获取所有应用的窗口（排除桌面小组件和Dock）
    func getAllWindows() -> Result<[WindowInfo], WindowError> {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[CFString: Any]] else {
            print("❌ Failed to get window list")
            return .failure(.noWindowsFound)
        }
        
        print("📋 Total windows from CGWindowList: \(windowList.count)")
        
        // 需要排除的应用 Bundle ID
        let excludedBundleIDs: Set<String> = [
            "com.apple.dock",
            "com.apple.controlcenter",
            "com.apple.notificationcenterui",
            "com.apple.WindowManager"
        ]
        
        var windows = windowList.compactMap { dict -> WindowInfo? in
            parseWindowInfo(from: dict, excludedBundleIDs: excludedBundleIDs)
        }
        
        print("✅ Parsed windows: \(windows.count)")
        
        // 根据访问历史记录排序窗口
        // 有历史记录的窗口按时间倒序排列（最近访问的在前）
        // 没有历史记录的窗口保持原有的 Z-order 顺序
        windows.sort { window1, window2 in
            let time1 = windowAccessHistory[window1.id]
            let time2 = windowAccessHistory[window2.id]
            
            // 如果两个窗口都有历史记录，按时间倒序
            if let t1 = time1, let t2 = time2 {
                return t1 > t2
            }
            
            // 有历史记录的窗口排在前面
            if time1 != nil { return true }
            if time2 != nil { return false }
            
            // 都没有历史记录，保持原顺序（CGWindowList 的 Z-order）
            return false
        }
        
        return windows.isEmpty ? .failure(.noWindowsFound) : .success(windows)
    }
    
    /// 获取指定 Bundle ID 应用的窗口
    func getWindows(forBundleID bundleID: String) -> Result<[WindowInfo], WindowError> {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) else {
            return .failure(.noWindowsFound)
        }
        
        return getWindows(forPID: app.processIdentifier)
    }
    
    /// 获取指定 PID 应用的窗口
    func getWindows(forPID pid: pid_t) -> Result<[WindowInfo], WindowError> {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[CFString: Any]] else {
            print("❌ Failed to get window list for PID \(pid)")
            return .failure(.noWindowsFound)
        }
        
        print("📋 Total windows from CGWindowList: \(windowList.count)")
        
        // 打印所有窗口信息用于调试
        for (index, dict) in windowList.enumerated() {
            let ownerPID = dict[kCGWindowOwnerPID] as? pid_t ?? 0
            let ownerName = dict[kCGWindowOwnerName] as? String ?? "Unknown"
            let title = dict[kCGWindowName] as? String ?? "(no title)"
            let layer = dict[kCGWindowLayer] as? Int ?? -1
            print("  [\(index)] PID:\(ownerPID) Owner:\(ownerName) Title:\(title) Layer:\(layer)")
        }
        
        let windows = windowList.compactMap { dict -> WindowInfo? in
            parseWindowInfo(from: dict, targetPID: pid)
        }
        
        print("✅ Parsed windows for PID \(pid): \(windows.count)")
        
        return windows.isEmpty ? .failure(.noWindowsFound) : .success(windows)
    }
    
    /// 解析窗口信息
    private func parseWindowInfo(from dict: [CFString: Any], targetPID: pid_t? = nil, excludedBundleIDs: Set<String> = []) -> WindowInfo? {
        guard let windowID = dict[kCGWindowNumber] as? CGWindowID,
              let ownerPID = dict[kCGWindowOwnerPID] as? pid_t else {
            return nil
        }
        
        let layer = dict[kCGWindowLayer] as? Int ?? 0
        
        // 过滤指定 PID
        if let targetPID = targetPID, ownerPID != targetPID {
            return nil
        }
        
        // 只获取普通窗口层 (layer 0)
        guard layer == 0 else {
            return nil
        }
        
        // 获取应用信息
        let app = NSRunningApplication(processIdentifier: ownerPID)
        let bundleID = app?.bundleIdentifier ?? ""
        let appName = dict[kCGWindowOwnerName] as? String ?? app?.localizedName ?? "Unknown"
        
        // 排除特定应用
        if excludedBundleIDs.contains(bundleID) {
            return nil
        }
        
        // 排除 MulTab 自己
        if bundleID == Bundle.main.bundleIdentifier {
            return nil
        }
        
        let title = dict[kCGWindowName] as? String ?? ""
        
        // 获取边界
        guard let boundsDict = dict[kCGWindowBounds] as? [String: CGFloat] else {
            return nil
        }
        
        let bounds = CGRect(
            x: boundsDict["X"] ?? 0,
            y: boundsDict["Y"] ?? 0,
            width: boundsDict["Width"] ?? 0,
            height: boundsDict["Height"] ?? 0
        )
        
        // 排除太小的窗口（可能是隐藏窗口或工具栏）
        guard bounds.width > 100 && bounds.height > 50 else {
            return nil
        }
        
        let isOnScreen = dict[kCGWindowIsOnscreen] as? Bool ?? true
        
        print("🪟 Found window: '\(title.isEmpty ? "(no title)" : title)' - App: \(appName) - Size: \(Int(bounds.width))x\(Int(bounds.height))")
        
        return WindowInfo(
            id: windowID,
            ownerPID: ownerPID,
            bundleID: bundleID,
            appName: appName,
            title: title.isEmpty ? appName : title,  // 如果没有标题，使用应用名
            bounds: bounds,
            layer: layer,
            isOnScreen: isOnScreen,
            isMinimized: false
        )
    }
    
    /// 激活窗口
    func activate(window: WindowInfo) -> Result<Void, WindowError> {
        // 记录当前窗口到历史记录
        recordWindowAccess(windowID: window.id)
        
        let app = AXUIElementCreateApplication(window.ownerPID)
        
        // 获取窗口列表
        var windowsRef: CFTypeRef?
        let getWindowsResult = AXUIElementCopyAttributeValue(
            app,
            kAXWindowsAttribute as CFString,
            &windowsRef
        )
        
        guard getWindowsResult == .success else {
            print("❌ Failed to get AX windows: \(getWindowsResult)")
            // 尝试直接激活应用
            if let nsApp = NSRunningApplication(processIdentifier: window.ownerPID) {
                nsApp.activate()
                return .success(())
            }
            return .failure(.activationFailed(reason: "Failed to get windows: \(getWindowsResult)"))
        }
        
        guard let windows = windowsRef as? [AXUIElement] else {
            return .failure(.activationFailed(reason: "Invalid window list"))
        }
        
        print("🔍 Looking for window: '\(window.title)' (bounds: \(window.bounds)) in \(windows.count) AX windows")
        
        // 查找目标窗口 - 通过位置和大小精确匹配
        var bestMatch: AXUIElement?
        var bestMatchScore = 0
        
        for axWindow in windows {
            var score = 0
            
            // 获取窗口标题
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef)
            let axTitle = titleRef as? String ?? ""
            
            // 获取窗口位置
            var positionRef: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &positionRef)
            var axPosition = CGPoint.zero
            if let positionValue = positionRef {
                AXValueGetValue(positionValue as! AXValue, .cgPoint, &axPosition)
            }
            
            // 获取窗口大小
            var sizeRef: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &sizeRef)
            var axSize = CGSize.zero
            if let sizeValue = sizeRef {
                AXValueGetValue(sizeValue as! AXValue, .cgSize, &axSize)
            }
            
            print("  - AX Window: '\(axTitle)' at (\(Int(axPosition.x)), \(Int(axPosition.y))) size \(Int(axSize.width))x\(Int(axSize.height))")
            
            // 匹配标题（+langName处理没有标题的情况）
            if axTitle == window.title {
                score += 10
            } else if !axTitle.isEmpty && window.title.contains(axTitle) {
                score += 5
            }
            
            // 匹配位置（允许小误差）
            let positionTolerance: CGFloat = 5
            if abs(axPosition.x - window.bounds.origin.x) <= positionTolerance &&
               abs(axPosition.y - window.bounds.origin.y) <= positionTolerance {
                score += 20
            }
            
            // 匹配大小（允许小误差）
            let sizeTolerance: CGFloat = 5
            if abs(axSize.width - window.bounds.width) <= sizeTolerance &&
               abs(axSize.height - window.bounds.height) <= sizeTolerance {
                score += 20
            }
            
            if score > bestMatchScore {
                bestMatchScore = score
                bestMatch = axWindow
            }
        }
        
        // 激活最佳匹配的窗口
        if let targetWindow = bestMatch, bestMatchScore > 0 {
            // 激活窗口
            AXUIElementPerformAction(targetWindow, kAXRaiseAction as CFString)
            
            // 将应用置前
            AXUIElementSetAttributeValue(
                app,
                kAXFrontmostAttribute as CFString,
                kCFBooleanTrue
            )
            
            // 激活应用
            if let nsApp = NSRunningApplication(processIdentifier: window.ownerPID) {
                nsApp.activate()
            }
            
            print("✅ Activated window with score \(bestMatchScore)")
            return .success(())
        }
        
        // 如果没找到匹配的窗口，尝试激活第一个窗口
        if let firstWindow = windows.first {
            AXUIElementPerformAction(firstWindow, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
            if let nsApp = NSRunningApplication(processIdentifier: window.ownerPID) {
                nsApp.activate()
            }
            print("✅ Activated first window as fallback")
            return .success(())
        }
        
        return .failure(.activationFailed(reason: "Window not found"))
    }
    
    /// 捕获窗口缩略图 - 返回应用图标作为标识
    func captureThumbnail(
        for window: WindowInfo,
        maxSize: CGSize = CGSize(width: 300, height: 200)
    ) async -> Result<NSImage, WindowError> {
        // 获取应用图标作为窗口标识
        if let app = NSRunningApplication(processIdentifier: window.ownerPID),
           let icon = app.icon {
            let scaledIcon = scaleImage(icon, to: maxSize)
            return .success(scaledIcon)
        }
        
        // 如果获取不到图标，创建一个默认图标
        let defaultImage = NSImage(systemSymbolName: "rectangle", accessibilityDescription: "Window")
            ?? NSImage(size: NSSize(width: 64, height: 64))
        return .success(defaultImage)
    }
    
    /// 缩放图片
    private func scaleImage(_ image: NSImage, to maxSize: CGSize) -> NSImage {
        let aspectRatio = image.size.width / image.size.height
        
        var newSize: NSSize
        if aspectRatio > maxSize.width / maxSize.height {
            newSize = NSSize(width: maxSize.width, height: maxSize.width / aspectRatio)
        } else {
            newSize = NSSize(width: maxSize.height * aspectRatio, height: maxSize.height)
        }
        
        let scaledImage = NSImage(size: newSize)
        scaledImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        scaledImage.unlockFocus()
        
        return scaledImage
    }
}
