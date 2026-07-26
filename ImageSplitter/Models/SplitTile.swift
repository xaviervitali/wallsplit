import SwiftUI

struct SplitTile: Identifiable {
    let id: UUID
    let screenId: UUID
    let screenName: String
    let image: NSImage
    let sourceRect: CGRect
    let screenRect: CGRect
    
    var resolution: String {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return "\(Int(screenRect.width))×\(Int(screenRect.height))"
        }
        return "\(cg.width)×\(cg.height)"
    }
}
