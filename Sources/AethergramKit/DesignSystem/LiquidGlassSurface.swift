import SwiftUI

/// Wraps grouped glass elements in Apple's macOS 26+ `GlassEffectContainer`
/// so adjacent glass pills, buttons, and cards morph and blend cohesively,
/// with a transparent fallback for macOS 14–25.
public struct LiquidGlassContainer<Content: View>: View {
    public let spacing: CGFloat
    public let content: () -> Content

    public init(spacing: CGFloat = 10, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}

public extension View {
    /// Applies macOS 26+ Liquid Glass (`Glass.regular`) to a rounded rectangle surface
    /// after layout and appearance modifiers, with `.ultraThinMaterial` fallback on earlier macOS.
    @ViewBuilder
    func mgGlassCard(
        cornerRadius: CGFloat = 14,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26, *) {
            if let tint {
                if interactive {
                    self.glassEffect(.regular.tint(tint).interactive(), in: shape)
                } else {
                    self.glassEffect(.regular.tint(tint), in: shape)
                }
            } else {
                if interactive {
                    self.glassEffect(.regular.interactive(), in: shape)
                } else {
                    self.glassEffect(.regular, in: shape)
                }
            }
        } else {
            self
                .background {
                    if let tint {
                        shape.fill(tint)
                    }
                }
                .background(.ultraThinMaterial, in: shape)
                .overlay(
                    shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                )
        }
    }

    /// Applies macOS 26+ Liquid Glass (`Glass.regular`) to a capsule pill
    /// after layout and appearance modifiers, with `.ultraThinMaterial` fallback on earlier macOS.
    @ViewBuilder
    func mgGlassCapsule(
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        if #available(macOS 26, *) {
            if let tint {
                if interactive {
                    self.glassEffect(.regular.tint(tint).interactive(), in: .capsule)
                } else {
                    self.glassEffect(.regular.tint(tint), in: .capsule)
                }
            } else {
                if interactive {
                    self.glassEffect(.regular.interactive(), in: .capsule)
                } else {
                    self.glassEffect(.regular, in: .capsule)
                }
            }
        } else {
            self
                .background {
                    if let tint {
                        Capsule().fill(tint)
                    }
                }
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
                )
        }
    }

    /// Applies macOS 26+ Liquid Glass (`Glass.regular`) to a circular icon button or badge
    /// after layout and appearance modifiers, with `.ultraThinMaterial` fallback on earlier macOS.
    @ViewBuilder
    func mgGlassCircle(
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        if #available(macOS 26, *) {
            if let tint {
                if interactive {
                    self.glassEffect(.regular.tint(tint).interactive(), in: .circle)
                } else {
                    self.glassEffect(.regular.tint(tint), in: .circle)
                }
            } else {
                if interactive {
                    self.glassEffect(.regular.interactive(), in: .circle)
                } else {
                    self.glassEffect(.regular, in: .circle)
                }
            }
        } else {
            self
                .background {
                    if let tint {
                        Circle().fill(tint)
                    }
                }
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
                )
        }
    }
}
