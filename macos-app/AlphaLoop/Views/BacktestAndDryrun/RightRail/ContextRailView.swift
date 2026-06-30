// ContextRailView.swift — Right rail: strategy meta + risk + promotion (always visible).

import SwiftUI

struct ContextRailView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: PulseSpacing.lg) {
                StrategyMetaPanel()
                RiskWarningsPanel()
                PromotionGatePanel()
            }
            .padding(PulseSpacing.lg)
        }
    }
}
