//
//  MulTabApp.swift
//  MulTab
//
//  Created by Alan Mok on 2025/12/30.
//

import SwiftUI
import AppKit

@main
struct MulTabApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
