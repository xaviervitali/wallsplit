import SwiftUI

struct ScreenListView: View {
    @EnvironmentObject var viewModel: SplitterViewModel
    @State private var editingId: UUID?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Displays", systemImage: "display.2").font(.headline)
                Spacer()
                Button { viewModel.screenManager.detectScreens(); viewModel.regenerateTiles() } label: {
                    Image(systemName: "arrow.clockwise").font(.caption)
                }.buttonStyle(.borderless).help("Re-detect displays")
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(viewModel.screenManager.screens) { screen in
                        ScreenRow(screen: screen, isEditing: editingId == screen.id,
                                  onEdit: { editingId = screen.id },
                                  onSave: { u in viewModel.screenManager.updateScreen(u); viewModel.regenerateTiles(); editingId = nil },
                                  onCancel: { editingId = nil },
                                  onRemove: { viewModel.screenManager.removeScreen(id: screen.id); viewModel.regenerateTiles() })
                    }
                }.padding(.vertical, 4)
            }
            Divider()
            Button { viewModel.screenManager.addVirtualScreen(); viewModel.regenerateTiles() } label: {
                Label("Add Virtual Display", systemImage: "plus.rectangle.on.rectangle").font(.callout)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
            }.buttonStyle(.borderless).padding(.horizontal, 16).padding(.vertical, 8)
            
            if !viewModel.screenManager.screens.isEmpty {
                HStack {
                    Image(systemName: "rectangle.dashed").font(.caption2)
                    Text("Canvas: \(viewModel.boundingBoxDescription)").font(.caption2)
                }.foregroundStyle(.secondary).padding(.horizontal, 16).padding(.bottom, 4)
                Text("Drag screens in preview to reposition").font(.caption2).foregroundStyle(.tertiary)
                    .padding(.horizontal, 16).padding(.bottom, 4)
                
                Divider().padding(.vertical, 4)
                
                // Mapping section
                VStack(spacing: 6) {
                    HStack {
                        Label("Desktop Mapping", systemImage: "arrow.triangle.swap").font(.caption.weight(.semibold))
                        Spacer()
                    }
                    
                    Button {
                        WallpaperService.testMapping()
                    } label: {
                        Label("Test (show numbers)", systemImage: "number.circle")
                            .font(.caption).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).controlSize(.mini)
                    .help("Apply numbered images to identify each desktop")
                    
                    Button {
                        swapQ27G4Mapping()
                    } label: {
                        Label("Swap external screens", systemImage: "arrow.left.arrow.right")
                            .font(.caption).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).controlSize(.mini)
                    .help("Swap the wallpaper assignment between your two external monitors")
                    
                    if WallpaperService.manualMappingOverrides.isEmpty {
                        Text("Auto-detected").font(.caption2).foregroundStyle(.tertiary)
                    } else {
                        HStack {
                            Text("Manual override active").font(.caption2).foregroundStyle(.orange)
                            Spacer()
                            Button("Reset") {
                                WallpaperService.clearMappingOverrides()
                            }.font(.caption2).buttonStyle(.borderless)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 8)
            }
        }
    }
    
    private func swapQ27G4Mapping() {
        let nsScreens = NSScreen.screens
        let desktopNames = WallpaperService.getDesktopNames()
        var mapping = WallpaperService.buildDesktopMapping(nsScreens: nsScreens, desktopNames: desktopNames)
        
        // Find the two NSScreen indices that are external (same model, not Retina)
        var externalIndices: [Int] = []
        for (i, screen) in nsScreens.enumerated() {
            if screen.backingScaleFactor == 1.0 { // external monitors typically have backing=1
                externalIndices.append(i)
            }
        }
        
        // Swap their desktop assignments
        if externalIndices.count == 2 {
            let a = externalIndices[0]
            let b = externalIndices[1]
            let tempA = mapping[a]
            let tempB = mapping[b]
            mapping[a] = tempB
            mapping[b] = tempA
            
            WallpaperService.manualMappingOverrides = mapping
            print("🔄 Swapped: NSScreen[\(a)]→Desktop \(mapping[a] ?? 0), NSScreen[\(b)]→Desktop \(mapping[b] ?? 0)")
        }
    }
    
    struct ScreenRow: View {
        let screen: ScreenInfo
        let isEditing: Bool
        let onEdit: () -> Void
        let onSave: (ScreenInfo) -> Void
        let onCancel: () -> Void
        let onRemove: () -> Void
        
        @State private var eName: String = ""
        @State private var eW: String = ""
        @State private var eH: String = ""
        @State private var eX: String = ""
        @State private var eY: String = ""
        
        var body: some View {
            VStack(spacing: 0) {
                if isEditing { editView } else { displayView }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
            .onAppear {
                eName = screen.name
                eW = "\(Int(screen.width))"
                eH = "\(Int(screen.height))"
                eX = "\(Int(screen.originX))"
                eY = "\(Int(screen.originY))"
            }
        }
        
        private var displayView: some View {
            HStack(spacing: 10) {
                Image(systemName: screen.isAutoDetected ? "display" : "rectangle.dashed")
                    .font(.title3).foregroundStyle(screen.isAutoDetected ? .primary : Color.orange).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(screen.name).font(.callout.weight(.medium)).lineLimit(1)
                    HStack(spacing: 8) {
                        Text(screen.resolution).font(.caption.monospaced())
                        Text("@ \(Int(screen.originX)),\(Int(screen.originY))").font(.caption.monospaced()).foregroundStyle(.tertiary)
                    }.foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Button { onEdit() } label: { Image(systemName: "pencil").font(.caption) }.buttonStyle(.borderless)
                    if !screen.isAutoDetected {
                        Button { onRemove() } label: { Image(systemName: "xmark").font(.caption).foregroundStyle(.red.opacity(0.8)) }.buttonStyle(.borderless)
                    }
                }
            }
        }
        
        private var editView: some View {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Name", text: $eName).textFieldStyle(.roundedBorder).font(.callout)
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Width").font(.caption2).foregroundStyle(.secondary)
                        TextField("W", text: $eW).textFieldStyle(.roundedBorder).font(.caption.monospaced())
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Height").font(.caption2).foregroundStyle(.secondary)
                        TextField("H", text: $eH).textFieldStyle(.roundedBorder).font(.caption.monospaced())
                    }
                }
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pos X").font(.caption2).foregroundStyle(.secondary)
                        TextField("X", text: $eX).textFieldStyle(.roundedBorder).font(.caption.monospaced())
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pos Y").font(.caption2).foregroundStyle(.secondary)
                        TextField("Y", text: $eY).textFieldStyle(.roundedBorder).font(.caption.monospaced())
                    }
                }
                HStack {
                    Button("Cancel") { onCancel() }.buttonStyle(.bordered).controlSize(.small)
                    Spacer()
                    Button("Save") {
                        var u = screen
                        u.name = eName
                        u.width = CGFloat(Int(eW) ?? Int(screen.width))
                        u.height = CGFloat(Int(eH) ?? Int(screen.height))
                        u.originX = CGFloat(Int(eX) ?? Int(screen.originX))
                        u.originY = CGFloat(Int(eY) ?? Int(screen.originY))
                        onSave(u)
                    }.buttonStyle(.borderedProminent).controlSize(.small)
                }
            }.padding(.vertical, 4)
        }
    }}
