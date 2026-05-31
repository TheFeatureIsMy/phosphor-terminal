import SwiftUI

struct SnapGuidesView: View {
    @Environment(PulseColors.self) private var colors
    let guides: [SnapGuide]
    let scale: CGFloat
    let offset: CGPoint

    var body: some View {
        Canvas { context, size in
            for guide in guides {
                let screenPos = guide.position * scale + (guide.orientation == .horizontal ? offset.y : offset.x)
                var path = Path()

                switch guide.orientation {
                case .horizontal:
                    path.move(to: CGPoint(x: 0, y: screenPos))
                    path.addLine(to: CGPoint(x: size.width, y: screenPos))
                case .vertical:
                    path.move(to: CGPoint(x: screenPos, y: 0))
                    path.addLine(to: CGPoint(x: screenPos, y: size.height))
                }

                context.stroke(path, with: .color(PulseColors.accent.opacity(0.5)),
                               style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .allowsHitTesting(false)
    }
}
