import SwiftUI

struct ToolbarView: View {
    @EnvironmentObject var viewModel: SplitterViewModel
    
    var body: some View {
        HStack(spacing: 14) {
            if viewModel.sourceImage != nil {
                HStack(spacing: 5) {
                    Image(systemName: "photo").font(.caption).foregroundStyle(.secondary)
                    Text(viewModel.imageDimensions).font(.caption.monospaced()).foregroundStyle(.secondary)
                }
                Divider().frame(height: 16)
            }
            
            // Fit mode
            HStack(spacing: 5) {
                Text("Fit:").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $viewModel.fitMode) {
                    ForEach(WallSplitService.FitMode.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.menu).frame(width: 160)
                .onChange(of: viewModel.fitMode) { viewModel.regenerateAndApply() }
            }

            // Anchor point (only for fill/fit)
            if viewModel.fitMode != .stretch && viewModel.sourceImage != nil {
                AnchorPicker(anchorX: $viewModel.anchorX, anchorY: $viewModel.anchorY)
                    .onChange(of: viewModel.anchorX) { viewModel.regenerateAndApply() }
                    .onChange(of: viewModel.anchorY) { viewModel.regenerateAndApply() }

                Button {
                    viewModel.smartCrop()
                } label: {
                    if viewModel.isSmartCropping {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.small)
                            Text("Analyzing…").font(.callout)
                        }
                    } else {
                        Label("Smart Crop", systemImage: "sparkles.rectangle.stack").font(.callout)
                    }
                }
                .buttonStyle(.bordered).controlSize(.small)
                .disabled(viewModel.isSmartCropping)
                .help("Auto-detect faces / subjects and set the best crop position")
            }
            
            Spacer()
            
            if viewModel.sourceImage != nil {
                Button { viewModel.openSavePresetSheet() } label: {
                    Label("Save Preset", systemImage: "star").font(.callout)
                }.buttonStyle(.bordered).controlSize(.small)

                Button { viewModel.clearImage() } label: {
                    Label("Clear", systemImage: "xmark.circle").font(.callout)
                }.buttonStyle(.bordered).controlSize(.small)
            }

            Button { viewModel.exportTiles() } label: {
                Label("Export", systemImage: "square.and.arrow.down").font(.callout)
            }.buttonStyle(.bordered).controlSize(.small).disabled(viewModel.tiles.isEmpty)

            Button { viewModel.showPreviewOverlay = true } label: {
                Label("Preview", systemImage: "eye").font(.callout)
            }.buttonStyle(.bordered).controlSize(.small).disabled(viewModel.tiles.isEmpty)

            Button { viewModel.applyWallpapers() } label: {
                Label("Apply Wallpapers", systemImage: "desktopcomputer").font(.callout.weight(.semibold))
            }.buttonStyle(.borderedProminent).controlSize(.small).disabled(viewModel.tiles.isEmpty)
        }
        .padding(.horizontal, 16).padding(.vertical, 10).background(.bar)
    }
}

// MARK: - Anchor Picker (3×3 grid)

struct AnchorPicker: View {
    @Binding var anchorX: CGFloat
    @Binding var anchorY: CGFloat
    
    private let positions: [(String, CGFloat, CGFloat)] = [
        ("↖", 0.0, 0.0), ("↑", 0.5, 0.0), ("↗", 1.0, 0.0),
        ("←", 0.0, 0.5), ("·", 0.5, 0.5), ("→", 1.0, 0.5),
        ("↙", 0.0, 1.0), ("↓", 0.5, 1.0), ("↘", 1.0, 1.0),
    ]
    
    var body: some View {
        HStack(spacing: 4) {
            Text("Anchor:").font(.caption).foregroundStyle(.secondary)
            
            VStack(spacing: 1) {
                ForEach(0..<3) { row in
                    HStack(spacing: 1) {
                        ForEach(0..<3) { col in
                            let idx = row * 3 + col
                            let (_, ax, ay) = positions[idx]
                            let isSelected = abs(anchorX - ax) < 0.01 && abs(anchorY - ay) < 0.01
                            
                            Rectangle()
                                .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.15))
                                .frame(width: 10, height: 10)
                                .cornerRadius(2)
                                .onTapGesture {
                                    anchorX = ax
                                    anchorY = ay
                                }
                        }
                    }
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 4).fill(.quaternary.opacity(0.5)))
            .help("Click to choose which part of the image to keep")
        }
    }
}
