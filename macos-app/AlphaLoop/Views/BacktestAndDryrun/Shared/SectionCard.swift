import SwiftUI

struct SectionCard<Content: View>: View {
    let title: String
    var dataNote: String = ""
    var locked: Bool = false
    @Environment(PulseColors.self) private var colors
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            HStack {
                Text(title).font(PulseFonts.headline)
                if !dataNote.isEmpty {
                    Text(dataNote)
                        .font(PulseFonts.micro)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if locked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            content
        }
        .padding(PulseSpacing.md)
        .background(colors.surfaceHover.opacity(0.35), in: RoundedRectangle(cornerRadius: PulseRadii.md))
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.md).stroke(colors.border, lineWidth: 1))
        .opacity(locked ? 0.4 : 1.0)
    }
}
