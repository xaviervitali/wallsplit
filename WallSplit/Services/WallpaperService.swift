import AppKit

class WallpaperService {
    
    static var wallpaperDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("WallSplit/Wallpapers", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    static var presetsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("WallSplit/Presets", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    struct ApplyResult {
        let applied: Int
        let skipped: Int   // écrans bloqués par une app plein écran
    }

    static func applyAsWallpapers(
        tiles: [SplitTile],
        screenInfos: [ScreenInfo],
        format: String = "png"
    ) -> Result<ApplyResult, WallpaperError> {
        let nsScreens = NSScreen.screens
        guard !nsScreens.isEmpty else { return .failure(.noScreens) }

        let savedURLs = saveTilesToDisk(tiles: tiles, format: format)
        guard savedURLs.count == tiles.count else { return .failure(.saveFailed) }

        var appliedCount = 0
        var skippedCount = 0

        // Pass 1: NSWorkspace — met à jour le Space actuellement visible sur chaque écran.
        // Échoue silencieusement si une app plein écran bloque le changement.
        for (tileIndex, tile) in tiles.enumerated() {
            guard let screenInfo = screenInfos.first(where: { $0.id == tile.screenId }),
                  let nsIndex = screenInfo.nsScreenIndex,
                  nsIndex < nsScreens.count
            else { continue }

            let nsScreen = nsScreens[nsIndex]
            let fileURL = savedURLs[tileIndex]

            do {
                try NSWorkspace.shared.setDesktopImageURL(fileURL, for: nsScreen, options: [:])
                print("✅ NSWorkspace: \(nsScreen.localizedName) → \(fileURL.lastPathComponent)")
                appliedCount += 1
            } catch {
                print("⚠️ NSWorkspace failed for \(nsScreen.localizedName): \(error)")
                skippedCount += 1
            }
        }

        let result = ApplyResult(applied: appliedCount, skipped: skippedCount)
        return (appliedCount + skippedCount) > 0 ? .success(result) : .failure(.applyFailed)
    }
    
    // MARK: - Test Mapping

    /// Apply a distinct solid-color image per screen to identify which screen is which.
    /// Sandbox-safe: uses NSWorkspace only, no osascript.
    static func testMapping() {
        let nsScreens = NSScreen.screens
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("WallSplit_test")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        for (nsIdx, screen) in nsScreens.enumerated() {
            let label = "\(screen.localizedName)\n(\(nsIdx + 1))"
            let size = NSSize(width: max(400, screen.frame.width * screen.backingScaleFactor),
                              height: max(300, screen.frame.height * screen.backingScaleFactor))
            let imgPath = tempDir.appendingPathComponent("test_\(nsIdx).png")
            generateTestImage(number: nsIdx + 1, label: label, size: size, saveTo: imgPath)
            try? NSWorkspace.shared.setDesktopImageURL(imgPath, for: screen, options: [:])
        }
    }

    /// Generate a numbered test image with a colour background.
    private static func generateTestImage(number: Int, label: String, size: NSSize, saveTo url: URL) {
        let colors: [NSColor] = [.systemBlue, .systemRed, .systemGreen, .systemOrange, .systemPurple, .systemTeal]
        let color = colors[(number - 1) % colors.count]
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        let numStr = "\(number)" as NSString
        let numFont = NSFont.systemFont(ofSize: size.height * 0.5, weight: .bold)
        let numAttrs: [NSAttributedString.Key: Any] = [.font: numFont, .foregroundColor: NSColor.white]
        let numSize = numStr.size(withAttributes: numAttrs)
        numStr.draw(at: NSPoint(x: (size.width - numSize.width) / 2,
                                y: (size.height - numSize.height) / 2 + size.height * 0.05),
                    withAttributes: numAttrs)
        let labelStr = label as NSString
        let labelFont = NSFont.systemFont(ofSize: size.height * 0.04, weight: .medium)
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: NSColor.white.withAlphaComponent(0.8)]
        let labelSize = labelStr.size(withAttributes: labelAttrs)
        labelStr.draw(at: NSPoint(x: (size.width - labelSize.width) / 2, y: size.height * 0.08),
                      withAttributes: labelAttrs)
        image.unlockFocus()
        if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let rep = NSBitmapImageRep(cgImage: cg)
            if let data = rep.representation(using: .png, properties: [:]) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
    
    // MARK: - Manual Mapping Override
    
    /// Stored overrides: key = "nsIndex", value = desktop number
    /// Saved in UserDefaults
    static var manualMappingOverrides: [Int: Int] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "desktopMappingOverrides"),
                  let dict = try? JSONDecoder().decode([String: Int].self, from: data) else { return [:] }
            var result: [Int: Int] = [:]
            for (k, v) in dict { if let intK = Int(k) { result[intK] = v } }
            return result
        }
        set {
            let dict = Dictionary(uniqueKeysWithValues: newValue.map { (String($0.key), $0.value) })
            if let data = try? JSONEncoder().encode(dict) {
                UserDefaults.standard.set(data, forKey: "desktopMappingOverrides")
            }
        }
    }
    
    /// Clear manual overrides
    static func clearMappingOverrides() {
        UserDefaults.standard.removeObject(forKey: "desktopMappingOverrides")
    }
    
    // MARK: - Desktop Mapping
    
    /// Build a mapping from NSScreen index → System Events desktop number (1-based)
    /// Strategy: match by name, and for duplicate names (e.g. two Q27G4),
    /// use position ordering (left→right) to disambiguate
    static func buildDesktopMapping(nsScreens: [NSScreen], desktopNames: [String]) -> [Int: Int] {
        // Check for manual overrides first
        let overrides = manualMappingOverrides
        if !overrides.isEmpty {
            print("📋 Using manual mapping overrides: \(overrides)")
            return overrides
        }
        
        var mapping: [Int: Int] = [:]
        var usedDesktops = Set<Int>() // desktop indices (0-based) already claimed
        
        // Step 1: Group NSScreens by their base model name
        // e.g. "Q27G4 (1)" → base "q27g4", "Built-in Retina Display" → base "built-in retina display"
        struct ScreenEntry {
            let nsIndex: Int
            let name: String
            let posX: CGFloat // for left→right ordering
        }
        
        var entries: [ScreenEntry] = []
        for (i, screen) in nsScreens.enumerated() {
            entries.append(ScreenEntry(
                nsIndex: i,
                name: screen.localizedName,
                posX: screen.frame.minX
            ))
        }
        
        // Step 2: Group desktop names by base name
        // "Q27G4 (1)" and "Q27G4 (2)" share base "q27g4"
        func baseName(_ name: String) -> String {
            // Remove trailing " (N)" pattern and lowercase
            var n = name.lowercased()
            if let range = n.range(of: #"\s*\(\d+\)\s*$"#, options: .regularExpression) {
                n.removeSubrange(range)
            }
            return n.trimmingCharacters(in: .whitespaces)
        }
        
        // Step 3: For each unique base name, collect NSScreens and desktops that match,
        // then pair them by position order (leftmost NSScreen → lowest desktop index)
        
        // Collect desktop entries
        struct DesktopEntry {
            let index: Int // 0-based
            let name: String
        }
        var desktopEntries = desktopNames.enumerated().map { DesktopEntry(index: $0.offset, name: $0.element) }
        
        // Get all unique base names from BOTH sides
        let allBaseNames = Set(
            entries.map { baseName($0.name) } +
            desktopEntries.map { baseName($0.name) }
        )
        
        for base in allBaseNames {
            // Find matching NSScreens (sorted by X position, left→right)
            var matchingNS = entries.filter { namesMatchBase(baseName($0.name), base) }
            matchingNS.sort { $0.posX < $1.posX }
            
            // Find matching desktops (sorted by their index, which SE gives in order)
            var matchingDE = desktopEntries.filter { namesMatchBase(baseName($0.name), base) && !usedDesktops.contains($0.index) }
            matchingDE.sort { $0.index < $1.index }
            
            // Pair them: leftmost NSScreen → first matching desktop
            for i in 0..<min(matchingNS.count, matchingDE.count) {
                let nsIdx = matchingNS[i].nsIndex
                let deIdx = matchingDE[i].index
                if mapping[nsIdx] == nil {
                    mapping[nsIdx] = deIdx + 1 // 1-based for AppleScript
                    usedDesktops.insert(deIdx)
                }
            }
        }
        
        // Step 4: Fallback for any unmatched NSScreens → assign remaining desktops
        let unmatchedNS = entries.filter { mapping[$0.nsIndex] == nil }.sorted { $0.posX < $1.posX }
        let unmatchedDE = desktopEntries.filter { !usedDesktops.contains($0.index) }.sorted { $0.index < $1.index }
        
        for i in 0..<min(unmatchedNS.count, unmatchedDE.count) {
            mapping[unmatchedNS[i].nsIndex] = unmatchedDE[i].index + 1
            usedDesktops.insert(unmatchedDE[i].index)
        }
        
        return mapping
    }
    
    /// Strip trailing " (N)" suffix and lowercase for comparison
    private static func baseName(_ name: String) -> String {
        var n = name.lowercased()
        if let range = n.range(of: #"\s*\(\d+\)\s*$"#, options: .regularExpression) {
            n.removeSubrange(range)
        }
        return n.trimmingCharacters(in: .whitespaces)
    }

    /// Check if two base names match
    private static func namesMatchBase(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        if a.contains(b) || b.contains(a) { return true }
        // Token match
        let tokA = a.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 3 }
        let tokB = b.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 3 }
        for t in tokA { if tokB.contains(t) { return true } }
        // Retina / intégré
        if a.contains("retina") && b.contains("retina") { return true }
        if (a.contains("built-in") || a.contains("built in")) && (b.contains("intégré") || b.contains("integre")) { return true }
        if (a.contains("intégré") || a.contains("integre")) && (b.contains("built-in") || b.contains("built in")) { return true }
        return false
    }
    
    /// Apply tiles immediately to visible desktops — no AppleScript, no Dock restart.
    /// Used for real-time preview (fit/anchor changes).
    static func applyQuick(tiles: [SplitTile], screenInfos: [ScreenInfo], format: String = "png") {
        let nsScreens = NSScreen.screens
        let savedURLs = saveTilesToDisk(tiles: tiles, format: format)
        guard savedURLs.count == tiles.count else { return }

        for (i, tile) in tiles.enumerated() {
            guard let screenInfo = screenInfos.first(where: { $0.id == tile.screenId }),
                  let nsIndex = screenInfo.nsScreenIndex,
                  nsIndex < nsScreens.count
            else { continue }
            try? NSWorkspace.shared.setDesktopImageURL(savedURLs[i], for: nsScreens[nsIndex], options: [:])
        }
    }

    private static func saveTilesToDisk(tiles: [SplitTile], format: String) -> [URL] {
        let dir = wallpaperDirectory
        if let c = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for f in c { try? FileManager.default.removeItem(at: f) }
        }
        // Nom unique à chaque application : force macOS à recharger l'image depuis le
        // disque plutôt que d'utiliser son cache, même pour les écrans couverts par
        // une appli plein écran dont le fond d'écran n'était pas visible.
        let stamp = Int(Date().timeIntervalSince1970)
        return WallSplitService.exportTiles(tiles, to: dir, format: format, baseName: "wallpaper_\(stamp)")
    }
    
    enum WallpaperError: LocalizedError {
        case noScreens, saveFailed, applyFailed
        var errorDescription: String? {
            switch self {
            case .noScreens: return "No screens detected."
            case .saveFailed: return "Failed to save wallpaper files."
            case .applyFailed: return "Could not match screens to desktops."
            }
        }
    }
}
