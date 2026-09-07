import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var viewModel: SplitterViewModel
    @ObservedObject private var proManager = ProManager.shared
    @State private var showSaveName = false
    @State private var saveName = ""
    @State private var saveResult: String?
    @State private var isImporting = false
    @State private var importProgress = ""
    @State private var isSmartImporting = false
    @State private var showClearConfirm = false
    @State private var customMinutes: String = ""
    @State private var showCustomInterval = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label("Library", systemImage: "photo.stack").font(.headline)
                Spacer()
                Text("\(viewModel.library.sets.count)")
                    .font(.caption.monospaced()).foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(.quaternary))
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            
            Divider()

            // Backup + Save buttons
            VStack(spacing: 6) {
                Button {
                    let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
                    if viewModel.library.backupCurrentWallpapers(name: "Backup \(dateStr)") {
                        saveResult = "Current wallpapers saved!"
                    } else {
                        saveResult = "Could not read current wallpapers"
                    }
                } label: {
                    Label("Backup Current Wallpapers", systemImage: "arrow.down.doc")
                        .font(.callout).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.small)
                
                if viewModel.sourceImage != nil && !viewModel.tiles.isEmpty {
                    Button {
                        showSaveName = true
                    } label: {
                        Label("Save Split to Library", systemImage: "plus.square.on.square")
                            .font(.callout).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                }
                
                // Import folder (fit + smart crop — adapts to current screens)
                Button {
                    importFolderSmart()
                } label: {
                    Label("Import Folder (Fit + Smart)…", systemImage: "sparkles.rectangle.stack")
                        .font(.callout).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.small)
                .disabled(isImporting || isSmartImporting)

                // Import folder (manual settings)
                Button {
                    importFolder()
                } label: {
                    Label("Import Folder…", systemImage: "folder.badge.plus")
                        .font(.callout).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.small)
                .disabled(isImporting || isSmartImporting)

                if isImporting || isSmartImporting {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text(importProgress).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                
                // Clear library
                if !viewModel.library.sets.isEmpty {
                    Button {
                        showClearConfirm = true
                    } label: {
                        Label("Clear Library", systemImage: "trash")
                            .font(.callout).foregroundStyle(.red.opacity(0.8)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            
            Divider()
            
            // Random + Auto-rotate controls
            VStack(spacing: 8) {
                Button {
                    if let name = viewModel.library.applyRandom() {
                        saveResult = "Applied: \(name)"
                    } else {
                        saveResult = "No sets in library"
                    }
                } label: {
                    Label("Random Wallpaper", systemImage: "shuffle")
                        .font(.callout.weight(.medium)).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.small)
                .disabled(viewModel.library.sets.isEmpty)
                
                // Auto-rotate (Pro feature)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Toggle(isOn: Binding(
                            get: { viewModel.library.autoRotateEnabled },
                            set: { enabled in
                                guard proManager.isPro else {
                                    viewModel.showUpgradeSheet = true
                                    return
                                }
                                if enabled { viewModel.library.startAutoRotation() }
                                else { viewModel.library.stopAutoRotation() }
                            }
                        )) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath").font(.caption)
                                Text("Auto-rotate").font(.callout)
                                if !proManager.isPro { ProBadge() }
                            }
                        }
                        .toggleStyle(.switch).controlSize(.small)
                        Spacer()
                    }

                    if viewModel.library.autoRotateEnabled && proManager.isPro {
                        HStack(spacing: 6) {
                            Picker("", selection: Binding(
                                get: { showCustomInterval ? TimeInterval(-1) : viewModel.library.autoRotateInterval },
                                set: { val in
                                    if val == -1 {
                                        showCustomInterval = true
                                    } else {
                                        showCustomInterval = false
                                        viewModel.library.updateRotationInterval(val)
                                    }
                                }
                            )) {
                                Text("5 min").tag(TimeInterval(300))
                                Text("15 min").tag(TimeInterval(900))
                                Text("30 min").tag(TimeInterval(1800))
                                Text("1 hour").tag(TimeInterval(3600))
                                Text("3 hours").tag(TimeInterval(10800))
                                Text("Daily").tag(TimeInterval(86400))
                                Text("Custom…").tag(TimeInterval(-1))
                            }
                            .pickerStyle(.menu).controlSize(.small)
                            .frame(maxWidth: .infinity)

                            if showCustomInterval {
                                HStack(spacing: 4) {
                                    TextField("min", text: $customMinutes)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 46)
                                        .onSubmit { applyCustomInterval() }
                                    Text("min").font(.caption).foregroundStyle(.secondary)
                                    Button("OK") { applyCustomInterval() }
                                        .buttonStyle(.bordered).controlSize(.mini)
                                }
                            }
                        }
                    }
                }
                .disabled(viewModel.library.sets.isEmpty)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            
            if let result = saveResult {
                Text(result).font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, 16).padding(.bottom, 4)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { saveResult = nil }
                    }
            }
            
            Divider()
            
            // Sets list
            if viewModel.library.sets.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle").font(.title2).foregroundStyle(.quaternary)
                    Text("No wallpapers saved").font(.caption).foregroundStyle(.tertiary)
                    Text("Split an image, then save to library").font(.caption2).foregroundStyle(.quaternary)
                }.frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(viewModel.library.sets) { set in
                            LibrarySetRow(wallpaperSet: set)
                        }
                    }.padding(.vertical, 4)
                }
            }
        }
        .alert("Save to Library", isPresented: $showSaveName) {
            TextField("Name", text: $saveName)
            Button("Save") {
                if viewModel.library.saveSet(
                    name: saveName.isEmpty ? "Untitled" : saveName,
                    tiles: viewModel.tiles,
                    screenInfos: viewModel.screenManager.screens,
                    format: "png",
                    sourceImage: viewModel.sourceImage,
                    sourceImageURL: viewModel.sourceImageURL
                ) {
                    saveResult = "Saved: \(saveName.isEmpty ? "Untitled" : saveName)"
                }
                saveName = ""
            }
            Button("Cancel", role: .cancel) { saveName = "" }
        }
        .alert("Clear Library", isPresented: $showClearConfirm) {
            Button("Delete All", role: .destructive) {
                viewModel.library.clearAllSets()
                saveResult = "Library cleared"
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete all \(viewModel.library.sets.count) wallpaper sets? This cannot be undone.")
        }
    }
    
    private func applyCustomInterval() {
        guard let minutes = Double(customMinutes), minutes > 0 else { return }
        viewModel.library.updateRotationInterval(minutes * 60)
        showCustomInterval = false
        customMinutes = ""
    }

    private func importFolderSmart() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder — images will be split using Fit + Smart Crop on current screens"
        panel.prompt = "Import"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        isSmartImporting = true
        importProgress = "Starting…"

        Task {
            let result = await viewModel.library.importFolderSmart(
                url: url,
                screens: viewModel.screenManager.screens,
                boundingBox: viewModel.screenManager.boundingBox,
                format: "png",
                progress: { name, current, total in
                    DispatchQueue.main.async {
                        importProgress = "\(current)/\(total): \(name)"
                    }
                }
            )
            DispatchQueue.main.async {
                isSmartImporting = false
                importProgress = ""
                saveResult = "Imported \(result.imported) wallpapers (Fit + Smart)" +
                    (result.skipped > 0 ? " (\(result.skipped) skipped)" : "")
            }
        }
    }

    private func importFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder of images to import"
        panel.prompt = "Import"
        
        guard panel.runModal() == .OK, let url = panel.url else { return }
        
        isImporting = true
        importProgress = "Starting…"
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = viewModel.library.importFolder(
                url: url,
                screens: viewModel.screenManager.screens,
                boundingBox: viewModel.screenManager.boundingBox,
                fitMode: viewModel.fitMode,
                anchorX: viewModel.anchorX,
                anchorY: viewModel.anchorY,
                format: "png",
                progress: { name, current, total in
                    DispatchQueue.main.async {
                        importProgress = "\(current)/\(total): \(name)"
                    }
                }
            )
            
            DispatchQueue.main.async {
                isImporting = false
                importProgress = ""
                saveResult = "Imported \(result.imported) wallpapers" +
                    (result.skipped > 0 ? " (\(result.skipped) skipped)" : "")
            }
        }
    }
}

struct LibrarySetRow: View {
    let wallpaperSet: WallpaperSet
    @EnvironmentObject var viewModel: SplitterViewModel
    @State private var hover = false
    @State private var thumbnail: NSImage?
    
    var body: some View {
        HStack(spacing: 10) {
            // Thumbnail
            Group {
                if let thumb = thumbnail {
                    Image(nsImage: thumb).resizable().aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 30).clipped()
                } else {
                    Rectangle().fill(.quaternary).frame(width: 60, height: 30)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(wallpaperSet.name).font(.callout.weight(.medium)).lineLimit(1)
                HStack(spacing: 4) {
                    Label("\(wallpaperSet.screenCount)", systemImage: "display").font(.caption2)
                    Text("·").font(.caption2)
                    Text(wallpaperSet.displayDate).font(.caption2)
                }.foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if hover {
                if viewModel.library.originalImageURL(for: wallpaperSet) != nil {
                    Button {
                        viewModel.loadFromLibrarySet(wallpaperSet)
                    } label: {
                        Image(systemName: "pencil.circle").font(.callout).foregroundStyle(.secondary)
                    }.buttonStyle(.borderless).help("Load for editing")
                }

                Button {
                    _ = viewModel.library.applySet(wallpaperSet)
                } label: {
                    Image(systemName: "play.circle.fill").font(.callout).foregroundStyle(Color.accentColor)
                }.buttonStyle(.borderless).help("Apply this set")

                Button {
                    viewModel.library.deleteSet(id: wallpaperSet.id)
                } label: {
                    Image(systemName: "trash").font(.caption).foregroundStyle(.red.opacity(0.7))
                }.buttonStyle(.borderless).help("Delete")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .background(hover ? Color.accentColor.opacity(0.06) : .clear)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture(count: 2) { _ = viewModel.library.applySet(wallpaperSet) }
        .onAppear { loadThumbnail() }
    }
    
    private func loadThumbnail() {
        let url = viewModel.library.thumbnailURL(for: wallpaperSet)
        if let img = NSImage(contentsOf: url) {
            thumbnail = img
        }
    }
}
