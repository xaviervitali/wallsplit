import AppKit

class WallpaperService {
    
    static var wallpaperDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ImageSplitter/Wallpapers", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    static var presetsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ImageSplitter/Presets", isDirectory: true)
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

        // Pass 2: System Events — couvre TOUS les Spaces de chaque écran,
        // y compris les bureaux virtuels supplémentaires.
        // Pour les écrans en plein écran, met à jour le bureau caché derrière
        // l'app : le changement sera visible dès la sortie du plein écran.
        let desktopNames = getDesktopNames()
        print("📋 SE desktops: \(desktopNames)")
        var scriptLines: [String] = ["tell application \"System Events\""]

        for (dIdx, dName) in desktopNames.enumerated() {
            let dNum = dIdx + 1
            let dBase = baseName(dName)

            for (tileIndex, tile) in tiles.enumerated() {
                guard let sInfo = screenInfos.first(where: { $0.id == tile.screenId }),
                      let nsIdx = sInfo.nsScreenIndex, nsIdx < nsScreens.count else { continue }
                let screenBase = baseName(nsScreens[nsIdx].localizedName)
                if namesMatchBase(dBase, screenBase) {
                    let fileURL = savedURLs[tileIndex]
                    scriptLines.append("    tell desktop \(dNum)")
                    scriptLines.append("        set picture to \"\(fileURL.path)\"")
                    scriptLines.append("    end tell")
                    print("🖥️ Desktop \(dNum) (\(dName)) → \(fileURL.lastPathComponent)")
                    break
                }
            }
        }

        scriptLines.append("end tell")
        _ = runAppleScript(scriptLines.joined(separator: "\n"))

        // Redémarrer le Dock pour propager les changements à tous les Spaces
        if appliedCount > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
                p.arguments = ["Dock"]
                try? p.run()
                p.waitUntilExit()
                print("✅ Dock restarted")
            }
        }

        let result = ApplyResult(applied: appliedCount, skipped: skippedCount)
        return (appliedCount + skippedCount) > 0 ? .success(result) : .failure(.applyFailed)
    }
    
    // MARK: - Test Mapping
    
    /// Generate numbered test images and apply them to identify which desktop is which
    static func testMapping() {
        let nsScreens = NSScreen.screens
        let desktopNames = getDesktopNames()
        let mapping = buildDesktopMapping(nsScreens: nsScreens, desktopNames: desktopNames)
        
        print("🧪 Testing mapping: \(mapping)")
        print("🧪 Desktops: \(desktopNames)")
        
        var scriptLines: [String] = []
        
        // Generate a test image for each desktop
        let tempDir = URL(fileURLWithPath: "/tmp/ImageSplitter_test")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Finder amorce
        let amorcePath = tempDir.appendingPathComponent("amorce.png")
        generateTestImage(number: 0, label: "TEST", size: NSSize(width: 800, height: 600), saveTo: amorcePath)
        
        scriptLines.append("tell application \"Finder\"")
        scriptLines.append("    set desktop picture to POSIX file \"\(amorcePath.path)\"")
        scriptLines.append("end tell")
        scriptLines.append("delay 1")
        scriptLines.append("tell application \"System Events\"")
        
        for (nsIdx, _) in nsScreens.enumerated() {
            guard let dNum = mapping[nsIdx] else { continue }
            let screen = nsScreens[nsIdx]
            let label = "Desktop \(dNum)\n\(screen.localizedName)\nNSScreen[\(nsIdx)]"
            
            let imgPath = tempDir.appendingPathComponent("test_\(dNum).png")
            let size = NSSize(width: screen.frame.width * screen.backingScaleFactor,
                            height: screen.frame.height * screen.backingScaleFactor)
            generateTestImage(number: dNum, label: label, size: size, saveTo: imgPath)
            
            scriptLines.append("    tell desktop \(dNum)")
            scriptLines.append("        set picture to \"\(imgPath.path)\"")
            scriptLines.append("    end tell")
        }
        
        scriptLines.append("end tell")
        
        let script = scriptLines.joined(separator: "\n")
        _ = runAppleScript(script)
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            p.arguments = ["Dock"]
            try? p.run()
            p.waitUntilExit()
        }
    }
    
    /// Generate a test image with a big number and label
    private static func generateTestImage(number: Int, label: String, size: NSSize, saveTo url: URL) {
        let colors: [NSColor] = [.systemBlue, .systemRed, .systemGreen, .systemOrange, .systemPurple, .systemTeal]
        let color = colors[number % colors.count]
        
        let image = NSImage(size: size)
        image.lockFocus()
        
        // Background
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Big number
        let numStr = "\(number)" as NSString
        let numFont = NSFont.systemFont(ofSize: size.height * 0.5, weight: .bold)
        let numAttrs: [NSAttributedString.Key: Any] = [
            .font: numFont,
            .foregroundColor: NSColor.white
        ]
        let numSize = numStr.size(withAttributes: numAttrs)
        numStr.draw(at: NSPoint(x: (size.width - numSize.width) / 2, y: (size.height - numSize.height) / 2 + size.height * 0.05),
                   withAttributes: numAttrs)
        
        // Label text below
        let labelStr = label as NSString
        let labelFont = NSFont.systemFont(ofSize: size.height * 0.04, weight: .medium)
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.8)
        ]
        let labelSize = labelStr.size(withAttributes: labelAttrs)
        labelStr.draw(at: NSPoint(x: (size.width - labelSize.width) / 2, y: size.height * 0.08),
                     withAttributes: labelAttrs)
        
        image.unlockFocus()
        
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let rep = NSBitmapImageRep(cgImage: cgImage)
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
    
    // MARK: - Helpers
    
    static func getDesktopNames() -> [String] {
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
    
    private static func runAppleScript(_ source: String) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", source]
        let err = Pipe(); p.standardError = err
        do {
            try p.run(); p.waitUntilExit()
            if p.terminationStatus != 0 {
                let d = err.fileHandleForReading.readDataToEndOfFile()
                print("⚠️ osascript: \(String(data: d, encoding: .utf8) ?? "")")
                return false
            }
            return true
        } catch { return false }
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
        return ImageSplitterService.exportTiles(tiles, to: dir, format: format, baseName: "wallpaper_\(stamp)")
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
