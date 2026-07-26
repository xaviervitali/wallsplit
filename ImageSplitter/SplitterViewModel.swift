import SwiftUI
import Combine
import UniformTypeIdentifiers

class SplitterViewModel: ObservableObject {
    @Published var screenManager = ScreenManager()
    @Published var presetManager = PresetManager()
    @Published var library = WallpaperLibrary()
    @Published var sourceImage: NSImage?
    @Published var sourceImageName = ""
    @Published var sourceImageURL: URL?
    @Published var tiles: [SplitTile] = []
    @Published var isDragging = false
    @Published var selectedTileId: UUID?
    @Published var fitMode: ImageSplitterService.FitMode = .fit
    @Published var anchorX: CGFloat = 0.5  // 0=left, 0.5=center, 1=right
    @Published var anchorY: CGFloat = 0.5  // 0=top, 0.5=center, 1=bottom
    
    @Published var showExportSuccess = false
    @Published var exportedCount = 0
    @Published var showWallpaperResult = false
    @Published var wallpaperResultMessage = ""
    @Published var wallpaperResultIsError = false
    @Published var showSavePreset = false
    @Published var presetName = ""
    @Published var showHelp = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        library.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        presetManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        loadCurrentWallpaper()
    }

    func loadCurrentWallpaper() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen,
              let url = NSWorkspace.shared.desktopImageURL(for: screen) else { return }
        loadImage(from: url)
    }
    
    // MARK: - Image
    
    func loadImage(from url: URL) {
        guard let image = NSImage(contentsOf: url) else { return }
        sourceImage = image
        sourceImageURL = url
        sourceImageName = url.deletingPathExtension().lastPathComponent
        regenerateTiles()
    }
    
    func loadImage(_ image: NSImage, name: String = "pasted") {
        sourceImage = image
        sourceImageURL = nil
        sourceImageName = name
        regenerateTiles()
    }
    
    func regenerateTiles() {
        guard let image = sourceImage else { tiles = []; return }
        tiles = ImageSplitterService.split(
            image: image, screens: screenManager.screens,
            boundingBox: screenManager.boundingBox, fitMode: fitMode,
            anchorX: anchorX, anchorY: anchorY
        )
    }

    /// Régénère les tiles et applique immédiatement sans alert ni redémarrage du Dock.
    func regenerateAndApply() {
        regenerateTiles()
        guard !tiles.isEmpty else { return }
        WallpaperService.applyQuick(tiles: tiles, screenInfos: screenManager.screens, format: "png")
    }

    /// Applique les tiles actuels sans les régénérer (après un loadImage par exemple).
    func applyCurrentTiles() {
        guard !tiles.isEmpty else { return }
        WallpaperService.applyQuick(tiles: tiles, screenInfos: screenManager.screens, format: "png")
    }
    
    // MARK: - Wallpapers
    
    func applyWallpapers() {
        guard !tiles.isEmpty else { return }

        let result = WallpaperService.applyAsWallpapers(tiles: tiles, screenInfos: screenManager.screens, format: "png")
        switch result {
        case .success(let r):
            if r.skipped == 0 {
                wallpaperResultMessage = "Wallpaper applied on \(r.applied) screen\(r.applied > 1 ? "s" : "")!"
            } else if r.applied == 0 {
                wallpaperResultMessage = "Could not apply wallpapers: full-screen apps are blocking all screens. Exit full-screen and try again."
            } else {
                wallpaperResultMessage = "Wallpaper applied on \(r.applied) screen\(r.applied > 1 ? "s" : ""). \(r.skipped) screen\(r.skipped > 1 ? "s are" : " is") blocked by a full-screen app — the change will appear when you exit full-screen."
            }
            wallpaperResultIsError = r.applied == 0
        case .failure(let error):
            wallpaperResultMessage = error.localizedDescription
            wallpaperResultIsError = true
        }
        showWallpaperResult = true
    }
    
    // MARK: - Presets

    func openSavePresetSheet() {
        if presetName.isEmpty {
            presetName = defaultPresetName
        }
        showSavePreset = true
    }

    private var defaultPresetName: String {
        if !sourceImageName.isEmpty {
            let count = screenManager.screens.count
            return count > 1 ? "\(sourceImageName) – \(count) screens" : sourceImageName
        }
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return "Preset \(f.string(from: Date()))"
    }

    func saveCurrentAsPreset() {
        guard !presetName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        presetManager.savePreset(
            name: presetName,
            screens: screenManager.screens,
            fitMode: fitMode,
            sourceImage: sourceImage,
            sourceImageURL: sourceImageURL
        )
        presetName = ""
        showSavePreset = false
    }

    func loadPreset(_ preset: Preset) {
        screenManager.screens = preset.screens
        fitMode = ImageSplitterService.FitMode.allCases.first { $0.rawValue == preset.fitMode } ?? .fill
        if let url = presetManager.imageURL(for: preset) {
            loadImage(from: url)
        } else {
            regenerateTiles()
        }
        applyCurrentTiles()
    }
    
    // MARK: - Drop
    
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] item, _ in
                DispatchQueue.main.async {
                    if let url = item as? URL { self?.loadImage(from: url) }
                    else if let data = item as? Data, let img = NSImage(data: data) { self?.loadImage(img) }
                }
            }
            return true
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                DispatchQueue.main.async {
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) { self?.loadImage(from: url) }
                }
            }
            return true
        }
        return false
    }
    
    // MARK: - File Picker
    
    func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg, .tiff, .bmp]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url { loadImage(from: url) }
    }
    
    // MARK: - Export
    
    func exportTiles() {
        guard !tiles.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        if panel.runModal() == .OK, let url = panel.url {
            let saved = ImageSplitterService.exportTiles(tiles, to: url, format: "png", baseName: sourceImageName.isEmpty ? "wallpaper" : sourceImageName)
            exportedCount = saved.count
            showExportSuccess = true
            if let first = saved.first {
                NSWorkspace.shared.selectFile(first.path, inFileViewerRootedAtPath: url.path)
            }
        }
    }
    
    /// Charge l'image source d'un set de la bibliothèque pour modifier la présentation
    func loadFromLibrarySet(_ set: WallpaperSet) {
        guard let url = library.originalImageURL(for: set) else { return }
        loadImage(from: url)
    }

    func clearImage() {
        sourceImage = nil; sourceImageName = ""; sourceImageURL = nil; tiles = []; selectedTileId = nil
    }
    
    var imageDimensions: String {
        guard let cg = sourceImage?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return "" }
        return "\(cg.width) × \(cg.height) px"
    }
    
    var boundingBoxDescription: String {
        let bb = screenManager.boundingBox
        return "\(Int(bb.width)) × \(Int(bb.height)) px"
    }
}
