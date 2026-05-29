// NodeConfigPanel.swift — 右侧节点配置面板 (320px)
// 节点选中时滑入，动态渲染 configSchema 字段

import SwiftUI

struct NodeConfigPanel: View {
    let node: CanvasNode
    let definition: NodeDefinition?
    var onDelete: (() -> Void)?
    var onConfigChange: ((String, AnyCodable) -> Void)?
    var onWidgetChange: ((String, AnyCodable) -> Void)?

    @State private var showAdvanced = false
    @State private var nameText: String = ""
    @State private var notesText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider().foregroundStyle(PulseColors.border)

            // Scrollable content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: PulseSpacing.md) {
                    // Name field
                    sectionLabel("名称")
                    configTextField(text: $nameText, placeholder: definition?.name ?? "")

                    // Notes field
                    sectionLabel("备注")
                    configTextField(text: $notesText, placeholder: "添加备注...")

                    Divider().foregroundStyle(PulseColors.border)

                    // Dynamic config fields
                    if let definition, !definition.configSchema.isEmpty {
                        sectionLabel("参数")
                        ForEach(definition.configSchema) { field in
                            configFieldView(field)
                        }
                    }

                    Divider().foregroundStyle(PulseColors.border)

                    // Advanced section (collapsible)
                    DisclosureGroup(isExpanded: $showAdvanced) {
                        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                            sectionLabel("输出变量名")
                            configTextField(text: .constant(""), placeholder: "自动生成")

                            sectionLabel("执行条件")
                            configTextField(text: .constant(""), placeholder: "始终执行")
                        }
                        .padding(.top, PulseSpacing.xs)
                    } label: {
                        Text("高级选项")
                            .font(PulseFonts.captionMedium)
                            .foregroundStyle(PulseColors.textSecondary)
                    }
                }
                .padding(PulseSpacing.md)
            }
        }
        .frame(width: 320)
        .task {
            nameText = node.config["name"]?.value as? String
                ?? definition?.name ?? ""
            notesText = node.config["notes"]?.value as? String ?? ""
        }
        .onChange(of: nameText) {
            onConfigChange?("name", AnyCodable(nameText))
        }
        .onChange(of: notesText) {
            onConfigChange?("notes", AnyCodable(notesText))
        }
        .background(PulseColors.surfaceElevated)
        .overlay(
            Rectangle()
                .fill(PulseGlass.surfaceTint)
                .allowsHitTesting(false)
        )
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundStyle(PulseColors.border),
            alignment: .leading
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: PulseSpacing.xs) {
            Image(systemName: definition?.icon ?? "circle")
                .font(.system(size: 14))
                .foregroundStyle(definition?.color ?? PulseColors.textSecondary)

            Text(definition?.name ?? node.nodeType)
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(PulseColors.textPrimary)
                .lineLimit(1)

            Spacer()

            Button {
                onDelete?()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(PulseColors.danger)
            }
            .buttonStyle(.plain)
            .help("删除节点")
        }
        .padding(PulseSpacing.sm)
    }

    // MARK: - Config field renderers

    @ViewBuilder
    private func configFieldView(_ field: ConfigField) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(field.label)
                .font(PulseFonts.caption)
                .foregroundStyle(PulseColors.textSecondary)

            switch field.fieldType {
            case .text, .expression, .code:
                configTextField(
                    text: Binding(
                        get: { node.config[field.key]?.value as? String ?? "" },
                        set: { onConfigChange?(field.key, AnyCodable($0)) }
                    ),
                    placeholder: field.defaultValue?.value as? String ?? ""
                )

            case .number:
                HStack {
                    configTextField(
                        text: Binding(
                            get: { String(describing: node.config[field.key]?.value ?? field.defaultValue?.value ?? "") },
                            set: { str in
                                if let double = Double(str) {
                                    onConfigChange?(field.key, AnyCodable(double))
                                }
                            }
                        ),
                        placeholder: "0"
                    )
                    if let min = field.min, let max = field.max {
                        Text("[\(Int(min))-\(Int(max))]")
                            .font(PulseFonts.micro)
                            .foregroundStyle(PulseColors.textMuted)
                    }
                }

            case .slider:
                let current = node.config[field.key]?.value as? Double
                    ?? field.defaultValue?.value as? Double ?? 0
                let range = (field.min ?? 0)...(field.max ?? 100)
                let step = field.step ?? 1
                HStack(spacing: PulseSpacing.xs) {
                    Slider(
                        value: Binding(
                            get: { current },
                            set: { onConfigChange?(field.key, AnyCodable($0)) }
                        ),
                        in: range,
                        step: step
                    )
                    .tint(PulseColors.accent)
                    Text(String(format: "%.0f", current))
                        .font(PulseFonts.monoSmall)
                        .foregroundStyle(PulseColors.textSecondary)
                        .frame(width: 36, alignment: .trailing)
                }

            case .dropdown:
                let current = node.config[field.key]?.value as? String
                    ?? field.defaultValue?.value as? String ?? ""
                Picker(selection: Binding(
                    get: { current },
                    set: { onConfigChange?(field.key, AnyCodable($0)) }
                )) {
                    ForEach(field.options ?? [], id: \.self) { option in
                        Text(option).tag(option)
                    }
                } label: { EmptyView() }
                .pickerStyle(.menu)
                .tint(PulseColors.accent)

            case .toggle:
                let current = node.config[field.key]?.value as? Bool ?? false
                Toggle(isOn: Binding(
                    get: { current },
                    set: { onConfigChange?(field.key, AnyCodable($0)) }
                )) {
                    Text(field.label)
                        .font(PulseFonts.caption)
                }
                .toggleStyle(.switch)
                .tint(PulseColors.accent)

            case .multiselect:
                // Simplified: show as comma-separated text
                configTextField(
                    text: Binding(
                        get: { node.config[field.key]?.value as? String ?? "" },
                        set: { onConfigChange?(field.key, AnyCodable($0)) }
                    ),
                    placeholder: "选择..."
                )

            case .filePicker:
                HStack {
                    configTextField(text: .constant(""), placeholder: "选择文件...")
                    Button {
                        // File picker would open here
                    } label: {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                            .foregroundStyle(PulseColors.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Shared components

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(PulseFonts.captionMedium)
            .foregroundStyle(PulseColors.textMuted)
    }

    private func configTextField(text: Binding<String>, placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(PulseFonts.caption)
            .foregroundStyle(PulseColors.textPrimary)
            .padding(PulseSpacing.xs)
            .background(PulseColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .stroke(PulseColors.border, lineWidth: 1)
            )
    }
}
