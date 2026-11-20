import SwiftUI

/// Shared visual language with the web terminal: near-black canvas, lime accent,
/// mono labels, thin bordered cards.
enum IOSTheme {
    static let background = Color(hex: "0A0A0C")
    static let card = Color(hex: "111214")
    static let surface = Color(hex: "17181C")
    static let border = Color(hex: "26272D")
    static let accent = Color(hex: "D8FF3D")
    static let onAccent = Color(hex: "0A0A0C")
    static let text = Color(hex: "F5F6F8")
    static let textSecondary = Color(hex: "9BA0AE")
    static let textMuted = Color(hex: "60656F")
    static let bull = Color(hex: "3DF584")
    static let bear = Color(hex: "FF4D6D")
    static let warning = Color(hex: "FFB84D")

    static let monoLabel = Font.system(size: 10, weight: .semibold, design: .monospaced)
    static let mono = Font.system(size: 12, weight: .medium, design: .monospaced)
    static let title = Font.system(size: 28, weight: .bold, design: .rounded)

    static var backgroundView: some View {
        ZStack {
            background.ignoresSafeArea()
            LinearGradient(
                colors: [accent.opacity(0.06), .clear, .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

struct IOSCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(IOSTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(IOSTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension View {
    func iosCard() -> some View { modifier(IOSCardModifier()) }

    func iosPageBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(IOSTheme.background)
    }
}

struct IOSSectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(IOSTheme.monoLabel)
            .tracking(1.2)
            .foregroundStyle(IOSTheme.textMuted)
    }
}
