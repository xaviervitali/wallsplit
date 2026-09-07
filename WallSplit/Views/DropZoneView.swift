import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @EnvironmentObject var viewModel: SplitterViewModel
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 2.5, dash: [12, 6]))
                .foregroundColor(viewModel.isDragging ? .accentColor : .secondary.opacity(0.35))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(viewModel.isDragging ? Color.accentColor.opacity(0.06) : Color(nsColor: .controlBackgroundColor).opacity(0.3))
                )
            VStack(spacing: 14) {
                Image(systemName: "photo.on.rectangle.angled").font(.system(size: 44, weight: .ultraLight)).foregroundStyle(.secondary)
                VStack(spacing: 5) {
                    Text("Drop your image here").font(.title3.weight(.medium))
                    Text("or click to browse").font(.callout).foregroundStyle(.secondary)
                }
                Text("PNG · JPEG · TIFF · BMP").font(.caption2.weight(.medium)).foregroundStyle(.tertiary)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Capsule().fill(.quaternary.opacity(0.8)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { viewModel.openFilePicker() }
        .onDrop(of: [.image, .fileURL], isTargeted: $viewModel.isDragging) { viewModel.handleDrop(providers: $0) }
    }
}
