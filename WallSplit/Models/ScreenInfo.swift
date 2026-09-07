import SwiftUI

/// Layout in POINTS (positions + sizes). backingScale gives native pixel resolution.
struct ScreenInfo: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var originX: CGFloat
    var originY: CGFloat
    var width: CGFloat       // points
    var height: CGFloat      // points
    var isAutoDetected: Bool
    var nsScreenIndex: Int?
    var backingScale: CGFloat  // 1.0 or 2.0

    var frame: CGRect { CGRect(x: originX, y: originY, width: width, height: height) }
    
    /// Native pixel resolution for display
    var pixelWidth: Int { Int(width * backingScale) }
    var pixelHeight: Int { Int(height * backingScale) }
    
    var resolution: String { "\(pixelWidth)×\(pixelHeight)" }
}
