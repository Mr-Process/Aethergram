import SwiftUI
#if os(macOS)
import AppKit
#endif

public struct PhotoBrushStroke: Identifiable, Sendable {
    public let id: UUID
    public var points: [CGPoint]
    public let lineWidth: CGFloat

    public init(id: UUID = UUID(), points: [CGPoint], lineWidth: CGFloat) {
        self.id = id
        self.points = points
        self.lineWidth = lineWidth
    }
}

/// Controller for Materialgram's photo editor supporting 1pt minimum brush thickness,
/// text overlay, and 94% JPEG export (matching Materialgram's reduced JPEG compression).
@MainActor
public final class PhotoEditorController: ObservableObject {
    public static let materialgramJPEGQuality: CGFloat = 0.94
    public static let minimumBrushThickness: CGFloat = 1.0

    @Published public var brushThickness: CGFloat = 2.0
    @Published public var overlayText: String = ""
    @Published public var strokes: [PhotoBrushStroke] = []
    @Published public var currentPoints: [CGPoint] = []

    public init() {}

    public func commitCurrentStroke() {
        guard !currentPoints.isEmpty else { return }
        strokes.append(PhotoBrushStroke(points: currentPoints, lineWidth: max(Self.minimumBrushThickness, brushThickness)))
        currentPoints = []
    }

    public func clearAll() {
        strokes = []
        currentPoints = []
        overlayText = ""
    }

    #if os(macOS)
    public static func exportJPEG94(image: NSImage, destinationURL: URL) throws -> URL {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpegData = bitmap.representation(
                using: .jpeg,
                properties: [.compressionFactor: NSNumber(value: Double(materialgramJPEGQuality))]
              ) else {
            throw NSError(domain: "MaterialgramPhotoEditor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode 94% JPEG."])
        }
        try jpegData.write(to: destinationURL, options: .atomic)
        return destinationURL
    }
    #endif
}

public struct PhotoEditorView: View {
    @ObservedObject public var controller: PhotoEditorController
    public let sourceURL: URL
    public let palette: MD3ColorPalette
    public let onCancel: () -> Void
    public let onSendEdited: (URL) -> Void

    public init(
        controller: PhotoEditorController,
        sourceURL: URL,
        palette: MD3ColorPalette,
        onCancel: @escaping () -> Void,
        onSendEdited: @escaping (URL) -> Void
    ) {
        self.controller = controller
        self.sourceURL = sourceURL
        self.palette = palette
        self.onCancel = onCancel
        self.onSendEdited = onSendEdited
    }

    public var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Photo Editor (94% JPEG)")
                    .font(.mgFont(size: 15, weight: .bold))
                Spacer()
                Button("Clear") { controller.clearAll() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Send") {
                    #if os(macOS)
                    if let img = NSImage(contentsOf: sourceURL) {
                        let out = FileManager.default.temporaryDirectory
                            .appendingPathComponent("mg_photo_\(UUID().uuidString).jpg")
                        if let exported = try? PhotoEditorController.exportJPEG94(image: img, destinationURL: out) {
                            onSendEdited(exported)
                            return
                        }
                    }
                    #endif
                    onSendEdited(sourceURL)
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.primary)
                .controlSize(.small)
            }

            ZStack {
                #if os(macOS)
                if let img = NSImage(contentsOf: sourceURL) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                }
                #endif

                Canvas { ctx, _ in
                    for stroke in controller.strokes {
                        var path = Path()
                        if let first = stroke.points.first {
                            path.move(to: first)
                            for pt in stroke.points.dropFirst() { path.addLine(to: pt) }
                            ctx.stroke(path, with: .color(palette.primary), lineWidth: stroke.lineWidth)
                        }
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            controller.currentPoints.append(value.location)
                        }
                        .onEnded { _ in
                            controller.commitCurrentStroke()
                        }
                )

                if !controller.overlayText.isEmpty {
                    Text(controller.overlayText)
                        .font(.mgFont(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(minHeight: 300)
            .background(Color.black.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 14) {
                Text("Brush: \(String(format: "%.1f", controller.brushThickness))pt")
                    .font(.mgFont(size: 12))
                Slider(value: $controller.brushThickness, in: PhotoEditorController.minimumBrushThickness...16.0, step: 0.5)
                    .frame(width: 140)
                    .tint(palette.primary)
                TextField("Text overlay", text: $controller.overlayText)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 460)
        .background(palette.surface)
    }
}
