import SwiftUI
import Combine

class ScreenManager: ObservableObject {
    @Published var screens: [ScreenInfo] = []
    
    var boundingBox: CGRect {
        guard !screens.isEmpty else { return .zero }
        return screens.reduce(screens[0].frame) { $0.union($1.frame) }
    }
    
    init() { detectScreens() }
    
    /// Detect screens. Layout (frame) is in POINTS so screens stay adjacent.
    /// width/height = point size for layout. backingScale stored for pixel export.
    func detectScreens() {
        let nsScreens = NSScreen.screens
        guard !nsScreens.isEmpty else { return }
        
        let allFrames = nsScreens.map(\.frame)
        let globalMinX = allFrames.map(\.minX).min() ?? 0
        let globalMaxY = allFrames.map(\.maxY).max() ?? 0
        
        var detected: [ScreenInfo] = []
        
        for (index, screen) in nsScreens.enumerated() {
            let f = screen.frame
            let b = screen.backingScaleFactor
            let normX = f.minX - globalMinX
            let normY = globalMaxY - f.maxY
            let isMain = (index == 0)
            let name = screen.localizedName + (isMain ? " ★" : "")
            
            // width/height in POINTS for layout (screens stay adjacent)
            detected.append(ScreenInfo(
                id: UUID(), name: name,
                originX: normX, originY: normY,
                width: f.width, height: f.height,
                isAutoDetected: true, nsScreenIndex: index, backingScale: b
            ))
            
            print("📺 [\(index)] \(name): layout=(\(Int(normX)),\(Int(normY))) \(Int(f.width))×\(Int(f.height))pt → \(Int(f.width*b))×\(Int(f.height*b))px backing=\(b)")
        }
        
        self.screens = detected
        let bb = boundingBox
        print("📐 BBox: \(Int(bb.width))×\(Int(bb.height)) pt")
    }
    
    func addVirtualScreen(width: CGFloat = 1920, height: CGFloat = 1080) {
        let maxX = screens.map { $0.originX + $0.width }.max() ?? 0
        screens.append(ScreenInfo(
            id: UUID(), name: "Virtual \(screens.count + 1)",
            originX: maxX + 10, originY: screens.first?.originY ?? 0,
            width: width, height: height,
            isAutoDetected: false, nsScreenIndex: nil, backingScale: 1.0
        ))
    }
    
    func removeScreen(id: UUID) { screens.removeAll { $0.id == id } }
    func updateScreen(_ updated: ScreenInfo) {
        if let idx = screens.firstIndex(where: { $0.id == updated.id }) { screens[idx] = updated }
    }
}
