//
//  WindowInfo.swift
//  MulTab
//
//  Created by Alan Mok on 2025/12/30.
//

import Foundation
import AppKit

/// 窗口信息模型
struct WindowInfo: Identifiable, Hashable, Sendable {
    let id: CGWindowID
    let ownerPID: pid_t
    let bundleID: String
    let appName: String
    let title: String
    let bounds: CGRect
    let layer: Int
    let isOnScreen: Bool
    let isMinimized: Bool
    
    /// 显示标题
    var displayTitle: String {
        title.isEmpty ? "Untitled" : title
    }
    
    /// 尺寸描述
    var sizeDescription: String {
        "\(Int(bounds.width))×\(Int(bounds.height))"
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id
    }
}
