//
//  PreferencesView.swift
//  MulTab
//
//  Created by Alan Mok on 2025/12/30.
//

import SwiftUI

/// 偏好设置视图
struct PreferencesView: View {
    @ObservedObject private var preferencesManager = PreferencesManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题
            Text("Preferences")
                .font(.title2)
                .fontWeight(.semibold)
            
            Divider()
            
            // 热键设置
            VStack(alignment: .leading, spacing: 12) {
                Text("Hotkey Settings")
                    .font(.headline)
                
                Text("Choose the keyboard shortcut to activate the window switcher:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // 热键选择
                Picker("Hotkey", selection: $preferencesManager.hotkeyType) {
                    ForEach(HotkeyType.allCases, id: \.self) { type in
                        HStack {
                            Text(type.displayName)
                        }
                        .tag(type)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                
                // 显示当前设置的说明
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "keyboard")
                                .foregroundColor(.accentColor)
                            Text("Current shortcuts:")
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Forward:")
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .trailing)
                            Text(preferencesManager.hotkeyType.displayName)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Backward:")
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .trailing)
                            Text(preferencesManager.hotkeyType.reverseDisplayName)
                                .fontWeight(.medium)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Divider()
            
            // 菜单栏图标设置
            VStack(alignment: .leading, spacing: 12) {
                Text("Menu Bar")
                    .font(.headline)
                
                Toggle("Hide menu bar icon", isOn: $preferencesManager.hideMenuBarIcon)
                    .toggleStyle(.checkbox)
                
                Text("When hidden, you can still access MulTab through its hotkey.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 底部说明
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                Text("Version 2.11.1")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 400, height: 500)
    }
}

/// 用于在 NSWindow 中显示偏好设置的窗口控制器
final class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "MulTab Preferences"
        window.center()
        window.contentView = NSHostingView(rootView: PreferencesView())
        
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func showWindow() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

#Preview {
    PreferencesView()
}
