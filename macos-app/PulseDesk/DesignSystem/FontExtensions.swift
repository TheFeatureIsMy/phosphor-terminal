// FontExtensions.swift — ProofAlpha 字体便捷扩展

import SwiftUI

extension Font {
    /// 等宽数字字体，用于金融数据对齐
    static func tabular(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced).monospacedDigit()
    }

    /// 展示字体，用于标题
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
