import SwiftUI

public struct HoverScaleButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

public struct MD3FloatingActionButton: View {
    public let icon: String
    public let label: String?
    public let color: Color
    public let onColor: Color
    public let action: () -> Void

    public init(
        icon: String,
        label: String? = nil,
        color: Color,
        onColor: Color = .white,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.color = color
        self.onColor = onColor
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                if let label = label {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .foregroundColor(onColor)
            .padding(.horizontal, label == nil ? 14 : 20)
            .padding(.vertical, 14)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .md3Elevation(2)
        }
        .buttonStyle(HoverScaleButtonStyle())
    }
}

public struct MD3Badge: View {
    public let count: Int
    public let isMuted: Bool
    public let color: Color
    public let onColor: Color

    public init(count: Int, isMuted: Bool = false, color: Color, onColor: Color = .white) {
        self.count = count
        self.isMuted = isMuted
        self.color = isMuted ? Color.gray.opacity(0.4) : color
        self.onColor = onColor
    }

    public var body: some View {
        if count > 0 {
            Text(count > 999 ? "999+" : "\(count)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isMuted ? .secondary : onColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color)
                .clipShape(Capsule())
        }
    }
}

public struct MD3ReactionChip: View {
    public let emoji: String
    public let count: Int
    public let isSelected: Bool
    public let primaryColor: Color
    public let action: () -> Void

    public init(
        emoji: String,
        count: Int,
        isSelected: Bool,
        primaryColor: Color,
        action: @escaping () -> Void
    ) {
        self.emoji = emoji
        self.count = count
        self.isSelected = isSelected
        self.primaryColor = primaryColor
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(emoji)
                    .font(.system(size: 12))
                if count > 1 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isSelected ? primaryColor : .secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isSelected ? primaryColor.opacity(0.18) : Color.primary.opacity(0.06))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? primaryColor.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
