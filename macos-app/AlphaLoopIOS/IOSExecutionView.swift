import SwiftUI

struct IOSExecutionView: View {
    let client: LiveNetworkClient

    @State private var data: OrdersPositionsBFFResponse?
    @State private var isLoading = false
    @State private var error: String?
    @State private var pending: PendingAction?
    @State private var batch: BatchKind?
    @State private var busy = false

    enum BatchKind: String, Identifiable {
        case cancelAll, closeAll
        var id: String { rawValue }
        var title: String {
            switch self {
            case .cancelAll: return "撤销全部挂单？"
            case .closeAll: return "市价平掉全部持仓？"
            }
        }
    }

    private var api: APIExecutionBFF { APIExecutionBFF(client: client) }

    enum PendingAction: Identifiable {
        case cancel(OrderBFFResponse)
        case close(PositionBFFResponse)

        var id: String {
            switch self {
            case .cancel(let order): return "cancel-\(order.id)"
            case .close(let position): return "close-\(position.id)"
            }
        }

        var title: String {
            switch self {
            case .cancel(let order): return "撤销 \(order.symbol) \(order.side) 订单？"
            case .close(let position): return "市价平掉 \(position.symbol) 仓位？"
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if let data {
                    if data.state != "healthy" {
                        Section {
                            Label(data.state, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            if !data.reasonCodes.isEmpty {
                                Text(data.reasonCodes.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("批量操作") {
                        Button("全部撤单", role: .destructive) { batch = .cancelAll }
                            .disabled(data.orders.isEmpty || busy)
                        Button("全部平仓", role: .destructive) { batch = .closeAll }
                            .disabled(data.positions.isEmpty || busy)
                    }

                    Section("挂单 (\(data.orders.count))") {
                        if data.orders.isEmpty {
                            Text("无挂单").font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach(data.orders) { order in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(order.symbol).font(.subheadline.monospaced())
                                    Text("\(order.side) · \(order.type) · \(order.status)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let price = order.price {
                                    Text(price, format: .number.precision(.fractionLength(2)))
                                        .font(.caption.monospacedDigit())
                                }
                                Button("撤单", role: .destructive) {
                                    pending = .cancel(order)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }

                    Section("持仓 (\(data.positions.count))") {
                        if data.positions.isEmpty {
                            Text("无持仓").font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach(data.positions) { position in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(position.symbol).font(.subheadline.monospaced())
                                    Text(position.side).font(.caption2).foregroundStyle(.secondary)
                                    Spacer()
                                    Text(position.unrealizedPnlPct, format: .number.precision(.fractionLength(2)))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(position.unrealizedPnl >= 0 ? .green : .red)
                                }
                                HStack {
                                    Text("入场 \(position.avgEntryPrice, format: .number.precision(.fractionLength(2)))")
                                    Text("现价 \(position.currentPrice, format: .number.precision(.fractionLength(2)))")
                                    Spacer()
                                    Button("平仓", role: .destructive) {
                                        pending = .close(position)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if let error {
                    Section {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(IOSTheme.background)
            .navigationTitle("执行")
            .refreshable { await load() }
            .task { await load() }
            .overlay {
                if isLoading && data == nil { ProgressView("加载中…") }
            }
            .overlay {
                if busy { ProgressView().padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12)) }
            }
            .confirmationDialog(
                pending?.title ?? "",
                isPresented: Binding(
                    get: { pending != nil },
                    set: { if !$0 { pending = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("确认", role: .destructive) {
                    Task { await confirm() }
                }
                Button("取消", role: .cancel) { pending = nil }
            } message: {
                Text("该操作会直接发送到执行端。")
            }
            .confirmationDialog(
                batch?.title ?? "",
                isPresented: Binding(
                    get: { batch != nil },
                    set: { if !$0 { batch = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("确认", role: .destructive) {
                    Task { await confirmBatch() }
                }
                Button("取消", role: .cancel) { batch = nil }
            } message: {
                Text("批量操作不可逐笔回滚。")
            }
        }
    }

    private func load() async {
        isLoading = true
        error = nil
        do {
            data = try await api.getOrdersPositions()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func confirmBatch() async {
        guard let kind = batch else { return }
        batch = nil
        busy = true
        error = nil
        do {
            switch kind {
            case .cancelAll:
                _ = try await api.cancelAllOrders()
            case .closeAll:
                _ = try await api.forceCloseAllPositions()
            }
            await load()
        } catch {
            self.error = error.localizedDescription
        }
        busy = false
    }

    private func confirm() async {
        guard let action = pending else { return }
        pending = nil
        busy = true
        error = nil
        do {
            switch action {
            case .cancel(let order):
                _ = try await api.cancelOrder(id: order.id)
            case .close(let position):
                _ = try await api.closePosition(id: position.id)
            }
            await load()
        } catch {
            self.error = error.localizedDescription
        }
        busy = false
    }
}
