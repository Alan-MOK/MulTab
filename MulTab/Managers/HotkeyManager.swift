//
//  HotkeyManager.swift
//  MulTab
//
//  Created by Alan Mok on 2025/12/30.
//

import Foundation
import Carbon
import CoreGraphics

/// 热键错误类型
enum HotkeyError: Error {
    case registrationFailed(reason: String)
    case alreadyRegistered
    case systemError(OSStatus)
    case eventTapCreationFailed
}

/// 键码常量
enum KeyCode: UInt32 {
    case tab = 48          // Tab 键
    case space = 49        // 空格
    case graveAccent = 50  // ` 键
    case escape = 53       // Esc
    case delete = 51       // Delete
    
    // 方向键
    case leftArrow = 123
    case rightArrow = 124
    case downArrow = 125
    case upArrow = 126
}

/// 修饰键常量
enum ModifierKey: UInt32 {
    case command = 0x0100   // ⌘
    case shift = 0x0200     // ⇧
    case option = 0x0800    // ⌥
    case control = 0x1000   // ⌃
    
    var carbon: UInt32 {
        switch self {
        case .command: return UInt32(cmdKey)
        case .shift: return UInt32(shiftKey)
        case .option: return UInt32(optionKey)
        case .control: return UInt32(controlKey)
        }
    }
}

/// 热键管理器协议
protocol HotkeyManagerProtocol {
    func registerHotkey(
        keyCode: UInt32,
        modifiers: UInt32,
        onPress callback: @escaping (_ reverse: Bool) -> Void,
        onRelease releaseCallback: (() -> Void)?
    ) -> Result<Void, HotkeyError>
    
    func unregisterHotkey()
    
    var isRegistered: Bool { get }
}

/// 全局热键管理器
final class HotkeyManager: HotkeyManagerProtocol {
    static let shared = HotkeyManager()
    
    private var eventHotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var pressCallback: ((_ reverse: Bool) -> Void)?
    private var releaseCallback: (() -> Void)?
    
    // CGEventTap 相关（用于拦截 Command + Tab）
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var currentModifier: ModifierKey = .option
    private var isUsingEventTap: Bool = false
    private var isTabPressed: Bool = false
    
    private let hotKeySignature: OSType = OSType("MTAB".utf8.reduce(0) { ($0 << 8) + OSType($1) })
    
    private(set) var isRegistered: Bool = false
    
    private init() {}
    
    deinit {
        unregisterHotkey()
    }
    
    /// 注册全局热键
    func registerHotkey(
        keyCode: UInt32,
        modifiers: UInt32,
        onPress callback: @escaping (_ reverse: Bool) -> Void,
        onRelease releaseCallback: (() -> Void)? = nil
    ) -> Result<Void, HotkeyError> {
        guard !isRegistered else {
            return .failure(.alreadyRegistered)
        }
        
        self.pressCallback = callback
        self.releaseCallback = releaseCallback
        
        // 判断是否需要使用 EventTap（Command 键需要）
        if modifiers == ModifierKey.command.carbon {
            currentModifier = .command
            return registerWithEventTap(keyCode: keyCode, modifiers: modifiers)
        } else {
            currentModifier = .option
            return registerWithCarbonAPI(keyCode: keyCode, modifiers: modifiers)
        }
    }
    
    /// 使用 Carbon API 注册热键（用于 Option + Tab）
    private func registerWithCarbonAPI(keyCode: UInt32, modifiers: UInt32) -> Result<Void, HotkeyError> {
        // 安装事件处理器
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                         eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                         eventKind: UInt32(kEventHotKeyReleased))
        ]
        
        let handlerResult = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                return manager.handleHotKeyEvent(event: event)
            },
            2,
            &eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        
        guard handlerResult == noErr else {
            return .failure(.systemError(handlerResult))
        }
        
        // 注册热键
        var hotKeyID = EventHotKeyID(signature: hotKeySignature, id: 1)
        let registerResult = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &eventHotKeyRef
        )
        
        guard registerResult == noErr else {
            RemoveEventHandler(eventHandler)
            eventHandler = nil
            return .failure(.systemError(registerResult))
        }
        
        isRegistered = true
        isUsingEventTap = false
        return .success(())
    }
    
    /// 使用 CGEventTap 注册热键（用于拦截 Command + Tab）
    private func registerWithEventTap(keyCode: UInt32, modifiers: UInt32) -> Result<Void, HotkeyError> {
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEventTap(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return .failure(.eventTapCreationFailed)
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            isRegistered = true
            isUsingEventTap = true
            return .success(())
        } else {
            return .failure(.eventTapCreationFailed)
        }
    }
    
    /// 处理 EventTap 事件
    private func handleEventTap(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // 处理事件 tap 被禁用的情况
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }
        
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        // 检查是否是 Command + Tab
        if keyCode == Int64(KeyCode.tab.rawValue) {
            let hasCommand = flags.contains(.maskCommand)
            let hasShift = flags.contains(.maskShift)
            
            if hasCommand && type == .keyDown {
                // Command + Tab 或 Command + Shift + Tab 按下
                let isFirstPress = !isTabPressed
                isTabPressed = true
                DispatchQueue.main.async { [weak self] in
                    self?.pressCallback?(hasShift)
                }
                return nil // 拦截事件，不传递给系统
            } else if hasCommand && type == .keyUp {
                // Tab 释放（但 Command 仍按住）
                // 允许在切换器中继续切换，不关闭
                return nil
            }
        }
        
        // 检测 Command 键释放
        if type == .flagsChanged {
            let hasCommand = flags.contains(.maskCommand)
            if !hasCommand && isTabPressed {
                // Command 键释放，关闭切换器
                isTabPressed = false
                DispatchQueue.main.async { [weak self] in
                    self?.releaseCallback?()
                }
            }
        }
        
        return Unmanaged.passRetained(event)
    }
    
    /// 注销热键
    func unregisterHotkey() {
        // 注销 Carbon 热键
        if let hotKeyRef = eventHotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            eventHotKeyRef = nil
        }
        
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        
        // 注销 EventTap
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }
        
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
        
        pressCallback = nil
        releaseCallback = nil
        isRegistered = false
        isUsingEventTap = false
        isTabPressed = false
    }
    
    /// 重新注册热键（用于更换热键组合）
    func reregisterHotkey(
        keyCode: UInt32,
        modifiers: UInt32,
        onPress callback: @escaping (_ reverse: Bool) -> Void,
        onRelease releaseCallback: (() -> Void)? = nil
    ) -> Result<Void, HotkeyError> {
        // 先注销现有热键
        unregisterHotkey()
        
        // 注册新热键
        return registerHotkey(
            keyCode: keyCode,
            modifiers: modifiers,
            onPress: callback,
            onRelease: releaseCallback
        )
    }
    
    // MARK: - 系统热键拦截（用于屏蔽系统 Command+Tab）
    
    private var systemInterceptionTap: CFMachPort?
    private var systemInterceptionRunLoopSource: CFRunLoopSource?
    private var isInterceptingSystemHotkey: Bool = false
    
    /// 开始拦截系统 Command+Tab 热键
    func startSystemHotkeyInterception() {
        guard !isInterceptingSystemHotkey else { return }
        
        // 如果已经在使用 EventTap 模式，不需要额外的拦截器
        if isUsingEventTap {
            isInterceptingSystemHotkey = true
            print("✅ System hotkey interception active (using existing EventTap)")
            return
        }
        
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleSystemInterceptionEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("❌ Failed to create system interception event tap")
            return
        }
        
        systemInterceptionTap = tap
        systemInterceptionRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let source = systemInterceptionRunLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            isInterceptingSystemHotkey = true
            print("✅ System hotkey interception started")
        }
    }
    
    /// 停止拦截系统热键
    func stopSystemHotkeyInterception() {
        guard isInterceptingSystemHotkey else { return }
        
        if let source = systemInterceptionRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            systemInterceptionRunLoopSource = nil
        }
        
        if let tap = systemInterceptionTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            systemInterceptionTap = nil
        }
        
        isInterceptingSystemHotkey = false
        print("🛑 System hotkey interception stopped")
    }
    
    /// 处理系统热键拦截事件
    private func handleSystemInterceptionEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // 处理事件 tap 被禁用的情况
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = systemInterceptionTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }
        
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        // 拦截 Command + Tab
        if keyCode == Int64(KeyCode.tab.rawValue) {
            let hasCommand = flags.contains(.maskCommand)
            if hasCommand {
                // 拦截 Command + Tab，阻止系统应用切换器
                return nil
            }
        }
        
        return Unmanaged.passRetained(event)
    }
    
    /// 处理热键事件
    private func handleHotKeyEvent(event: EventRef?) -> OSStatus {
        guard let event = event else { return OSStatus(eventNotHandledErr) }
        
        var hotKeyID = EventHotKeyID()
        let getIDResult = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        
        guard getIDResult == noErr else {
            return OSStatus(eventNotHandledErr)
        }
        
        let eventKind = GetEventKind(event)
        
        DispatchQueue.main.async { [weak self] in
            if eventKind == UInt32(kEventHotKeyPressed) {
                self?.pressCallback?(false)
            } else if eventKind == UInt32(kEventHotKeyReleased) {
                self?.releaseCallback?()
            }
        }
        
        return noErr
    }
}
