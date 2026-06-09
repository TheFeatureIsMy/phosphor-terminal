import SwiftUI
import UniformTypeIdentifiers

struct NodeConfigPanel: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    let node: CanvasNode
    let definition: NodeDefinition?
    var onDelete: (() -> Void)?
    var onConfigChange: ((String, AnyCodable) -> Void)?
    var onWidgetChange: ((String, AnyCodable) -> Void)?
    var onClose: (() -> Void)?
    var connectedInputPorts: [String: (connected: Bool, peerName: String?, peerNodeId: UUID?)] = [:]
    var connectedOutputPorts: [String: (connected: Bool, peerName: String?, peerNodeId: UUID?)] = [:]

    @State private var showAdvanced = false
    @State private var showDeleteConfirm = false
    @State private var nameText: String = ""
    @State private var notesText: String = ""
    @State private var fieldErrors: [String: String] = [:]
    @State private var showFilePicker = false

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().foregroundStyle(colors.border)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: PulseSpacing.md) {
                    // Layer 1: Core parameters
                    if let definition, !definition.configSchema.isEmpty {
                        sectionLabel(L10n.zh("核心参数", en: "Core Parameters"))
                        ForEach(definition.configSchema) { field in
                            VStack(alignment: .leading, spacing: 2) {
                                configFieldView(field)
                                if let error = fieldErrors[field.key] {
                                    Text(error).font(PulseFonts.micro).foregroundStyle(PulseColors.danger)
                                }
                            }
                        }

                        Divider().foregroundStyle(colors.border)
                    }

                    // Layer 2: Port connection status
                    if hasPorts {
                        sectionLabel(L10n.zh("端口连线", en: "Port Connections"))
                        portConnectionSection

                        Divider().foregroundStyle(colors.border)
                    }

                    // Layer 3: Advanced options (collapsed by default)
                    DisclosureGroup(isExpanded: $showAdvanced) {
                        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                            sectionLabel(L10n.zh("名称", en: "Name"))
                            configTextField(text: $nameText, placeholder: definition?.name ?? "")
                            sectionLabel(L10n.zh("备注", en: "Notes"))
                            configTextField(text: $notesText, placeholder: L10n.zh("添加备注...", en: "Add notes..."))
                            sectionLabel(L10n.zh("输出变量名", en: "Output Variable"))
                            configTextField(text: .constant(""), placeholder: L10n.zh("自动生成", en: "Auto-generated"))
                            sectionLabel(L10n.zh("执行条件", en: "Execution Condition"))
                            configTextField(text: .constant(""), placeholder: L10n.zh("始终执行", en: "Always execute"))
                        }.padding(.top, PulseSpacing.xs)
                    } label: {
                        Text(L10n.zh("高级选项", en: "Advanced Options")).font(PulseFonts.captionMedium).foregroundStyle(colors.textMuted)
                    }
                }
                .padding(PulseSpacing.md)
            }
        }
        .frame(width: 280)
        .id(settingsState.language)
        .task { reloadNodeData() }
        .onChange(of: node.id) { _, _ in reloadNodeData() }
        .onChange(of: nameText) { _, new in onConfigChange?("name", AnyCodable(new)) }
        .onChange(of: notesText) { _, new in onConfigChange?("notes", AnyCodable(new)) }
        .background(colors.background)
        .overlay(Rectangle().frame(width: 1).foregroundStyle(colors.border), alignment: .leading)
        .shadow(color: .black.opacity(0.4), radius: 8, x: -2)
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.json, .commaSeparatedText, UTType(filenameExtension: "py") ?? .data]) { result in
            if case .success(let url) = result {
                onConfigChange?("filePath", AnyCodable(url.path))
            }
        }
    }

    private var hasPorts: Bool {
        guard let def = definition else { return false }
        return !def.inputPorts.isEmpty || !def.outputPorts.isEmpty
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: PulseSpacing.xs) {
            Image(systemName: definition?.icon ?? "circle")
                .font(.system(size: 14)).foregroundStyle(definition?.color ?? colors.textSecondary)
            Text(definition?.name ?? node.nodeType)
                .font(PulseFonts.bodyMedium).foregroundStyle(colors.textPrimary).lineLimit(1)
            Spacer()
            Button { onClose?() } label: {
                Image(systemName: "xmark").font(.system(size: 10)).foregroundStyle(colors.textSecondary)
            }
            .buttonStyle(.plain).help(L10n.zh("关闭面板", en: "Close Panel"))
            Button { showDeleteConfirm = true } label: {
                Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(PulseColors.danger)
            }
            .buttonStyle(.plain).help(L10n.zh("删除节点", en: "Delete Node"))
            .confirmationDialog(L10n.zh("确认删除", en: "Confirm Delete"), isPresented: $showDeleteConfirm) {
                Button(L10n.zh("删除", en: "Delete"), role: .destructive) { onDelete?() }
                Button(L10n.zh("取消", en: "Cancel"), role: .cancel) {}
            } message: { Text(L10n.zh("确定要删除节点 \"\(definition?.name ?? node.nodeType)\" 吗？", en: "Are you sure you want to delete node \"\(definition?.name ?? node.nodeType)\"?")) }
        }
        .padding(PulseSpacing.sm)
    }

    // MARK: - Port connection status

    @ViewBuilder
    private var portConnectionSection: some View {
        if let def = definition {
            if !def.inputPorts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    sectionLabel(L10n.zh("输入", en: "Inputs"))
                    ForEach(def.inputPorts) { port in
                        let conn = connectedInputPorts[port.key]
                        inputPortRow(
                            port: port,
                            isConnected: conn?.connected ?? false,
                            peerName: conn?.peerName
                        )
                    }
                }
            }
            if !def.outputPorts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    sectionLabel(L10n.zh("输出", en: "Outputs"))
                    ForEach(def.outputPorts) { port in
                        let conn = connectedOutputPorts[port.key]
                        outputPortRow(
                            port: port,
                            isConnected: conn?.connected ?? false,
                            peerName: conn?.peerName
                        )
                    }
                }
            }
        }
    }

    private func inputPortRow(port: PortDefinition, isConnected: Bool, peerName: String?) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isConnected ? PulseColors.accent : colors.textMuted)
                .frame(width: 6, height: 6)
            Text(port.name)
                .font(PulseFonts.caption).foregroundStyle(colors.textPrimary)
            if port.isRequired {
                Text("*")
                    .font(PulseFonts.caption).foregroundStyle(PulseColors.danger)
            }
            Spacer()
            if isConnected, let name = peerName {
                Text("→ \(name)")
                    .font(PulseFonts.caption).foregroundStyle(PulseColors.accent)
            } else {
                Text(L10n.zh("→ 可选", en: "→ Optional"))
                    .font(PulseFonts.caption).foregroundStyle(colors.textMuted)
            }
        }
    }

    private func outputPortRow(port: PortDefinition, isConnected: Bool, peerName: String?) -> some View {
        HStack(spacing: 6) {
            Text(port.name)
                .font(PulseFonts.caption).foregroundStyle(colors.textPrimary)
            Spacer()
            Circle()
                .fill(isConnected ? PulseColors.accent : colors.textMuted)
                .frame(width: 6, height: 6)
            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: 6))
                .foregroundStyle(isConnected ? PulseColors.accent : colors.textMuted)
            if isConnected, let name = peerName {
                Text("→ \(name)")
                    .font(PulseFonts.caption).foregroundStyle(PulseColors.accent)
            } else {
                Text(L10n.zh("未连接", en: "Disconnected"))
                    .font(PulseFonts.caption).foregroundStyle(colors.textMuted)
            }
        }
    }

    // MARK: - Config fields

    @ViewBuilder
    private func configFieldView(_ field: ConfigField) -> some View {
        HStack(alignment: .center, spacing: 4) {
            Text(field.label).font(PulseFonts.caption).foregroundStyle(colors.textMuted)
                .frame(width: 60, alignment: .leading)

            switch field.fieldType {
            case .text, .expression, .code:
                configTextField(
                    text: Binding(get: { node.config[field.key]?.value as? String ?? "" },
                                  set: { onConfigChange?(field.key, AnyCodable($0)); validateField(field, value: $0) }),
                    placeholder: field.defaultValue?.value as? String ?? ""
                )
            case .number:
                configTextField(
                    text: Binding(
                        get: { node.config[field.key].flatMap { String(describing: $0.value) } ?? "" },
                        set: { str in
                            if let d = Double(str) { onConfigChange?(field.key, AnyCodable(d)); validateField(field, value: d) }
                        }
                    ), placeholder: "0"
                )
            case .slider:
                let current = node.config[field.key]?.value as? Double ?? field.defaultValue?.value as? Double ?? 0
                let range = (field.min ?? 0)...(field.max ?? 100)
                Slider(value: Binding(get: { current },
                                      set: { onConfigChange?(field.key, AnyCodable($0)); validateField(field, value: $0) }),
                       in: range, step: field.step ?? 1)
                    .tint(PulseColors.accent)
                Text(String(format: "%.0f", current)).font(PulseFonts.caption)
                    .foregroundStyle(colors.textSecondary).frame(width: 28, alignment: .trailing)
            case .dropdown:
                let current = node.config[field.key]?.value as? String ?? field.defaultValue?.value as? String ?? ""
                Picker(selection: Binding(get: { current }, set: { onConfigChange?(field.key, AnyCodable($0)) })) {
                    ForEach(field.options ?? [], id: \.self) { Text($0).tag($0) }
                } label: { EmptyView() }.pickerStyle(.menu).tint(PulseColors.accent)
            case .toggle:
                let current = node.config[field.key]?.value as? Bool ?? false
                Toggle(isOn: Binding(get: { current }, set: { onConfigChange?(field.key, AnyCodable($0)) })) { EmptyView() }
                    .toggleStyle(.switch).tint(PulseColors.accent)
            case .filePicker:
                let path = node.config[field.key]?.value as? String
                HStack(spacing: 4) {
                    Text(path.map { URL(fileURLWithPath: $0).lastPathComponent } ?? L10n.zh("选择文件...", en: "Select file..."))
                        .font(PulseFonts.caption).foregroundStyle(path != nil ? colors.textPrimary : colors.textMuted).lineLimit(1)
                    Button { showFilePicker = true } label: {
                        Image(systemName: "folder").font(.system(size: 12)).foregroundStyle(PulseColors.accent)
                    }.buttonStyle(.plain)
                }
            case .multiselect:
                configTextField(
                    text: Binding(get: { node.config[field.key]?.value as? String ?? "" },
                                  set: { onConfigChange?(field.key, AnyCodable($0)) }),
                    placeholder: L10n.zh("选择...", en: "Select...")
                )
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(PulseFonts.captionMedium).foregroundStyle(colors.textMuted)
    }

    private func configTextField(text: Binding<String>, placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain).font(PulseFonts.caption).foregroundStyle(colors.textPrimary)
            .padding(PulseSpacing.xs).background(colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
            .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(colors.border, lineWidth: 1))
    }

    private func reloadNodeData() {
        nameText = node.config["name"]?.value as? String ?? definition?.name ?? ""
        notesText = node.config["notes"]?.value as? String ?? ""
    }

    private func validateField(_ field: ConfigField, value: Any) {
        if let d = value as? Double {
            if let min = field.min, d < min {
                fieldErrors[field.key] = L10n.zh("最小 \(Int(min))", en: "Min \(Int(min))")
            } else if let max = field.max, d > max {
                fieldErrors[field.key] = L10n.zh("最大 \(Int(max))", en: "Max \(Int(max))")
            } else {
                fieldErrors.removeValue(forKey: field.key)
            }
        }
    }
}
