import SwiftUI

struct IOSSettingsView: View {
    let client: LiveNetworkClient
    let onLogout: () -> Void

    @State private var settings = SettingsState.shared
    @State private var apiBase: String = UserDefaults.standard.string(forKey: "apiBaseURL")
        ?? IOSConfig.apiBaseURL.absoluteString
    @State private var saved = false
    @State private var tenant: TenantInfo?
    @State private var me: User?
    @State private var planDraft = "free"
    @State private var planBusy = false
    @State private var planMessage = ""
    @State private var usage: TenantUsageInfo?
    @State private var subscription: TenantSubscriptionInfo?
    @State private var executionProfile: ExecutionProfileInfo?
    @State private var executionHealth: ExecutionProfileHealth?
    @State private var checkingHealth = false
    @State private var members: [TenantMember] = []
    @State private var membersError = ""
    @State private var showAddMember = false
    @State private var newUsername = ""
    @State private var newEmail = ""
    @State private var newPassword = ""
    @State private var newRole = "viewer"
    @State private var memberBusy = false
    @State private var sessions: [DeviceSessionInfo] = []
    @State private var currentSessionID: String?
    @State private var sessionsError = ""
    @State private var auditEntries: [TenantAuditEntry] = []
    @State private var auditError = ""

    private func auditLabel(_ action: String) -> String {
        switch action {
        case "plan.update": return "套餐变更"
        case "member.add": return "添加成员"
        case "member.role": return "修改角色"
        case "member.remove": return "移除成员"
        case "invite.create": return "创建邀请"
        case "invite.accept": return "接受邀请"
        case "profile.update": return "执行配置"
        case "runtime.provision": return "启动运行时"
        case "runtime.stop": return "停止运行时"
        case "quota.warning": return "配额预警"
        default: return action
        }
    }

    private func planQuota(_ plan: String) -> String {
        switch plan {
        case "pro": return "25 成员 / 200 策略 / 审计 365 天"
        case "enterprise": return "200 成员 / 2000 策略 / 审计 1095 天"
        default: return "5 成员 / 20 策略 / 审计 90 天"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("服务端") {
                    TextField("API Base URL", text: $apiBase)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Button("保存（重启 App 生效）") {
                        UserDefaults.standard.set(apiBase, forKey: "apiBaseURL")
                        saved = true
                    }
                    if saved {
                        Text("已保存，重启后生效。").font(.caption).foregroundStyle(.secondary)
                    }
                    Text("当前会话仍使用：\(IOSConfig.apiBaseURL.absoluteString)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Section("语言") {
                    Picker("界面语言", selection: $settings.language) {
                        Text("中文").tag(Language.zhCN)
                        Text("English").tag(Language.enUS)
                    }
                    .pickerStyle(.segmented)
                }

                Section("租户") {
                    if let tenant {
                        LabeledContent("名称", value: tenant.name)
                        LabeledContent("标识", value: tenant.slug)
                        LabeledContent("角色", value: tenant.role)
                        LabeledContent("套餐", value: (tenant.plan ?? "free").uppercased())
                        LabeledContent("配额", value: planQuota(tenant.plan ?? "free"))
                        LabeledContent("订阅", value: subscription?.status ?? "none")
                        if let end = subscription?.currentPeriodEnd {
                            LabeledContent("到期", value: String(end.prefix(10)))
                        }
                        if me?.isSuperuser == true {
                            Picker("套餐", selection: $planDraft) {
                                Text("free").tag("free")
                                Text("pro").tag("pro")
                                Text("enterprise").tag("enterprise")
                            }
                            Button(planBusy ? "更新中…" : "更新套餐") {
                                Task { await updatePlan() }
                            }
                            .disabled(planBusy)
                            if !planMessage.isEmpty {
                                Text(planMessage).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text("正在加载租户信息…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let usage {
                    Section("用量") {
                        LabeledContent("成员") {
                            Text("\(usage.usage.members) / \(usage.limits.members)")
                                .foregroundStyle(usage.warnings?.contains { $0.resource == "members" } == true ? .red : .primary)
                        }
                        LabeledContent("策略") {
                            Text("\(usage.usage.strategies) / \(usage.limits.strategies)")
                                .foregroundStyle(usage.warnings?.contains { $0.resource == "strategies" } == true ? .red : .primary)
                        }
                        LabeledContent("审计条数", value: "\(usage.usage.auditLogs)")
                        LabeledContent("活跃会话", value: "\(usage.usage.activeSessions)")
                    }
                }

                Section("执行运行时") {
                    if let executionProfile {
                        LabeledContent("模式", value: executionProfile.mode)
                        LabeledContent("状态", value: executionProfile.enabled ? "已启用" : "未启用")
                        LabeledContent("地址", value: executionProfile.freqtrade_url ?? "未配置")
                        LabeledContent("最大持仓", value: "\(executionProfile.max_open_trades)")
                        LabeledContent("运行时状态", value: executionProfile.runtime_status)
                        LabeledContent("最后检查", value: executionProfile.last_health_at ?? "—")
                        if let error = executionProfile.last_error {
                            LabeledContent("错误", value: error)
                        }
                        if let executionHealth {
                            LabeledContent(
                                "健康",
                                value: executionHealth.configured
                                    ? (executionHealth.reachable ? "可达" : "不可达")
                                    : "未配置"
                            )
                        }
                        Button("检查运行时") {
                            Task {
                                checkingHealth = true
                                executionHealth = try? await APIExecutionProfile(client: client).health()
                                checkingHealth = false
                            }
                        }
                        .disabled(checkingHealth)
                    } else {
                        Text("需要平台管理员配置执行运行时。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("成员") {
                    if membersError.isEmpty {
                        Button("添加成员") { showAddMember = true }

                        if members.isEmpty {
                            Text("暂无成员或正在加载…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(members) { member in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(member.username)
                                        Spacer()
                                        Menu(member.role) {
                                            ForEach(["owner", "admin", "trader", "viewer"], id: \.self) { role in
                                                Button(role) {
                                                    Task { await changeRole(member, to: role) }
                                                }
                                            }
                                        }
                                        .font(.caption)
                                    }
                                    Text(member.email)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .swipeActions {
                                    Button("移除", role: .destructive) {
                                        Task { await removeMember(member) }
                                    }
                                }
                            }
                        }
                    } else {
                        Text(membersError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("设备会话") {
                    if sessionsError.isEmpty {
                        ForEach(sessions) { session in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(session.device_name ?? "未知设备")
                                        if session.id == currentSessionID {
                                            Text("当前")
                                                .font(.caption2)
                                                .padding(.horizontal, 5)
                                                .background(Color.accentColor.opacity(0.15))
                                                .clipShape(Capsule())
                                        }
                                        if session.revoked {
                                            Text("已撤销")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Text("\(session.ip_address ?? "—") · \(session.created_at)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if !session.revoked {
                                    Button("撤销", role: .destructive) {
                                        Task { await revokeSession(session) }
                                    }
                                    .font(.caption)
                                }
                            }
                        }
                    } else {
                        Text(sessionsError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("审计日志") {
                    if auditError.isEmpty {
                        if auditEntries.isEmpty {
                            Text("暂无审计记录").font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach(auditEntries.prefix(20)) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(auditLabel(entry.action))
                                Text("actor #\(entry.actorUserId.map(String.init) ?? "—") · \(entry.createdAt ?? "—")")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text(auditError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("账户") {
                    Button("退出登录", role: .destructive, action: onLogout)
                }

                Section("关于") {
                    LabeledContent("客户端", value: "AlphaLoop iOS")
                    LabeledContent("版本", value: "0.1.0")
                }
            }
            .scrollContentBackground(.hidden)
            .background(IOSTheme.background)
            .navigationTitle("设置")
            .sheet(isPresented: $showAddMember) {
                NavigationStack {
                    Form {
                        TextField("用户名", text: $newUsername)
                        TextField("邮箱", text: $newEmail)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                        SecureField("初始密码", text: $newPassword)
                        Picker("角色", selection: $newRole) {
                            ForEach(["owner", "admin", "trader", "viewer"], id: \.self) {
                                Text($0).tag($0)
                            }
                        }
                        if let memberActionError = membersError.isEmpty ? nil : membersError {
                            Text(memberActionError).font(.caption).foregroundStyle(.red)
                        }
                    }
                    .navigationTitle("添加成员")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") { showAddMember = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("添加") {
                                Task { await addMember() }
                            }
                            .disabled(memberBusy || newUsername.isEmpty || newEmail.isEmpty || newPassword.isEmpty)
                        }
                    }
                }
            }
            .task {
                me = try? await APIAuth(client: client).getMe()
                tenant = try? await APIAuth(client: client).getTenant()
                planDraft = tenant?.plan ?? "free"
                usage = try? await APITenantUsage(client: client).get()
                subscription = try? await APITenantSubscription(client: client).get()
                executionProfile = try? await APIExecutionProfile(client: client).get()
                do {
                    members = try await APIMembers(client: client).list()
                } catch {
                    membersError = "需要租户 owner/admin 权限"
                }
                currentSessionID = APISessions.currentSessionID()
                sessions = (try? await APISessions(client: client).list()) ?? []
                do {
                    auditEntries = try await APITenantAudit(client: client).list()
                } catch {
                    auditError = "需要租户 owner/admin 权限"
                }
            }
        }
    }

    private func updatePlan() async {
        planBusy = true
        planMessage = ""
        do {
            let updated = try await APIAuth(client: client).updateTenantPlan(planDraft)
            if var current = tenant {
                current = TenantInfo(
                    id: current.id, name: current.name, slug: current.slug,
                    role: current.role, plan: updated.plan
                )
                tenant = current
            }
            planMessage = "套餐已更新"
        } catch {
            planMessage = error.localizedDescription
        }
        planBusy = false
    }

    private func reloadMembers() async {
        do {
            members = try await APIMembers(client: client).list()
            membersError = ""
        } catch {
            membersError = "需要租户 owner/admin 权限"
        }
    }

    private func addMember() async {
        memberBusy = true
        defer { memberBusy = false }
        do {
            _ = try await APIMembers(client: client).add(
                username: newUsername, email: newEmail,
                password: newPassword, role: newRole,
            )
            newUsername = ""; newEmail = ""; newPassword = ""; newRole = "viewer"
            showAddMember = false
            await reloadMembers()
        } catch {
            membersError = error.localizedDescription
        }
    }

    private func changeRole(_ member: TenantMember, to role: String) async {
        guard role != member.role else { return }
        do {
            _ = try await APIMembers(client: client).updateRole(userId: member.user_id, role: role)
            await reloadMembers()
        } catch {
            membersError = error.localizedDescription
        }
    }

    private func revokeSession(_ session: DeviceSessionInfo) async {
        do {
            try await APISessions(client: client).revoke(id: session.id)
            if session.id == currentSessionID {
                sessionsError = "当前会话已撤销，请重新登录。"
            } else {
                sessions = (try? await APISessions(client: client).list()) ?? []
            }
        } catch {
            sessionsError = error.localizedDescription
        }
    }

    private func removeMember(_ member: TenantMember) async {
        do {
            try await APIMembers(client: client).remove(userId: member.user_id)
            await reloadMembers()
        } catch {
            membersError = error.localizedDescription
        }
    }
}
