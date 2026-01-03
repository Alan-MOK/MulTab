//
//  PreferencesManager.swift
//  MulTab
//
//  Created by Alan Mok on 2025/12/30.
//

import Foundation
import Combine

/// 热键类型枚举
enum HotkeyType: String, CaseIterable {
    case optionTab = "option"
    case commandTab = "command"
    
    var displayName: String {
        switch self {
        case .optionTab:
            return "Option + Tab"
        case .commandTab:
            return "Command + Tab"
        }
    }
    
    var reverseDisplayName: String {
        switch self {
        case .optionTab:
            return "Option + Shift + Tab"
        case .commandTab:
            return "Command + Shift + Tab"
        }
    }
    
    var modifier: ModifierKey {
        switch self {
        case .optionTab:
            return .option
        case .commandTab:
            return .command
        }
    }
}

/// 偏好设置管理器
final class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()
    
    // MARK: - Keys
    private enum Keys {
        static let hotkeyType = "hotkeyType"
    }
    
    // MARK: - Published Properties
    @Published var hotkeyType: HotkeyType {
        didSet {
            UserDefaults.standard.set(hotkeyType.rawValue, forKey: Keys.hotkeyType)
            hotkeyTypeDidChange.send(hotkeyType)
        }
    }
    
    // MARK: - Publishers
    let hotkeyTypeDidChange = PassthroughSubject<HotkeyType, Never>()
    
    // MARK: - Initialization
    private init() {
        // 从 UserDefaults 加载保存的设置，默认使用 Option + Tab
        if let savedValue = UserDefaults.standard.string(forKey: Keys.hotkeyType),
           let type = HotkeyType(rawValue: savedValue) {
            self.hotkeyType = type
        } else {
            self.hotkeyType = .optionTab
        }
    }
}
