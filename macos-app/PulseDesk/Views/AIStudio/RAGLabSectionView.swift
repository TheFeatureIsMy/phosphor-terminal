// RAGLabSectionView.swift — RAG 策略实验室
// 文档上传、知识检索、AI 策略生成
// 注意: 本视图使用独立的 TerminalLabel 标题栏，而非其他 section 的 configBar 模式。保留现有结构。

import SwiftUI

struct RAGLabSectionView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @State private var query = ""
    @State private var isGenerating = false
    @State private var generatedStrategy: String?
    @State private var safetyStatus: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                TerminalLabel(text: "RAG 策略实验室")
                Spacer()
                BadgeDot(color: PulseColors.cyan, label: "实验性", size: .small)
            }
            .padding(PulseSpacing.lg)

            Divider().foregroundStyle(colors.border)

            ScrollView {
                VStack(spacing: PulseSpacing.lg) {
                    // 知识上传区
                    uploadSection

                    // 查询生成区
                    querySection

                    // 错误信息
                    if let errorMessage {
                        errorBanner(errorMessage)
                    }

                    // 生成结果
                    if let strategy = generatedStrategy {
                        resultSection(strategy)
                    }
                }
                .padding(PulseSpacing.lg)
            }
        }
    }

    // MARK: - 上传区
    private var uploadSection: some View {
        VStack(spacing: PulseSpacing.md) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(PulseColors.accent.opacity(0.6))

            Text("上传知识文档")
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(colors.textPrimary)

            Text("支持 PDF、TXT、Markdown 格式，AI 将基于文档内容生成量化策略")
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
                .multilineTextAlignment(.center)

            HStack(spacing: PulseSpacing.sm) {
                ProofAlphaButton(title: "选择文件") { }
                ProofAlphaButton(title: "从 URL 导入", action: { }, style: .ghost)
            }

            // 已上传文档列表
            HStack(spacing: PulseSpacing.xs) {
                Image(systemName: "doc.fill")
                    .foregroundStyle(PulseColors.accent)
                Text("quant_strategy_guide.pdf")
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textSecondary)
                Text("· 24 个知识块")
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                Spacer()
                BadgeDot(color: PulseColors.success, label: "已索引", size: .small)
            }
            .padding(PulseSpacing.sm)
            .background(colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.xs))
        }
        .cardStyle()
    }

    // MARK: - 查询区
    private var querySection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: "策略描述")

            TextEditor(text: $query)
                .font(PulseFonts.body)
                .foregroundStyle(colors.textPrimary)
                .frame(minHeight: 80)
                .frame(maxHeight: 200)
                .scrollContentBackground(.hidden)
                .padding(PulseSpacing.xs)
                .background(colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.xs))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.xs)
                        .stroke(colors.border, lineWidth: 1)
                )

            HStack {
                Text("基于知识库生成策略代码，需通过安全扫描后才能执行")
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)

                Spacer()

                ProofAlphaButton(title: "生成策略") {
                    Task { await generateStrategy() }
                }
                .opacity(query.isEmpty ? 0.5 : 1)
                .disabled(query.isEmpty || isGenerating)
            }
        }
        .cardStyle()
    }

    // MARK: - 错误横幅
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(PulseColors.loss)
            Text(message)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)
            Spacer()
        }
        .padding(PulseSpacing.sm)
        .background(PulseColors.loss.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.xs))
    }

    // MARK: - 结果区
    private func resultSection(_ code: String) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            HStack {
                TerminalLabel(text: "生成结果")
                Spacer()
                BadgeDot(
                    color: safetyStatus == "safe" ? PulseColors.success : PulseColors.warning,
                    label: safetyStatus == "safe" ? "安全通过" : safetyStatus ?? "未知",
                    size: .small
                )
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(PulseFonts.caption.monospaced())
                    .foregroundStyle(colors.textSecondary)
                    .textSelection(.enabled)
            }
            .padding(PulseSpacing.sm)
            .background(colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.xs))

            HStack(spacing: PulseSpacing.sm) {
                ProofAlphaButton(title: "运行回测") { }
                ProofAlphaButton(title: "部署策略") { }
                ProofAlphaButton(title: "复制代码", action: { }, style: .ghost)
            }
        }
        .cardStyle()
    }

    private func generateStrategy() async {
        isGenerating = true
        errorMessage = nil
        do {
            let response = try await networkClient.ragGenerate(
                prompt: query,
                riskLevel: "medium",
                market: "crypto"
            )
            generatedStrategy = response.code
            safetyStatus = response.safetyStatus
        } catch {
            errorMessage = "策略生成失败: \(error.localizedDescription)"
            generatedStrategy = nil
            safetyStatus = nil
        }
        isGenerating = false
    }
}
