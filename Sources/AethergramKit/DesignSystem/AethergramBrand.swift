import SwiftUI

/// Centralized brand identity and copy guidelines for Aethergram
/// (our macOS Liquid Glass + Material 3 rebrand of Materialgram).
public enum AethergramBrand {
    public static let appName = "Aethergram"
    public static let tagline = "Liquid Glass Telegram Client for macOS"
    public static let bundleIdentifier = "app.aethergram.macos"
    public static let version = "1.10"
    public static let buildNumber = "110"

    /// Preserves the existing Application Support/Materialgram data folder so live TDLib sessions
    /// (`tdlib_db`), custom wallpapers, and bookmarks remain 100% intact across the rebrand.
    public static let legacyDataDirectoryName = "Materialgram"
}

/// Vector brand mark for Aethergram: a faceted indigo-cyan-violet squircle with a luminous
/// glass paper-plane crest and constellation spark.
public struct AethergramLogoView: View {
    public let size: CGFloat
    public let cornerRadiusRatio: CGFloat

    public init(size: CGFloat = 28, cornerRadiusRatio: CGFloat = 0.26) {
        self.size = size
        self.cornerRadiusRatio = cornerRadiusRatio
    }

    public var body: some View {
        let radius = size * cornerRadiusRatio
        ZStack {
            // Deep Aether Squircle Base
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.11, blue: 0.26), // Deep Midnight Indigo
                            Color(red: 0.19, green: 0.23, blue: 0.58), // Electric Cobalt
                            Color(red: 0.06, green: 0.56, blue: 0.82)  // Luminous Aether Cyan
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Subtle Inner Aurora Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.48, green: 0.86, blue: 1.00).opacity(0.45),
                            Color.clear
                        ],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: size * 0.75
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))

            // Faceted Paper-Plane Crest
            Canvas { context, canvasSize in
                let w = canvasSize.width
                let h = canvasSize.height

                // Outer main wing polygon
                var wing = Path()
                wing.move(to: CGPoint(x: w * 0.18, y: h * 0.51))
                wing.addLine(to: CGPoint(x: w * 0.82, y: h * 0.22))
                wing.addLine(to: CGPoint(x: w * 0.67, y: h * 0.79))
                wing.addLine(to: CGPoint(x: w * 0.47, y: h * 0.61))
                wing.closeSubpath()

                context.fill(
                    wing,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color.white,
                            Color(red: 0.82, green: 0.95, blue: 1.0)
                        ]),
                        startPoint: CGPoint(x: w * 0.2, y: h * 0.2),
                        endPoint: CGPoint(x: w * 0.8, y: h * 0.8)
                    )
                )

                // Inner fold shadow facet
                var fold = Path()
                fold.move(to: CGPoint(x: w * 0.42, y: h * 0.56))
                fold.addLine(to: CGPoint(x: w * 0.82, y: h * 0.22))
                fold.addLine(to: CGPoint(x: w * 0.47, y: h * 0.61))
                fold.addLine(to: CGPoint(x: w * 0.41, y: h * 0.75))
                fold.closeSubpath()

                context.fill(
                    fold,
                    with: .color(Color(red: 0.36, green: 0.76, blue: 0.98).opacity(0.85))
                )

                // Four-point Aether spark at top-left
                let cx = w * 0.27
                let cy = h * 0.27
                let rOuter = w * 0.075
                let rInner = w * 0.024
                var spark = Path()
                for i in 0..<8 {
                    let angle = Double(i) * (.pi / 4.0) - (.pi / 2.0)
                    let r = (i % 2 == 0) ? rOuter : rInner
                    let pt = CGPoint(
                        x: cx + CGFloat(cos(angle)) * r,
                        y: cy + CGFloat(sin(angle)) * r
                    )
                    if i == 0 {
                        spark.move(to: pt)
                    } else {
                        spark.addLine(to: pt)
                    }
                }
                spark.closeSubpath()
                context.fill(spark, with: .color(Color(red: 0.70, green: 0.94, blue: 1.0)))
            }

            // Specular Liquid Glass Rim
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            Color.white.opacity(0.12),
                            Color(red: 0.35, green: 0.85, blue: 1.0).opacity(0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(1, size * 0.035)
                )
        }
        .frame(width: size, height: size)
        .shadow(color: Color(red: 0.07, green: 0.42, blue: 0.78).opacity(0.28), radius: size * 0.14, x: 0, y: size * 0.06)
    }
}
