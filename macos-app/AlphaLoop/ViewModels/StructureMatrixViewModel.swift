// StructureMatrixViewModel.swift — 结构矩阵 ViewModel

import SwiftUI

@Observable
@MainActor
final class StructureMatrixViewModel {
    var matrixData: StructureMatrixBFFResponse?
    var selectedSymbol = "BTC/USDT"
    var isLoading = false
    var error: String?

    private let api: APIStructureBFF

    init(client: NetworkClientProtocol) {
        self.api = APIStructureBFF(client: client)
    }

    func loadMatrix() async {
        isLoading = true
        defer { isLoading = false }
        do {
            matrixData = try await api.getMatrix(symbol: selectedSymbol)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refresh() async {
        await loadMatrix()
    }
}
