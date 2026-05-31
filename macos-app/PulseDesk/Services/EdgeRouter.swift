import Foundation

struct EdgeRouter {
    private let titleBarHeight: CGFloat = 30
    private let portSpacing: CGFloat = 18
    private let portGap: CGFloat = 12
    private let halfPortSize: CGFloat = 6

    func portPosition(
        node: CanvasNode,
        definition: NodeDefinition,
        portName: String,
        isInput: Bool
    ) -> CGPoint? {
        if isInput {
            guard let index = definition.inputPorts.firstIndex(where: { $0.name == portName }) else {
                return nil
            }
            return CGPoint(
                x: node.position.x,
                y: node.position.y + titleBarHeight + CGFloat(index) * portSpacing + halfPortSize
            )
        } else {
            guard let index = definition.outputPorts.firstIndex(where: { $0.name == portName }) else {
                return nil
            }
            let inputCount = CGFloat(definition.inputPorts.count)
            return CGPoint(
                x: node.position.x + node.size.width,
                y: node.position.y + titleBarHeight + inputCount * portSpacing + portGap + CGFloat(index) * portSpacing + halfPortSize
            )
        }
    }
}
