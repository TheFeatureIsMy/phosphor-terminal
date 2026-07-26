// BackgroundLayersView.swift — Protocol 浅色背景(冷白纯色,无扫描线/mesh/霓虹)

import SwiftUI

struct BackgroundLayersView: View {
    var body: some View {
        // Protocol §③: 浅色大留白冷白底,零渐变/扫描线/mesh。
        Color(hex: "F6F7FB")
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}
