import SwiftUI

struct ScreenLayoutView: View {
    @EnvironmentObject var viewModel: SplitterViewModel
    @State private var draggingScreenId: UUID?
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geo in
            let bb = viewModel.screenManager.boundingBox
            if bb.width <= 0 || bb.height <= 0 {
                Text("No screens detected").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                canvas(geo: geo, bb: bb)
            }
        }
    }
    
    @ViewBuilder
    private func canvas(geo: GeometryProxy, bb: CGRect) -> some View {
        let pad: CGFloat = 24
        let scale = min((geo.size.width - pad * 2) / bb.width, (geo.size.height - pad * 2) / bb.height)
        let ox = (geo.size.width - bb.width * scale) / 2
        let oy = (geo.size.height - bb.height * scale) / 2
        
        ZStack(alignment: .topLeading) {
            ForEach(viewModel.screenManager.screens) { screen in
                let isDrag = draggingScreenId == screen.id
                let bx = (screen.originX - bb.minX) * scale + ox
                let by = (screen.originY - bb.minY) * scale + oy
                let w = screen.width * scale
                let h = screen.height * scale
                let px = bx + w / 2 + (isDrag ? dragOffset.width : 0)
                let py = by + h / 2 + (isDrag ? dragOffset.height : 0)
                let tile = viewModel.tiles.first { $0.screenId == screen.id }
                let sel = tile.map { viewModel.selectedTileId == $0.id } ?? false
                
                cell(screen: screen, tile: tile, sel: sel, isDrag: isDrag, w: w, h: h)
                    .position(x: px, y: py)
                    .zIndex(isDrag ? 100 : 0)
                    .gesture(drag(screen: screen, scale: scale))
                    .onTapGesture {
                        if let t = tile {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.selectedTileId = viewModel.selectedTileId == t.id ? nil : t.id
                            }
                        }
                    }
            }
        }
        .frame(width: geo.size.width, height: geo.size.height)
    }
    
    private func drag(screen: ScreenInfo, scale: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { v in draggingScreenId = screen.id; dragOffset = v.translation }
            .onEnded { v in
                var u = screen
                u.originX += v.translation.width / scale
                u.originY += v.translation.height / scale
                u = snap(u, all: viewModel.screenManager.screens)
                viewModel.screenManager.updateScreen(u)
                viewModel.regenerateTiles()
                draggingScreenId = nil; dragOffset = .zero
            }
    }
    
    @ViewBuilder
    private func cell(screen: ScreenInfo, tile: SplitTile?, sel: Bool, isDrag: Bool, w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            if let tile = tile {
                Image(nsImage: tile.image).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: w, height: h).clipped()
            } else {
                Rectangle().fill(Color(nsColor: .windowBackgroundColor))
            }
            VStack(spacing: 2) {
                Text(screen.name).font(.system(size: max(9, w * 0.04), weight: .semibold))
                Text(screen.resolution).font(.system(size: max(8, w * 0.03), design: .monospaced))
            }
            .foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 4)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
        }
        .frame(width: w, height: h)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(
            isDrag ? Color.orange : sel ? Color.accentColor : .primary.opacity(0.2),
            lineWidth: isDrag ? 3 : sel ? 2.5 : 1))
        .shadow(color: .black.opacity(isDrag ? 0.3 : 0.15), radius: isDrag ? 12 : 4, y: isDrag ? 6 : 2)
        .scaleEffect(isDrag ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isDrag)
    }
    
    private func snap(_ s: ScreenInfo, all: [ScreenInfo]) -> ScreenInfo {
        var r = s; let t: CGFloat = 50
        for o in all where o.id != s.id {
            let sR = r.originX + r.width, oR = o.originX + o.width
            let sB = r.originY + r.height, oB = o.originY + o.height
            // Horizontal
            if abs(sR - o.originX) < t { r.originX = o.originX - r.width }
            if abs(r.originX - oR) < t { r.originX = oR }
            if abs(r.originX - o.originX) < t { r.originX = o.originX }
            if abs(sR - oR) < t { r.originX = oR - r.width }
            // Vertical
            if abs(sB - o.originY) < t { r.originY = o.originY - r.height }
            if abs(r.originY - oB) < t { r.originY = oB }
            if abs(r.originY - o.originY) < t { r.originY = o.originY }
            if abs(sB - oB) < t { r.originY = oB - r.height }
            // Center
            let mcy = r.originY + r.height / 2, ocy = o.originY + o.height / 2
            if abs(mcy - ocy) < t { r.originY = ocy - r.height / 2 }
        }
        return r
    }
}
