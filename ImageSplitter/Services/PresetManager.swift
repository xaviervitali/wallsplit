import SwiftUI
import Combine

struct Preset: Identifiable, Codable {
    let id: UUID
    var name: String
    var createdAt: Date
    var screens: [ScreenInfo]
    var fitMode: String
    var imageFilename: String?

    var screenCount: Int { screens.count }
    var displayDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: createdAt)
    }
}

class PresetManager: ObservableObject {
    @Published var presets: [Preset] = []

    private var presetsFileURL: URL {
        WallpaperService.presetsDirectory.appendingPathComponent("presets_v2.json")
    }

    private var imagesDir: URL {
        let dir = WallpaperService.presetsDirectory.appendingPathComponent("Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    init() { loadPresets() }

    // MARK: - Save

    func savePreset(
        name: String,
        screens: [ScreenInfo],
        fitMode: ImageSplitterService.FitMode,
        sourceImage: NSImage? = nil,
        sourceImageURL: URL? = nil
    ) {
        let presetId = UUID()
        let imageFilename = saveImage(id: presetId, sourceImage: sourceImage, sourceImageURL: sourceImageURL)

        let preset = Preset(
            id: presetId,
            name: name,
            createdAt: Date(),
            screens: screens,
            fitMode: fitMode.rawValue,
            imageFilename: imageFilename
        )
        presets.insert(preset, at: 0)
        persistPresets()
    }

    private func saveImage(id: UUID, sourceImage: NSImage?, sourceImageURL: URL?) -> String? {
        // Prefer copying from the original file (preserves format and quality)
        if let srcURL = sourceImageURL, FileManager.default.fileExists(atPath: srcURL.path) {
            let ext = srcURL.pathExtension.isEmpty ? "png" : srcURL.pathExtension
            let filename = "\(id.uuidString).\(ext)"
            let destURL = imagesDir.appendingPathComponent(filename)
            if (try? FileManager.default.copyItem(at: srcURL, to: destURL)) != nil {
                return filename
            }
        }
        // Fallback: encode NSImage as PNG
        if let image = sourceImage,
           let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let filename = "\(id.uuidString).png"
            let destURL = imagesDir.appendingPathComponent(filename)
            let rep = NSBitmapImageRep(cgImage: cgImage)
            if let data = rep.representation(using: .png, properties: [:]),
               (try? data.write(to: destURL, options: .atomic)) != nil {
                return filename
            }
        }
        return nil
    }

    // MARK: - Load image

    func imageURL(for preset: Preset) -> URL? {
        guard let filename = preset.imageFilename else { return nil }
        let url = imagesDir.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Delete

    func deletePreset(id: UUID) {
        if let preset = presets.first(where: { $0.id == id }),
           let filename = preset.imageFilename {
            try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(filename))
        }
        presets.removeAll { $0.id == id }
        persistPresets()
    }

    // MARK: - Persistence

    func loadPresets() {
        guard FileManager.default.fileExists(atPath: presetsFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: presetsFileURL)
            presets = try JSONDecoder().decode([Preset].self, from: data)
        } catch {
            print("Presets load error: \(error.localizedDescription)")
        }
    }

    private func persistPresets() {
        do {
            let data = try JSONEncoder().encode(presets)
            try data.write(to: presetsFileURL, options: .atomic)
        } catch {
            print("Presets save error: \(error.localizedDescription)")
        }
    }
}
