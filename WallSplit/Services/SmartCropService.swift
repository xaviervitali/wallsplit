import Vision
import AppKit

/// Uses Vision face detection + attention saliency to suggest the best anchorX/Y
/// for cropping a source image across a multi-screen canvas.
struct SmartCropService {

    struct Result {
        let anchorX: CGFloat
        let anchorY: CGFloat
        /// "faces" | "saliency" | nil (nothing found)
        let source: String
    }

    /// Returns the optimal anchor, or nil if no subjects were detected.
    static func suggestAnchor(
        for image: NSImage,
        canvasSize: CGSize,
        fitMode: WallSplitService.FitMode
    ) async -> Result? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              canvasSize.width > 0, canvasSize.height > 0
        else { return nil }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let faceRequest     = VNDetectFaceRectanglesRequest()
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()

        try? handler.perform([faceRequest, saliencyRequest])

        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)

        // --- 1. Face detection (highest priority) ---
        if let faces = faceRequest.results, !faces.isEmpty {
            if let centroid = weightedCentroid(of: faces.map(\.boundingBox)) {
                let anchor = mapToAnchor(
                    centroid: centroid,
                    imageSize: CGSize(width: imgW, height: imgH),
                    canvasSize: canvasSize,
                    fitMode: fitMode
                )
                return Result(anchorX: anchor.x, anchorY: anchor.y, source: "faces")
            }
        }

        // --- 2. Attention-based saliency fallback ---
        if let salientObjects = (saliencyRequest.results?.first as? VNSaliencyImageObservation)?.salientObjects,
           !salientObjects.isEmpty {
            if let centroid = weightedCentroid(of: salientObjects.map(\.boundingBox)) {
                let anchor = mapToAnchor(
                    centroid: centroid,
                    imageSize: CGSize(width: imgW, height: imgH),
                    canvasSize: canvasSize,
                    fitMode: fitMode
                )
                return Result(anchorX: anchor.x, anchorY: anchor.y, source: "saliency")
            }
        }

        return nil
    }

    // MARK: - Helpers

    /// Vision bounding boxes: origin = bottom-left, normalized.
    /// Returns centroid in top-left normalized coords, weighted by bounding-box area.
    private static func weightedCentroid(of boxes: [CGRect]) -> CGPoint? {
        var totalArea: CGFloat = 0
        var wx: CGFloat = 0
        var wy: CGFloat = 0
        for bb in boxes {
            let area = bb.width * bb.height
            wx += bb.midX * area
            wy += (1.0 - bb.midY) * area   // flip Y: Vision = bottom-left → top-left
            totalArea += area
        }
        guard totalArea > 0 else { return nil }
        return CGPoint(x: wx / totalArea, y: wy / totalArea)
    }

    /// Maps a content centroid (normalized, top-left origin) to (anchorX, anchorY)
    /// such that the crop window is centered on that point.
    ///
    /// Derived from `computeMapping` in WallSplitService:
    ///   ox = excessX * anchorX,  cropWindow = [ox, ox + canW*s]
    ///   → center at cx*imgW  ↔  anchorX = (cx*imgW - canW*s/2) / excessX
    private static func mapToAnchor(
        centroid: CGPoint,
        imageSize: CGSize,
        canvasSize: CGSize,
        fitMode: WallSplitService.FitMode
    ) -> CGPoint {
        let imgW = imageSize.width, imgH = imageSize.height
        let canW = canvasSize.width, canH = canvasSize.height

        let s: CGFloat
        switch fitMode {
        case .fill:    s = max(imgW / canW, imgH / canH)
        case .fit:     s = min(imgW / canW, imgH / canH)
        case .stretch: return CGPoint(x: 0.5, y: 0.5)
        }

        let excessX = imgW - canW * s
        let excessY = imgH - canH * s

        let ax: CGFloat = excessX > 1
            ? ((centroid.x * imgW - (canW * s) / 2) / excessX).clamped(to: 0...1)
            : 0.5
        let ay: CGFloat = excessY > 1
            ? ((centroid.y * imgH - (canH * s) / 2) / excessY).clamped(to: 0...1)
            : 0.5

        return CGPoint(x: ax, y: ay)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
