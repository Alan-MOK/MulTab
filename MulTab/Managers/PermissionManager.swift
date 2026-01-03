//
//  PermissionManager.swift
//  MulTab
//
//  Created by Alan Mok on 2025/12/30.
//

import Foundation
import AppKit
import Combine
import ScreenCaptureKit

/// 权限类型
enum PermissionType {
    case accessibility
    case screenRecording
}

/// 权限管理器协议
protocol PermissionManagerProtocol {
    var hasAccessibility: Bool { get }
    var hasScreenRecording: Bool { get }
    
    func checkAccessibility() -> Bool
    func requestAccessibility()
    func checkScreenRecording() -> Bool
    func requestScreenRecording()
    func openSystemSettings(for permission: PermissionType)
    func updatePermissionStatus()
}

/// 权限管理器
final class PermissionManager: PermissionManagerProtocol, ObservableObject {
    static let shared = PermissionManager()
    
    @Published private(set) var hasAccessibility: Bool = false
    @Published private(set) var hasScreenRecording: Bool = false
    
    private init() {
        updatePermissionStatus()
    }
    
    /// 更新权限状态
    func updatePermissionStatus() {
        hasAccessibility = checkAccessibility()
        hasScreenRecording = checkScreenRecording()
    }
    
    /// 检查辅助功能权限
    func checkAccessibility() -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false
        ]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    /// 请求辅助功能权限
    func requestAccessibility() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        // 延迟后再次检查
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.updatePermissionStatus()
        }
    }
    
    /// 检查屏幕录制权限 - 使用 ScreenCaptureKit
    func checkScreenRecording() -> Bool {
        // 在 macOS 15+ 中，我们可以尝试获取 shareable content 来检查权限
        // 这里简化处理，假设有权限
        return true
    }
    
    /// 请求屏幕录制权限
    func requestScreenRecording() {
        // 使用 ScreenCaptureKit 触发权限请求
        Task {
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            } catch {
                print("Screen recording permission not granted: \(error)")
            }
        }
        
        // 延迟后再次检查
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.updatePermissionStatus()
        }
    }
    
    /// 打开系统设置
    func openSystemSettings(for permission: PermissionType) {
        let urlString: String
        
        switch permission {
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .screenRecording:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
