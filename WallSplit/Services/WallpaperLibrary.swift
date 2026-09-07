import SwiftUI
import Combine

/// A saved set of wallpapers (one per screen)
struct WallpaperSet: Identifiable, Codable {
    let id: UUID
    var name: String
    var createdAt: Date
    var screenCount: Int
    /// Filenames within the set's folder (one per screen, ordered by desktop index)
    var files: [WallpaperFile]
    /// Filename of the original (unsplit) source image, if available for re-editing
    var originalImageFilename: String?

    var displayDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: createdAt)
    }
}

struct WallpaperFile: Codable {
    let filename: String
    let screenName: String
    let desktopIndex: Int  // System Events desktop number (1-based)
}

/// Manages a library of saved wallpaper sets
class WallpaperLibrary: ObservableObject {
    @Published var sets: [WallpaperSet] = []
    @Published var autoRotateEnabled = false
    @Published var autoRotateInterval: TimeInterval = 3600  // 1 hour default
    
    private var rotationTimer: Timer?
    
    private var libraryDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("WallSplit/Library", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private var indexURL: URL {
        libraryDir.appendingPathComponent("library.json")
    }
    
    init() {
        loadLibrary()
    }
    
    // MARK: - Save a set
    
    /// Save current tiles as a named wallpaper set in the library
    func saveSet(
        name: String,
        tiles: [SplitTile],
        screenInfos: [ScreenInfo],
        format: String = "png",
        sourceImage: NSImage? = nil,
        sourceImageURL: URL? = nil
    ) -> Bool {
        let setId = UUID()
        let setDir = libraryDir.appendingPathComponent(setId.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: setDir, withIntermediateDirectories: true)

        // Sauvegarder l'image source pour pouvoir la recharger et modifier la présentation
        var originalImageFilename: String? = nil
        if let srcURL = sourceImageURL, FileManager.default.fileExists(atPath: srcURL.path) {
            let ext = srcURL.pathExtension.isEmpty ? "png" : srcURL.pathExtension
            let destURL = setDir.appendingPathComponent("original.\(ext)")
            if (try? FileManager.default.copyItem(at: srcURL, to: destURL)) != nil {
                originalImageFilename = "original.\(ext)"
            }
        } else if let srcImage = sourceImage,
                  let cgImage = srcImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let destURL = setDir.appendingPathComponent("original.png")
            let rep = NSBitmapImageRep(cgImage: cgImage)
            if let data = rep.representation(using: .png, properties: [:]) {
                try? data.write(to: destURL, options: .atomic)
                originalImageFilename = "original.png"
            }
        }

        let desktopNames = getDesktopNames()
        let nsScreens = NSScreen.screens
        let mapping = WallpaperService.buildDesktopMapping(nsScreens: nsScreens, desktopNames: desktopNames)
        
        var wallpaperFiles: [WallpaperFile] = []
        
        for tile in tiles {
            guard let screenInfo = screenInfos.first(where: { $0.id == tile.screenId }),
                  let nsIndex = screenInfo.nsScreenIndex,
                  nsIndex < nsScreens.count
            else { continue }
            
            // Fallback sur nsIndex+1 si l'écran n'est pas dans le mapping
            // (ex: "Displays have separate Spaces" désactivé → System Events ne voit qu'1 desktop)
            let dNum = mapping[nsIndex] ?? (nsIndex + 1)

            let ext = format == "jpeg" ? "jpg" : "png"
            let safeName = tile.screenName.replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "/", with: "-")
            let filename = "\(safeName).\(ext)"
            let fileURL = setDir.appendingPathComponent(filename)
            
            guard let cgImage = tile.image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
            let rep = NSBitmapImageRep(cgImage: cgImage)
            let fileType: NSBitmapImageRep.FileType = format == "jpeg" ? .jpeg : .png
            let props: [NSBitmapImageRep.PropertyKey: Any] = format == "jpeg" ? [.compressionFactor: 0.95] : [:]
            guard let data = rep.representation(using: fileType, properties: props) else { continue }
            
            do {
                try data.write(to: fileURL, options: .atomic)
                wallpaperFiles.append(WallpaperFile(filename: filename, screenName: tile.screenName, desktopIndex: dNum))
            } catch {
                print("Failed to save: \(error)")
            }
        }
        
        guard !wallpaperFiles.isEmpty else { return false }
        
        // Generate thumbnail (composite of all tiles)
        saveThumbnail(tiles: tiles, to: setDir)
        
        let newSet = WallpaperSet(
            id: setId, name: name, createdAt: Date(),
            screenCount: wallpaperFiles.count, files: wallpaperFiles,
            originalImageFilename: originalImageFilename
        )
        sets.insert(newSet, at: 0)
        persistLibrary()

        return true
    }
    
    // MARK: - Apply a set
    
    /// Apply a wallpaper set. Re-maps screen names to desktops at apply time.
    func applySet(_ set: WallpaperSet) -> Bool {
        let setDir = libraryDir.appendingPathComponent(set.id.uuidString)
        let nsScreens = NSScreen.screens
        let desktopNames = getDesktopNames()
        let mapping = WallpaperService.buildDesktopMapping(nsScreens: nsScreens, desktopNames: desktopNames)

        var usedDesktops = Set<Int>()
        var usedNSScreens = Set<Int>()
        var appliedCount = 0
        var scriptLines: [String] = ["tell application \"System Events\""]

        for file in set.files {
            let fileURL = setDir.appendingPathComponent(file.filename)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }

            let cleanName = file.screenName.lowercased()
                .replacingOccurrences(of: " ★", with: "")
                .replacingOccurrences(of: "★", with: "")
                .trimmingCharacters(in: .whitespaces)

            // Trouver le NSScreen correspondant par nom (exact match d'abord)
            var matchedNSIndex: Int? = nil
            for (nsIdx, nsScreen) in nsScreens.enumerated() {
                if usedNSScreens.contains(nsIdx) { continue }
                let nsName = nsScreen.localizedName.lowercased()
                if nsName == cleanName || nsName.contains(cleanName) || cleanName.contains(nsName) {
                    matchedNSIndex = nsIdx
                    break
                }
            }

            // Fallback : si le nom ne correspond pas, retrouver l'écran via le desktopIndex stocké
            if matchedNSIndex == nil {
                for (nsIdx, dNum) in mapping where dNum == file.desktopIndex && !usedNSScreens.contains(nsIdx) {
                    matchedNSIndex = nsIdx
                    break
                }
            }

            // Méthode primaire : API native NSWorkspace
            if let nsIdx = matchedNSIndex {
                let nsScreen = nsScreens[nsIdx]
                do {
                    try NSWorkspace.shared.setDesktopImageURL(fileURL, for: nsScreen, options: [:])
                    usedNSScreens.insert(nsIdx)
                    appliedCount += 1
                    print("✅ [Library] NSWorkspace: \(nsScreen.localizedName) → \(file.filename)")
                } catch {
                    print("⚠️ [Library] NSWorkspace failed for \(nsScreen.localizedName): \(error)")
                }
            }

            // Complément System Events pour les autres espaces
            var desktopNum: Int? = nil
            if let nsIdx = matchedNSIndex, let dNum = mapping[nsIdx], !usedDesktops.contains(dNum) {
                desktopNum = dNum
                usedDesktops.insert(dNum)
            } else if !usedDesktops.contains(file.desktopIndex) {
                desktopNum = file.desktopIndex
                usedDesktops.insert(file.desktopIndex)
            } else {
                for d in 1...max(desktopNames.count, 1) where !usedDesktops.contains(d) {
                    desktopNum = d
                    usedDesktops.insert(d)
                    break
                }
            }

            if let dNum = desktopNum {
                print("🖼 [Library] \(file.screenName) → Desktop \(dNum)")
                scriptLines.append("    tell desktop \(dNum)")
                scriptLines.append("        set picture to \"\(fileURL.path)\"")
                scriptLines.append("    end tell")
            }
        }

        scriptLines.append("end tell")
        _ = runAppleScript(scriptLines.joined(separator: "\n"))

        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            p.arguments = ["Dock"]
            try? p.run()
            p.waitUntilExit()
        }

        return appliedCount > 0
    }
    
    // MARK: - Random
    
    func applyRandom() -> String? {
        guard !sets.isEmpty else { return nil }
        let randomSet = sets.randomElement()!
        let success = applySet(randomSet)
        return success ? randomSet.name : nil
    }
    
    // MARK: - Auto Rotation
    
    func startAutoRotation() {
        stopAutoRotation()
        autoRotateEnabled = true
        
        rotationTimer = Timer.scheduledTimer(withTimeInterval: autoRotateInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                _ = self?.applyRandom()
            }
        }
        
        // Apply one immediately
        _ = applyRandom()
    }
    
    func stopAutoRotation() {
        autoRotateEnabled = false
        rotationTimer?.invalidate()
        rotationTimer = nil
    }
    
    func updateRotationInterval(_ interval: TimeInterval) {
        autoRotateInterval = interval
        if autoRotateEnabled {
            startAutoRotation()
        }
    }
    
    // MARK: - Import Folder

    /// Import a folder using .fit mode + smart crop per image (async)
    func importFolderSmart(
        url: URL,
        screens: [ScreenInfo],
        boundingBox: CGRect,
        format: String,
        progress: ((String, Int, Int) -> Void)? = nil
    ) async -> (imported: Int, skipped: Int) {
        let fm = FileManager.default
        let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "tiff", "tif", "bmp", "heic", "webp"]

        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return (0, 0)
        }

        let imageFiles = contents
            .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !imageFiles.isEmpty else { return (0, 0) }

        var imported = 0
        var skipped = 0
        let fitMode = WallSplitService.FitMode.fit
        let canvasSize = boundingBox.size

        for (index, fileURL) in imageFiles.enumerated() {
            let fileName = fileURL.deletingPathExtension().lastPathComponent
            progress?(fileName, index + 1, imageFiles.count)

            guard let image = NSImage(contentsOf: fileURL) else {
                skipped += 1
                continue
            }

            let smartResult = await SmartCropService.suggestAnchor(for: image, canvasSize: canvasSize, fitMode: fitMode)
            let anchorX = smartResult?.anchorX ?? 0.5
            let anchorY = smartResult?.anchorY ?? 0.5

            let tiles = WallSplitService.split(
                image: image,
                screens: screens,
                boundingBox: boundingBox,
                fitMode: fitMode,
                anchorX: anchorX,
                anchorY: anchorY
            )

            guard !tiles.isEmpty else { skipped += 1; continue }

            if saveSet(name: fileName, tiles: tiles, screenInfos: screens, format: format, sourceImageURL: fileURL) {
                imported += 1
            } else {
                skipped += 1
            }
        }

        return (imported, skipped)
    }

    /// Import all images from a folder: split each one and save as a set in the library
    /// Returns (imported count, skipped count)
    func importFolder(
        url: URL,
        screens: [ScreenInfo],
        boundingBox: CGRect,
        fitMode: WallSplitService.FitMode,
        anchorX: CGFloat,
        anchorY: CGFloat,
        format: String,
        progress: ((String, Int, Int) -> Void)? = nil
    ) -> (imported: Int, skipped: Int) {
        let fm = FileManager.default
        let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "tiff", "tif", "bmp", "heic", "webp"]
        
        // Find all image files in folder (non-recursive first level)
        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return (0, 0)
        }
        
        let imageFiles = contents.filter { imageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        
        guard !imageFiles.isEmpty else { return (0, 0) }
        
        var imported = 0
        var skipped = 0
        
        for (index, fileURL) in imageFiles.enumerated() {
            let fileName = fileURL.deletingPathExtension().lastPathComponent
            progress?(fileName, index + 1, imageFiles.count)
            
            guard let image = NSImage(contentsOf: fileURL) else {
                skipped += 1
                print("⚠️ Could not load: \(fileURL.lastPathComponent)")
                continue
            }
            
            // Split the image
            let tiles = WallSplitService.split(
                image: image,
                screens: screens,
                boundingBox: boundingBox,
                fitMode: fitMode,
                anchorX: anchorX,
                anchorY: anchorY
            )
            
            guard !tiles.isEmpty else {
                skipped += 1
                continue
            }
            
            // Save as a set (avec l'image source pour permettre la ré-édition)
            if saveSet(name: fileName, tiles: tiles, screenInfos: screens, format: format, sourceImageURL: fileURL) {
                imported += 1
                print("✅ Imported: \(fileName)")
            } else {
                skipped += 1
            }
        }
        
        return (imported, skipped)
    }
    
    // MARK: - Clear Library
    
    func clearAllSets() {
        for set in sets {
            let setDir = libraryDir.appendingPathComponent(set.id.uuidString)
            try? FileManager.default.removeItem(at: setDir)
        }
        sets.removeAll()
        persistLibrary()
    }
    
    // MARK: - Delete
    
    func deleteSet(id: UUID) {
        let setDir = libraryDir.appendingPathComponent(id.uuidString)
        try? FileManager.default.removeItem(at: setDir)
        sets.removeAll { $0.id == id }
        persistLibrary()
    }
    
    // MARK: - Backup Current Wallpapers
    
    /// Save the current wallpapers from all desktops into the library
    /// Uses System Events to get current picture paths, then copies the files
    func backupCurrentWallpapers(name: String = "Backup") -> Bool {
        // Get current wallpaper paths from System Events
        let paths = getCurrentWallpaperPaths()
        guard !paths.isEmpty else {
            print("❌ No current wallpapers found")
            return false
        }
        
        let desktopNames = getDesktopNames()
        
        let setId = UUID()
        let setDir = libraryDir.appendingPathComponent(setId.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: setDir, withIntermediateDirectories: true)
        
        var wallpaperFiles: [WallpaperFile] = []
        var thumbnailImages: [(NSImage, CGFloat, CGFloat)] = [] // image, width, height
        
        for (index, path) in paths.enumerated() {
            let sourceURL = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else {
                print("⚠️ Wallpaper file not found: \(path)")
                continue
            }
            
            let desktopNum = index + 1
            let screenName = index < desktopNames.count ? desktopNames[index] : "Desktop \(desktopNum)"
            let safeName = screenName
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "/", with: "-")
            
            let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
            let filename = "\(safeName).\(ext)"
            let destURL = setDir.appendingPathComponent(filename)
            
            do {
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
                wallpaperFiles.append(WallpaperFile(
                    filename: filename,
                    screenName: screenName,
                    desktopIndex: desktopNum
                ))
                
                // Load for thumbnail
                if let img = NSImage(contentsOf: sourceURL) {
                    let size = img.size
                    thumbnailImages.append((img, size.width, size.height))
                }
                
                print("✅ Backed up \(screenName): \(path)")
            } catch {
                print("❌ Copy failed for \(screenName): \(error.localizedDescription)")
            }
        }
        
        guard !wallpaperFiles.isEmpty else { return false }
        
        // Generate thumbnail
        saveThumbnailFromImages(thumbnailImages, to: setDir)
        
        let newSet = WallpaperSet(
            id: setId,
            name: name,
            createdAt: Date(),
            screenCount: wallpaperFiles.count,
            files: wallpaperFiles
        )
        sets.insert(newSet, at: 0)
        persistLibrary()
        
        print("✅ Backup saved: \(name) (\(wallpaperFiles.count) screens)")
        return true
    }
    
    /// Get current wallpaper file paths from System Events
    private func getCurrentWallpaperPaths() -> [String] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", "tell application \"System Events\" to get picture of every desktop"]
        let out = Pipe()
        p.standardOutput = out
        do {
            try p.run()
            p.waitUntilExit()
            let str = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return str.components(separatedBy: ", ")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        } catch { return [] }
    }
    
    /// Generate thumbnail from NSImage array
    private func saveThumbnailFromImages(_ images: [(NSImage, CGFloat, CGFloat)], to dir: URL) {
        guard !images.isEmpty else { return }
        let thumbH: CGFloat = 80
        let totalW = images.reduce(CGFloat(0)) { result, item in
            let (_, w, h) = item
            return result + (h > 0 ? w / h * thumbH : thumbH)
        }
        
        let thumbImage = NSImage(size: NSSize(width: totalW, height: thumbH))
        thumbImage.lockFocus()
        var x: CGFloat = 0
        for (img, w, h) in images {
            let drawW = h > 0 ? w / h * thumbH : thumbH
            img.draw(in: NSRect(x: x, y: 0, width: drawW, height: thumbH))
            x += drawW
        }
        thumbImage.unlockFocus()
        
        if let cgImage = thumbImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let rep = NSBitmapImageRep(cgImage: cgImage)
            if let data = rep.representation(using: .png, properties: [:]) {
                try? data.write(to: dir.appendingPathComponent("thumbnail.png"), options: .atomic)
            }
        }
    }
    
    // MARK: - Original image access

    /// URL de l'image source originale si elle a été sauvegardée avec le set
    func originalImageURL(for set: WallpaperSet) -> URL? {
        guard let filename = set.originalImageFilename else { return nil }
        let url = libraryDir.appendingPathComponent(set.id.uuidString).appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Thumbnail

    func thumbnailURL(for set: WallpaperSet) -> URL {
        libraryDir.appendingPathComponent(set.id.uuidString).appendingPathComponent("thumbnail.png")
    }
    
    private func saveThumbnail(tiles: [SplitTile], to dir: URL) {
        // Create a small composite image
        let thumbH: CGFloat = 80
        let totalW = tiles.reduce(CGFloat(0)) { $0 + ($1.screenRect.width / $1.screenRect.height * thumbH) }
        
        let thumbImage = NSImage(size: NSSize(width: totalW, height: thumbH))
        thumbImage.lockFocus()
        var x: CGFloat = 0
        for tile in tiles {
            let w = tile.screenRect.width / tile.screenRect.height * thumbH
            tile.image.draw(in: NSRect(x: x, y: 0, width: w, height: thumbH))
            x += w
        }
        thumbImage.unlockFocus()
        
        if let cgImage = thumbImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let rep = NSBitmapImageRep(cgImage: cgImage)
            if let data = rep.representation(using: .png, properties: [:]) {
                try? data.write(to: dir.appendingPathComponent("thumbnail.png"), options: .atomic)
            }
        }
    }
    
    // MARK: - Persistence
    
    private func loadLibrary() {
        guard FileManager.default.fileExists(atPath: indexURL.path) else { return }
        do {
            let data = try Data(contentsOf: indexURL)
            sets = try JSONDecoder().decode([WallpaperSet].self, from: data)
        } catch {
            print("Library load error: \(error)")
        }
    }
    
    private func persistLibrary() {
        do {
            let data = try JSONEncoder().encode(sets)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            print("Library save error: \(error)")
        }
    }
    
    // MARK: - Desktop matching (same as WallpaperService)
    
    private func findDesktopNum(nsName: String, desktopNames: [String], screenInfos: [ScreenInfo], currentId: UUID, nsScreens: [NSScreen]) -> Int? {
        for (dIdx, dName) in desktopNames.enumerated() {
            if namesMatch(nsName: nsName, desktopName: dName) { return dIdx + 1 }
        }
        // Fallback
        var matched = Set<Int>()
        for si in screenInfos where si.id != currentId {
            if let idx = si.nsScreenIndex, idx < nsScreens.count {
                let name = nsScreens[idx].localizedName
                for (dIdx, dName) in desktopNames.enumerated() {
                    if namesMatch(nsName: name, desktopName: dName) { matched.insert(dIdx) }
                }
            }
        }
        for dIdx in 0..<desktopNames.count where !matched.contains(dIdx) { return dIdx + 1 }
        return nil
    }
    
    private func namesMatch(nsName: String, desktopName: String) -> Bool {
        let a = nsName.lowercased(), b = desktopName.lowercased()
        if a == b || a.contains(b) || b.contains(a) { return true }
        let tokA = a.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 3 }
        let tokB = b.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 3 }
        for t in tokA { if tokB.contains(t) { return true } }
        if a.contains("retina") && b.contains("retina") { return true }
        if (a.contains("built-in") || a.contains("built in")) && b.contains("intégré") { return true }
        if a.contains("intégré") && (b.contains("built-in") || b.contains("built in")) { return true }
        return false
    }
    
    private func getDesktopNames() -> [String] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", "tell application \"System Events\" to get name of every desktop"]
        let out = Pipe()
        p.standardOutput = out
        do {
            try p.run(); p.waitUntilExit()
            let str = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return str.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
        } catch { return [] }
    }
    
    private func runAppleScript(_ source: String) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", source]
        let err = Pipe(); p.standardError = err
        do {
            try p.run(); p.waitUntilExit()
            return p.terminationStatus == 0
        } catch { return false }
    }
}
