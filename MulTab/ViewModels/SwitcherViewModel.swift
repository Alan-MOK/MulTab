//
//  SwitcherViewModel.swift
//  MulTab
//
//  Created by Alan Mok on 2025/12/30.
//

import Foundation
import AppKit
import Combine

/// 切换器视图模型
@MainActor
final class SwitcherViewModel: ObservableObject {
    // MARK: - Published State
    @Published private(set) var windows: [WindowInfo] = []
    @Published var selectedIndex: Int = 0
    @Published private(set) var thumbnails: [CGWindowID: NSImage] = [:]
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?
    
    // MARK: - Dependencies
    private let windowManager: WindowManagerProtocol
    private let permissionManager: PermissionManagerProtocol
    
    // MARK: - Computed Properties
    var selectedWindow: WindowInfo? {
        guard selectedIndex >= 0 && selectedIndex < windows.count else { return nil }
        return windows[selectedIndex]
    }
    
    var hasWindows: Bool {
        !windows.isEmpty
    }
    
    // MARK: - Init
    init(
        windowManager: WindowManagerProtocol = WindowManager.shared,
        permissionManager: PermissionManagerProtocol = PermissionManager.shared
    ) {
        self.windowManager = windowManager
        self.permissionManager = permissionManager
    }
    
    // MARK: - Actions
    
    /// 加载窗口列表（获取所有应用的窗口）
    func loadWindows() async {
        isLoading = true
        defer { isLoading = false }
        
        // 获取所有应用的窗口
        let result = windowManager.getAllWindows()
        
        switch result {
        case .success(let windows):
            print("📋 ViewModel: Loaded \(windows.count) windows")
            self.windows = windows
            // 默认选中第二个窗口（如果存在），否则选中第一个
            self.selectedIndex = windows.count > 1 ? 1 : 0
            await loadThumbnails()
            
        case .failure(let error):
            print("❌ ViewModel: Failed to load windows: \(error)")
            self.error = error
            self.windows = []
        }
    }
    
    /// 加载指定应用的窗口列表
    func loadWindows(forPID pid: pid_t) async {
        isLoading = true
        defer { isLoading = false }
        
        // 获取指定PID应用的窗口
        let result = windowManager.getWindows(forPID: pid)
        
        switch result {
        case .success(let windows):
            print("📋 ViewModel: Loaded \(windows.count) windows for PID \(pid)")
            self.windows = windows
            // 默认选中第二个窗口（如果存在），否则选中第一个
            self.selectedIndex = windows.count > 1 ? 1 : 0
            await loadThumbnails()
            
        case .failure(let error):
            print("❌ ViewModel: Failed to load windows: \(error)")
            self.error = error
            self.windows = []
        }
    }
    
    /// 选择下一个窗口
    func selectNext() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % windows.count
    }
    
    /// 选择上一个窗口
    func selectPrevious() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + windows.count) % windows.count
    }
    
    /// 选择指定索引的窗口
    func select(at index: Int) {
        guard index >= 0 && index < windows.count else { return }
        selectedIndex = index
    }
    
    /// 激活选中的窗口
    func activateSelectedWindow() -> Result<Void, WindowError> {
        guard let window = selectedWindow else {
            return .failure(.noWindowsFound)
        }
        return windowManager.activate(window: window)
    }
    
    /// 清理资源
    func cleanup() {
        thumbnails.removeAll()
        windows.removeAll()
        selectedIndex = 0
        error = nil
    }
    
    // MARK: - Private Methods
    
    /// 加载缩略图
    private func loadThumbnails() async {
        await withTaskGroup(of: (CGWindowID, NSImage?).self) { group in
            for window in windows {
                group.addTask { [weak self] in
                    guard let self = self else { return (window.id, nil) }
                    let result = await self.windowManager.captureThumbnail(
                        for: window,
                        maxSize: CGSize(width: 300, height: 200)
                    )
                    
                    switch result {
                    case .success(let image):
                        return (window.id, image)
                    case .failure:
                        return (window.id, nil)
                    }
                }
            }
            
            for await (id, image) in group {
                if let image = image {
                    thumbnails[id] = image
                }
            }
        }
    }
}
