import SwiftUI

struct AIChatView: View {
    @Environment(PulseColors.self) private var colors
    var onStrategyGenerated: (Int) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 32)).foregroundStyle(colors.textMuted)
            Text("AI 对话生成").font(PulseFonts.body).foregroundStyle(colors.textSecondary)
            Text("即将接入").font(PulseFonts.caption).foregroundStyle(colors.textMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}
