// DrawerContainer.swift — 右侧滑入抽屉容器：backdrop + 动画 + ESC

import SwiftUI

struct DrawerContainer<Content: View>: View {
    @Binding var isPresented: Bool
    let width: CGFloat
    @ViewBuilder let content: Content
    @Environment(PulseColors.self) private var colors

    var body: some View {
        ZStack(alignment: .trailing) {
            if isPresented {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { isPresented = false }
                    .transition(.opacity)

                content
                    .frame(width: width)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.card)
                            .fill(colors.cardBackground)
                            .overlay(RoundedRectangle(cornerRadius: PulseRadii.card).stroke(colors.border, lineWidth: 1))
                            .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .background(
                        Button("") { isPresented = false }
                            .keyboardShortcut(.escape, modifiers: [])
                            .opacity(0)
                    )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isPresented)
    }
}
