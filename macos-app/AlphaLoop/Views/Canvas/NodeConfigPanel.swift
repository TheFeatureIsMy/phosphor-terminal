import SwiftUI
import UniformTypeIdentifiers

struct NodeConfigPanel: View {
    @Environment(PulseColors.self) private var colors
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
                        sectionLabel("核心参数")
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
                        sectionLabel("端口连线")
                        portConnectionSection

                        Divider().foregroundStyle(colors.border)
                    }

                    // Layer 3: Advanced options (collapsed by default)
                    DisclosureGroup(isExpanded: $showAdvanced) {
                        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                            sectionLabel("名称")
                            configTextField(text: $nameText, placeholder: definition?.name ?? "")
                            sectionLabel("备注")
                            configTextField(text: $notesText, placeholder: "添加备注...")
                            sectionLabel("输出变量名")
                            configTextField(text: .constant(""), placeholder: "自动生成")
                            sectionLabel("执行条件")
                            configTextField(text: .constant(""), placeholder: "始终执行")
                        }.padding(.top, PulseSpacing.xs)
                    } label: {
                        Text("高级选项").font(PulseFonts.captionMedium).foregroundStyle(colors.textMuted)
                    }
                }
                .padding(PulseSpacing.md)
            }
        }
        .frame(width: 280)
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
            .buttonStyle(.plain).help("关闭面板")
            Button { showDeleteConfirm = true } label: {
                Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(PulseColors.danger)
            }
            .buttonStyle(.plain).help("删除节点")
            .confirmationDialog("确认删除", isPresented: $showDeleteConfirm) {
                Button("删除", role: .destructive) { onDelete?() }
                Button("取消", role: .cancel) {}
            } message: { Text("确定要删除节点 \"\(definition?.name ?? node.nodeType)\" 吗？") }
        }
        .padding(PulseSpacing.sm)
    }

    // MARK: - Port connection status

    @ViewBuilder
    private var portConnectionSection: some View {
        if let def = definition {
            if !def.inputPorts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    sectionLabel("输入")
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
                    sectionLabel("输出")
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
                Text("→ 可选")
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
                Text("未连接")
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
                    Text(path.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "选择文件...")
                        .font(PulseFonts.caption).foregroundStyle(path != nil ? colors.textPrimary : colors.textMuted).lineLimit(1)
                    Button { showFilePicker = true } label: {
                        Image(systemName: "folder").font(.system(size: 12)).foregroundStyle(PulseColors.accent)
                    }.buttonStyle(.plain)
                }
            case .multiselect:
                configTextField(
                    text: Binding(get: { node.config[field.key]?.value as? String ?? "" },
                                  set: { onConfigChange?(field.key, AnyCodable($0)) }),
                    placeholder: "选择..."
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
                fieldErrors[field.key] = "最小 \(Int(min))"
            } else if let max = field.max, d > max {
                fieldErrors[field.key] = "最大 \(Int(max))"
            } else {
                fieldErrors.removeValue(forKey: field.key)
            }
        }
    }
}
