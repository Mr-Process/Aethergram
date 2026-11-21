import SwiftUI

public enum MD3CornerRadius {
    public static let none: CGFloat = 0
    public static let extraSmall: CGFloat = 4
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 12
    public static let large: CGFloat = 16
    public static let extraLarge: CGFloat = 28
    public static let full: CGFloat = 9999
}

/// Tailless MD3 message bubble shape matching Materialgram's
/// "Removed message bubble tails and reverted old paddings".
public struct MD3BubbleShape: Shape {
    public let isOutgoing: Bool
    public let baseRadius: CGFloat
    public let tailRadius: CGFloat

    public init(isOutgoing: Bool, baseRadius: CGFloat = 16, tailRadius: CGFloat? = nil) {
        self.isOutgoing = isOutgoing
        self.baseRadius = baseRadius
        self.tailRadius = tailRadius ?? baseRadius
    }

    public func path(in rect: CGRect) -> Path {
        let rTopLeft = baseRadius
        let rTopRight = baseRadius
        let rBottomLeft = isOutgoing ? baseRadius : tailRadius
        let rBottomRight = isOutgoing ? tailRadius : baseRadius

        var path = Path()
        
        let tl = CGPoint(x: rect.minX, y: rect.minY)
        let tr = CGPoint(x: rect.maxX, y: rect.minY)
        let br = CGPoint(x: rect.maxX, y: rect.maxY)
        let bl = CGPoint(x: rect.minX, y: rect.maxY)

        path.move(to: CGPoint(x: tl.x + rTopLeft, y: tl.y))
        path.addLine(to: CGPoint(x: tr.x - rTopRight, y: tr.y))
        path.addArc(center: CGPoint(x: tr.x - rTopRight, y: tr.y + rTopRight),
                    radius: rTopRight, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)

        path.addLine(to: CGPoint(x: br.x, y: br.y - rBottomRight))
        path.addArc(center: CGPoint(x: br.x - rBottomRight, y: br.y - rBottomRight),
                    radius: rBottomRight, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)

        path.addLine(to: CGPoint(x: bl.x + rBottomLeft, y: bl.y))
        path.addArc(center: CGPoint(x: bl.x + rBottomLeft, y: bl.y - rBottomLeft),
                    radius: rBottomLeft, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)

        path.addLine(to: CGPoint(x: tl.x, y: tl.y + rTopLeft))
        path.addArc(center: CGPoint(x: tl.x + rTopLeft, y: tl.y + rTopLeft),
                    radius: rTopLeft, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)

        path.closeSubpath()
        return path
    }
}

public struct MD3Elevation: ViewModifier {
    public let level: Int

    public func body(content: Content) -> some View {
        switch level {
        case 1:
            content.shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
        case 2:
            content.shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
        case 3:
            content.shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 4)
        default:
            content
        }
    }
}

public extension View {
    func md3Elevation(_ level: Int) -> some View {
        modifier(MD3Elevation(level: level))
    }
}
