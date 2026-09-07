import SwiftUI
import UniformTypeIdentifiers

struct TileDetailView: View {
    let tile: SplitTile
    @EnvironmentObject var viewModel: SplitterViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Selected Tile", systemImage: "rectangle.on.rectangle").font(.headline)
                Spacer()
                Button { viewModel.selectedTileId = nil } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }.buttonStyle(.borderless)
            }
            Divider()
            Image(nsImage: tile.image).resizable().aspectRatio(contentMode: .fit).frame(maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.primary.opacity(0.1), lineWidth: 1))
            
            VStack(alignment: .leading, spacing: 6) {
                row("display", "Screen", tile.screenName)
                row("arrow.up.left.and.arrow.down.right", "Output", tile.resolution)
            }
            Spacer()
            Button { exportSingle() } label: {
                Label("Export This Tile", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).controlSize(.regular)
        }
        .padding(16).frame(width: 240).background(Color(nsColor: .controlBackgroundColor))
    }
    
    private func row(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption2).foregroundStyle(.secondary).frame(width: 14)
            Text("\(label):").font(.caption).foregroundStyle(.secondary)
            Text(value).font(.caption.monospaced()).lineLimit(1)
        }
    }
    
    private func exportSingle() {
        let panel = NSSavePanel()
        let safe = tile.screenName.replacingOccurrences(of: " ", with: "_")
        panel.nameFieldStringValue = "\(viewModel.sourceImageName.isEmpty ? "wallpaper" : viewModel.sourceImageName)_\(safe).png"
        panel.allowedContentTypes = [.png]
        if panel.runModal() == .OK, let url = panel.url {
            guard let cg = tile.image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
            let rep = NSBitmapImageRep(cgImage: cg)
            if let data = rep.representation(using: .png, properties: [:]) {
                try? data.write(to: url, options: .atomic)
                NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
            }
        }
    }
}
