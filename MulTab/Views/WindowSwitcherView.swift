//
//  WindowSwitcherView.swift
//  MulTab
//
//  Created by Alan Mok on 2025/12/30.
//

import SwiftUI

/// 顶部凹形圆角、底部凸形圆角的自定义形状
struct NotchDropdownShape: Shape {
    var topConcaveRadius: CGFloat = 12    // 顶部凹形圆角半径
    var bottomConvexRadius: CGFloat = 16  // 底部凸形圆角半径
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let w = rect.width
        let h = rect.height
        let tcr = topConcaveRadius
        let bcr = bottomConvexRadius
        
        // 从左上角开始（凹形圆角）
        path.move(to: CGPoint(x: 0, y: 0))
        
        // 左上角凹形圆角 - 向内弯曲
        path.addQuadCurve(
            to: CGPoint(x: tcr, y: tcr),
            control: CGPoint(x: tcr, y: 0)
        )
        
        // 左边线向下
        path.addLine(to: CGPoint(x: tcr, y: h - bcr))
        
        // 左下角凸形圆角
        path.addQuadCurve(
            to: CGPoint(x: tcr + bcr, y: h),
            control: CGPoint(x: tcr, y: h)
        )
        
        // 底边
        path.addLine(to: CGPoint(x: w - tcr - bcr, y: h))
        
        // 右下角凸形圆角
        path.addQuadCurve(
            to: CGPoint(x: w - tcr, y: h - bcr),
            control: CGPoint(x: w - tcr, y: h)
        )
        
        // 右边线向上
        path.addLine(to: CGPoint(x: w - tcr, y: tcr))
        
        // 右上角凹形圆角 - 向内弯曲
        path.addQuadCurve(
            to: CGPoint(x: w, y: 0),
            control: CGPoint(x: w - tcr, y: 0)
        )
        
        // 顶边回到起点
        path.addLine(to: CGPoint(x: 0, y: 0))
        
        path.closeSubpath()
        return path
    }
}

/// 窗口切换器视图
struct WindowSwitcherView: View {
    @ObservedObject var viewModel: SwitcherViewModel
    let onDismiss: () -> Void
    let onActivate: (() -> Void)?
    
    @State private var isVisible = false
    @State private var expandWidth: CGFloat = 130
    @State private var itemAppearProgress: [Int: CGFloat] = [:]
    
    // 【1. 控制整个弹窗的窗口大小】
    private let maxWidth: CGFloat = 900      // 弹窗最大宽度
    private let viewHeight: CGFloat = 140    // 弹窗高度
    
    init(viewModel: SwitcherViewModel, onDismiss: @escaping () -> Void, onActivate: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        self.onActivate = onActivate
    }
    
    var body: some View {
        ZStack {
            // 黑色背景 - 顶部凹形圆角，底部凸形圆角
            NotchDropdownShape(topConcaveRadius: 12, bottomConvexRadius: 16)
                .fill(Color.black.opacity(0.9))
                .shadow(color: .black.opacity(0.5), radius: 30, y: 15)
            
            // 内容
            VStack(spacing: 0) {
                // 【2. 控制上部留白】躲开Notch区域
                Spacer()
                    .frame(height: 30)  // 上部留白高度
                
                // 窗口列表
                if viewModel.hasWindows {
                    windowListView
                        .opacity(isVisible ? 1 : 0)
                } else if viewModel.isLoading {
                    loadingView
                        .opacity(isVisible ? 1 : 0)
                } else {
                    emptyStateView
                        .opacity(isVisible ? 1 : 0)
                }
                
                // 底部提示
                footerView
                    .opacity(isVisible ? 1 : 0)
            }
        }
        // 【1. 控制整个弹窗的窗口大小】width: 宽度动画从100到900, height: 高度从32到140
        .frame(width: expandWidth, height: isVisible ? viewHeight : 32, alignment: .top)
        .clipShape(NotchDropdownShape(topConcaveRadius: 12, bottomConvexRadius: 16))
        // 放在固定大小的容器中，顶部对齐避免与屏幕顶部分离
        .frame(maxWidth: maxWidth, maxHeight: .infinity, alignment: .top)
        .task {
            // 加载所有应用的窗口
            await viewModel.loadWindows()

            // 阶段1：从 Notch 中间水平展开
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                expandWidth = maxWidth
            }

            // 阶段2：垂直展开
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            withAnimation(.spring(response: 0.15, dampingFraction: 0.8)) {
                isVisible = true
            }

            // 阶段3：所有项目同时显示
            for i in 0..<viewModel.windows.count {
                itemAppearProgress[i] = 1 // 设置为1时，所有项目同时显示；设置为0时，项目逐个显示
            }

            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            for i in 0..<viewModel.windows.count {
                let delay = UInt64(Double(i) * 25_000_000) // 0.025秒间隔
                try? await Task.sleep(nanoseconds: delay)
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    itemAppearProgress[i] = 1
                }
            }
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
    
    // MARK: - Notch 连接指示器
    private var notchConnector: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.white.opacity(0.3))
            .frame(width: 40, height: 4)
            .padding(.top, 6)
            .padding(.bottom, 4)
    }
    
    // MARK: - 窗口列表视图
    // 【3. 控制应用icon显示区域的显示范围】整个水平滚动区域
    private var windowListView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {  // 【增加间距避免放大时被裁剪】每个应用icon之间的间距
                ForEach(Array(viewModel.windows.enumerated()), id: \.element.id) { index, window in
                    let progress = itemAppearProgress[index] ?? 0
                    
                    WindowItemView(
                        window: window,
                        thumbnail: viewModel.thumbnails[window.id],
                        isSelected: index == viewModel.selectedIndex,
                        index: index
                    )
                    .padding(.vertical, 8)  // 【增加上下padding避免被裁剪】
                    .scaleEffect(0.7 + (0.3 * progress))
                    .opacity(progress)
                    .offset(y: 15 * (1 - progress))
                    .onTapGesture {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
                            viewModel.select(at: index)
                        }
                        activateAndDismiss()
                    }
                }
            }
            .padding(.horizontal, 32)  // 【3. 控制应用icon显示区域的显示范围】左右边距（12pt凹形圆角 + 12pt间距）
        }
    }
    
    // MARK: - 加载视图
    private var loadingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)
            Text("Loading...")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(height: 50)
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.on.rectangle.slash")
                .font(.title3)
                .foregroundColor(.white.opacity(0.5))
            Text("No windows")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(height: 50)
    }
    
    // MARK: - 底部提示
    private var footerView: some View {
        HStack(spacing: 20) {
            HStack(spacing: 4) {
                Text("⌥")
                    .font(.system(size: 10, weight: .medium))
                Text("+")
                    .font(.system(size: 9))
                Text("Tab")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.5))
            
            Text("•")
                .foregroundColor(.white.opacity(0.3))
            
            Text("Release ⌥ to switch")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Actions
    private func activateAndDismiss() {
        // 收起动画 - 反向
        withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
            isVisible = false
        }
        
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85).delay(0.05)) {
            expandWidth = 200
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            _ = viewModel.activateSelectedWindow()
            onActivate?()
            onDismiss()
        }
    }
    
    // MARK: - Public Methods
    func selectNext() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.55)) {
            viewModel.selectNext()
        }
    }
    
    func selectPrevious() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.55)) {
            viewModel.selectPrevious()
        }
    }
    
    func activateSelected() {
        activateAndDismiss()
    }
}

/// 窗口项视图
struct WindowItemView: View {
    let window: WindowInfo
    let thumbnail: NSImage?
    let isSelected: Bool
    let index: Int
    
    var body: some View {
        VStack(spacing: 6) {
            // 应用图标/缩略图
            ZStack {
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 36, height: 36)  // 【3. 控制应用icon显示区域】单个图标大小
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 36, height: 36)  // 【3. 控制应用icon显示区域】占位图标大小
                        .overlay(
                            Image(systemName: "app.fill")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.4))
                        )
                }
                
                // 选中指示器
                if isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 44, height: 44)
                }
            }
            
            // 窗口标题（优先显示窗口标题，如果没有则显示应用名）
            Text(window.hasUniqueTitle ? window.displayTitle : window.appName)
                .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
                .frame(width: 80)  // 增加宽度以显示更多文字
                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.white.opacity(0.15) : Color.clear)
                .scaleEffect(isSelected ? 1.1 : 1.0)
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        
        VStack {
            WindowSwitcherView(viewModel: SwitcherViewModel(), onDismiss: {})
            Spacer()
        }
        .padding(.top, 10)
    }
    .frame(width: 800, height: 300)
}
