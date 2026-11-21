import SwiftUI

public enum MD3PalettePreset: String, CaseIterable, Identifiable, Sendable {
    case classic = "Material Classic"
    case amber = "Amber Sunrise"
    case emerald = "Emerald Mint"
    case sapphire = "Sapphire Indigo"
    case amethyst = "Amethyst Berry"
    case amoled = "AMOLED Dark"

    public var id: String { rawValue }

    public var accentColor: Color {
        switch self {
        case .classic:  return Color(red: 0.13, green: 0.59, blue: 0.95) // #2196F3
        case .amber:    return Color(red: 1.00, green: 0.60, blue: 0.00) // #FF9800
        case .emerald:  return Color(red: 0.00, green: 0.75, blue: 0.52) // #00BF84
        case .sapphire: return Color(red: 0.25, green: 0.35, blue: 0.95) // #3F59F2
        case .amethyst: return Color(red: 0.62, green: 0.30, blue: 0.88) // #9C27B0
        case .amoled:   return Color(red: 0.40, green: 0.70, blue: 1.00) // #66B2FF
        }
    }
}

public struct MD3ColorPalette: Sendable {
    public let primary: Color
    public let onPrimary: Color
    public let primaryContainer: Color
    public let onPrimaryContainer: Color

    public let secondary: Color
    public let onSecondary: Color
    public let secondaryContainer: Color
    public let onSecondaryContainer: Color

    public let tertiary: Color
    public let onTertiary: Color

    public let surface: Color
    public let onSurface: Color
    public let surfaceVariant: Color
    public let onSurfaceVariant: Color

    public let surfaceContainer: Color
    public let surfaceContainerHigh: Color
    public let surfaceContainerLow: Color

    public let outline: Color
    public let outlineVariant: Color

    public let bubbleOutgoing: Color
    public let onBubbleOutgoing: Color
    public let bubbleIncoming: Color
    public let onBubbleIncoming: Color

    public static func forPreset(_ preset: MD3PalettePreset, isDark: Bool) -> MD3ColorPalette {
        if preset == .amoled {
            return amoledPalette()
        }
        return isDark ? darkPalette(preset) : lightPalette(preset)
    }

    private static func lightPalette(_ preset: MD3PalettePreset) -> MD3ColorPalette {
        let p = preset.accentColor
        return MD3ColorPalette(
            primary: p,
            onPrimary: .white,
            primaryContainer: p.opacity(0.18),
            onPrimaryContainer: p.opacity(0.95),
            secondary: Color(red: 0.35, green: 0.40, blue: 0.45),
            onSecondary: .white,
            secondaryContainer: Color(red: 0.88, green: 0.92, blue: 0.96),
            onSecondaryContainer: Color(red: 0.10, green: 0.15, blue: 0.20),
            tertiary: Color(red: 0.55, green: 0.30, blue: 0.65),
            onTertiary: .white,
            surface: Color(red: 0.98, green: 0.98, blue: 0.99),
            onSurface: Color(red: 0.11, green: 0.12, blue: 0.13),
            surfaceVariant: Color(red: 0.91, green: 0.93, blue: 0.95),
            onSurfaceVariant: Color(red: 0.30, green: 0.32, blue: 0.35),
            surfaceContainer: Color(red: 0.95, green: 0.96, blue: 0.97),
            surfaceContainerHigh: Color(red: 0.93, green: 0.94, blue: 0.96),
            surfaceContainerLow: Color(red: 0.97, green: 0.98, blue: 0.99),
            outline: Color(red: 0.75, green: 0.77, blue: 0.80),
            outlineVariant: Color(red: 0.85, green: 0.87, blue: 0.90),
            bubbleOutgoing: p.opacity(0.20),
            onBubbleOutgoing: Color(red: 0.08, green: 0.12, blue: 0.18),
            bubbleIncoming: Color(red: 0.93, green: 0.94, blue: 0.96),
            onBubbleIncoming: Color(red: 0.11, green: 0.12, blue: 0.13)
        )
    }

    private static func darkPalette(_ preset: MD3PalettePreset) -> MD3ColorPalette {
        let p = preset.accentColor
        return MD3ColorPalette(
            primary: p,
            onPrimary: Color(red: 0.05, green: 0.05, blue: 0.08),
            primaryContainer: p.opacity(0.30),
            onPrimaryContainer: p.opacity(0.95),
            secondary: Color(red: 0.75, green: 0.80, blue: 0.85),
            onSecondary: Color(red: 0.12, green: 0.15, blue: 0.20),
            secondaryContainer: Color(red: 0.22, green: 0.26, blue: 0.32),
            onSecondaryContainer: Color(red: 0.88, green: 0.92, blue: 0.96),
            tertiary: Color(red: 0.80, green: 0.60, blue: 0.90),
            onTertiary: Color(red: 0.20, green: 0.10, blue: 0.25),
            surface: Color(red: 0.11, green: 0.12, blue: 0.14),
            onSurface: Color(red: 0.92, green: 0.93, blue: 0.95),
            surfaceVariant: Color(red: 0.17, green: 0.19, blue: 0.22),
            onSurfaceVariant: Color(red: 0.75, green: 0.77, blue: 0.80),
            surfaceContainer: Color(red: 0.14, green: 0.15, blue: 0.18),
            surfaceContainerHigh: Color(red: 0.18, green: 0.20, blue: 0.23),
            surfaceContainerLow: Color(red: 0.09, green: 0.10, blue: 0.12),
            outline: Color(red: 0.35, green: 0.38, blue: 0.42),
            outlineVariant: Color(red: 0.24, green: 0.26, blue: 0.30),
            bubbleOutgoing: p.opacity(0.28),
            onBubbleOutgoing: Color(red: 0.95, green: 0.96, blue: 0.98),
            bubbleIncoming: Color(red: 0.18, green: 0.19, blue: 0.23),
            onBubbleIncoming: Color(red: 0.92, green: 0.93, blue: 0.95)
        )
    }

    private static func amoledPalette() -> MD3ColorPalette {
        let p = MD3PalettePreset.amoled.accentColor
        return MD3ColorPalette(
            primary: p,
            onPrimary: .black,
            primaryContainer: Color(red: 0.08, green: 0.20, blue: 0.35),
            onPrimaryContainer: p,
            secondary: Color(red: 0.70, green: 0.80, blue: 0.90),
            onSecondary: .black,
            secondaryContainer: Color(red: 0.10, green: 0.14, blue: 0.18),
            onSecondaryContainer: Color(red: 0.85, green: 0.90, blue: 0.95),
            tertiary: Color(red: 0.75, green: 0.50, blue: 0.85),
            onTertiary: .black,
            surface: .black,
            onSurface: Color(red: 0.95, green: 0.95, blue: 0.96),
            surfaceVariant: Color(red: 0.08, green: 0.08, blue: 0.09),
            onSurfaceVariant: Color(red: 0.75, green: 0.77, blue: 0.80),
            surfaceContainer: Color(red: 0.05, green: 0.05, blue: 0.06),
            surfaceContainerHigh: Color(red: 0.09, green: 0.09, blue: 0.11),
            surfaceContainerLow: .black,
            outline: Color(red: 0.25, green: 0.27, blue: 0.30),
            outlineVariant: Color(red: 0.16, green: 0.18, blue: 0.20),
            bubbleOutgoing: Color(red: 0.10, green: 0.26, blue: 0.42),
            onBubbleOutgoing: Color(red: 0.95, green: 0.96, blue: 0.98),
            bubbleIncoming: Color(red: 0.10, green: 0.10, blue: 0.12),
            onBubbleIncoming: Color(red: 0.92, green: 0.93, blue: 0.95)
        )
    }
}
