import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    let generatedGraph: (strategyId: Int, name: String, market: String, exchange: String, nodeCount: Int)?

    enum Role { case ai, user }

    static func ai(_ text: String, graph: (Int, String, String, String, Int)? = nil) -> ChatMessage {
        ChatMessage(role: .ai, content: text, generatedGraph: graph)
    }
    static func user(_ text: String) -> ChatMessage {
        ChatMessage(role: .user, content: text, generatedGraph: nil)
    }
}

struct AIChatView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(\.networkClient) private var networkClient
    var onStrategyGenerated: (Int) -> Void = { _ in }

    @State private var messages: [ChatMessage] = [
        .ai("你好！我是策略构建助手。用自然语言描述你想做的交易策略，我会自动生成对应的画布节点图。\n\n试试说：\"用 EMA 和 RSI 做比特币趋势跟踪，RSI 低于 30 买入，Binance 交易所\"")
    ]
    @State private var inputText = ""
    @State private var isThinking = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { _, msg in
                            MessageBubble(msg: msg, onOpenGraph: onStrategyGenerated)
                        }
                        if isThinking {
                            ThinkingBubble()
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(PulseSpacing.md)
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation { proxy.scrollTo("bottom") }
                }
                .onChange(of: isThinking) { _, _ in
                    withAnimation { proxy.scrollTo("bottom") }
                }
            }

            Divider().foregroundStyle(colors.border)

            HStack(spacing: 8) {
                TextField("描述你的策略...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textPrimary)
                    .padding(10)
                    .background(colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .focused($isFocused)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Circle().fill(
                            inputText.trimmingCharacters(in: .whitespaces).isEmpty ? colors.border : PulseColors.purple
                        ))
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isThinking)
            }
            .padding(PulseSpacing.sm)
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isThinking else { return }
        messages.append(.user(text))
        inputText = ""
        isThinking = true

        Task {
            do {
                let generator = AIStrategyGenerator(client: networkClient)
                let result = try await generator.generate(prompt: text)
                isThinking = false
                messages.append(.ai(
                    "已根据你的描述生成策略画布：",
                    graph: (result.strategy_id, result.name, result.market, result.exchange, result.graph?.nodes.count ?? 0)
                ))
            } catch {
                isThinking = false
                messages.append(.ai("抱歉，生成过程遇到问题。请再试一次或换个描述试试。"))
            }
        }
    }
}

// MARK: - MessageBubble
private struct MessageBubble: View {
    @Environment(PulseColors.self) private var colors
    let msg: ChatMessage
    var onOpenGraph: (Int) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if msg.role == .ai {
                avatar("🤖", bg: Color.purple.opacity(0.15))
                bubbleContent.alignmentGuide(.leading) { _ in 0 }
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                bubbleContent
                avatar("👤", bg: PulseColors.accent.opacity(0.15))
            }
        }
    }

    private func avatar(_ emoji: String, bg: Color) -> some View {
        Text(emoji).font(.system(size: 13))
            .frame(width: 28, height: 28)
            .background(Circle().fill(bg))
    }

    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(msg.content)
                .font(PulseFonts.caption)
                .foregroundStyle(msg.role == .ai ? colors.textSecondary : colors.textPrimary)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(msg.role == .ai ? Color.white.opacity(0.03) : PulseColors.accent.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(msg.role == .ai ? Color.white.opacity(0.05) : PulseColors.accent.opacity(0.1), lineWidth: 1)
                )

            if let graph = msg.generatedGraph {
                generatedCard(graph)
            }
        }
    }

    private func generatedCard(_ graph: (strategyId: Int, name: String, market: String, exchange: String, nodeCount: Int)) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "square.grid.2x2").font(.system(size: 9)).foregroundStyle(PulseColors.accent)
                Text("策略画布预览").font(PulseFonts.captionMedium).foregroundStyle(PulseColors.accent)
            }

            HStack(spacing: 12) {
                paramItem("名称", graph.name)
                paramItem("市场", graph.market)
                paramItem("交易所", graph.exchange)
            }

            Text("已自动生成 \(graph.nodeCount) 个节点并连线")
                .font(PulseFonts.micro).foregroundStyle(colors.textMuted)

            HStack(spacing: 6) {
                Button { onOpenGraph(graph.strategyId) } label: {
                    Label("打开画布", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(colors.background)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 14).fill(PulseColors.accent))
                }
                .buttonStyle(.plain)

                Button {} label: {
                    Label("重新生成", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 9))
                        .foregroundStyle(colors.textSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(colors.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(colors.border, lineWidth: 1))
    }

    private func paramItem(_ key: String, _ val: String) -> some View {
        HStack(spacing: 2) {
            Text(key).font(.system(size: 8)).foregroundStyle(colors.textMuted)
            Text(val).font(.system(size: 9, weight: .semibold)).foregroundStyle(colors.textPrimary)
        }
    }
}

// MARK: - ThinkingBubble
private struct ThinkingBubble: View {
    @Environment(PulseColors.self) private var colors
    @State private var animating = false

    var body: some View {
        HStack(spacing: 10) {
            Text("🤖").font(.system(size: 13))
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.purple.opacity(0.15)))
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(colors.textMuted)
                        .frame(width: 5, height: 5)
                        .scaleEffect(animating ? 1.3 : 0.7)
                        .opacity(animating ? 1.0 : 0.3)
                        .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2), value: animating)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
            .onAppear { animating = true }
            Spacer(minLength: 40)
        }
    }
}
