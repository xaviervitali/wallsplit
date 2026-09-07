import AppKit

class WallSplitService {
    
    enum FitMode: String, CaseIterable, Identifiable {
        case fill = "Fill (crop edges)"
        case fit = "Fit (letterbox)"
        case stretch = "Stretch"
        var id: String { rawValue }
    }
    
    /// Split image across screens.
    /// anchorX/anchorY: 0.0 = top-left, 0.5 = center, 1.0 = bottom-right
    static func split(
        image: NSImage,
        screens: [ScreenInfo],
        boundingBox: CGRect,
        fitMode: FitMode = .fill,
        anchorX: CGFloat = 0.5,
        anchorY: CGFloat = 0.5
    ) -> [SplitTile] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              !screens.isEmpty, boundingBox.width > 0, boundingBox.height > 0
        else { return [] }
        
        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)
        
        let (sx, sy, ox, oy) = computeMapping(
            imageWidth: imgW, imageHeight: imgH,
            targetWidth: boundingBox.width, targetHeight: boundingBox.height,
            mode: fitMode, anchorX: anchorX, anchorY: anchorY
        )
        
        var tiles: [SplitTile] = []
        
        for screen in screens {
            let relX = screen.originX - boundingBox.minX
            let relY = screen.originY - boundingBox.minY
            
            let imgX = relX * sx + ox
            let imgY = relY * sy + oy
            let imgCropW = screen.width * sx
            let imgCropH = screen.height * sy
            
            let cropRect = CGRect(x: imgX, y: imgY, width: imgCropW, height: imgCropH)
                .intersection(CGRect(x: 0, y: 0, width: imgW, height: imgH))
            
            guard cropRect.width > 0, cropRect.height > 0 else { continue }
            
            if let cropped = cgImage.cropping(to: cropRect) {
                let exportW = Int(screen.width * screen.backingScale)
                let exportH = Int(screen.height * screen.backingScale)
                let finalImage = resizeImage(cgImage: cropped, targetWidth: exportW, targetHeight: exportH)
                
                tiles.append(SplitTile(
                    id: UUID(), screenId: screen.id, screenName: screen.name,
                    image: finalImage, sourceRect: cropRect, screenRect: screen.frame
                ))
            }
        }
        
        return tiles
    }
    
    /// anchorX/anchorY: 0.0 → offset pulls to start, 0.5 → center, 1.0 → offset pulls to end
    private static func computeMapping(
        imageWidth: CGFloat, imageHeight: CGFloat,
        targetWidth: CGFloat, targetHeight: CGFloat,
        mode: FitMode,
        anchorX: CGFloat = 0.5,
        anchorY: CGFloat = 0.5
    ) -> (sx: CGFloat, sy: CGFloat, ox: CGFloat, oy: CGFloat) {
        switch mode {
        case .stretch:
            return (imageWidth / targetWidth, imageHeight / targetHeight, 0, 0)
        case .fill:
            let s = max(imageWidth / targetWidth, imageHeight / targetHeight)
            let excessX = imageWidth - targetWidth * s
            let excessY = imageHeight - targetHeight * s
            return (s, s, excessX * anchorX, excessY * anchorY)
        case .fit:
            let s = min(imageWidth / targetWidth, imageHeight / targetHeight)
            let excessX = imageWidth - targetWidth * s
            let excessY = imageHeight - targetHeight * s
            return (s, s, excessX * anchorX, excessY * anchorY)
        }
    }
    
    private static func resizeImage(cgImage: CGImage, targetWidth: Int, targetHeight: Int) -> NSImage {
        guard let ctx = CGContext(
            data: nil, width: targetWidth, height: targetHeight,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return NSImage(cgImage: cgImage, size: NSSize(width: targetWidth, height: targetHeight))
        }
        ctx.interpolationQuality = .high
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        if let resized = ctx.makeImage() {
            return NSImage(cgImage: resized, size: NSSize(width: targetWidth, height: targetHeight))
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: targetWidth, height: targetHeight))
    }
    
    static func exportTiles(_ tiles: [SplitTile], to dir: URL, format: String = "png", baseName: String = "wallpaper") -> [URL] {
        var saved: [URL] = []
        for tile in tiles {
            let ext = format == "jpeg" ? "jpg" : "png"
            let safe = tile.screenName.replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "/", with: "-")
            let url = dir.appendingPathComponent("\(baseName)_\(safe).\(ext)")
            guard let cg = tile.image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
            let rep = NSBitmapImageRep(cgImage: cg)
            let ft: NSBitmapImageRep.FileType = format == "jpeg" ? .jpeg : .png
            let props: [NSBitmapImageRep.PropertyKey: Any] = format == "jpeg" ? [.compressionFactor: 0.95] : [:]
            if let data = rep.representation(using: ft, properties: props) {
                try? data.write(to: url, options: .atomic)
                saved.append(url)
            }
        }
        return saved
    }
}
