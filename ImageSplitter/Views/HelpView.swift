import SwiftUI

struct HelpView: View {
    @State private var selectedSection: HelpSection? = .gettingStarted
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            List(HelpSection.allCases, id: \.self, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.icon)
                    .font(.callout)
            }
            .listStyle(.sidebar)
            .frame(width: 190)

            Divider()

            // Content
            ScrollView {
                if let section = selectedSection {
                    section.content
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(28)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(width: 780, height: 600)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
    }
}

// MARK: - Sections

enum HelpSection: String, CaseIterable {
    case gettingStarted = "getting_started"
    case loadingImages  = "loading_images"
    case screens        = "screens"
    case fitModes       = "fit_modes"
    case anchor         = "anchor"
    case applying       = "applying"
    case library        = "library"
    case presets        = "presets"
    case browse         = "browse"
    case shortcuts      = "shortcuts"
    case troubleshoot   = "troubleshoot"

    var title: String {
        switch self {
        case .gettingStarted: return "Getting Started"
        case .loadingImages:  return "Loading Images"
        case .screens:        return "Screen Setup"
        case .fitModes:       return "Fit Modes"
        case .anchor:         return "Anchor Point"
        case .applying:       return "Apply Wallpapers"
        case .library:        return "Library"
        case .presets:        return "Presets"
        case .browse:         return "Browse Photos"
        case .shortcuts:      return "Shortcuts"
        case .troubleshoot:   return "Troubleshooting"
        }
    }

    var icon: String {
        switch self {
        case .gettingStarted: return "star.circle"
        case .loadingImages:  return "photo.badge.plus"
        case .screens:        return "display.2"
        case .fitModes:       return "aspectratio"
        case .anchor:         return "move.3d"
        case .applying:       return "desktopcomputer"
        case .library:        return "photo.stack"
        case .presets:        return "bookmark"
        case .browse:         return "photo.on.rectangle.angled"
        case .shortcuts:      return "keyboard"
        case .troubleshoot:   return "wrench.and.screwdriver"
        }
    }

    @ViewBuilder
    var content: some View {
        switch self {
        case .gettingStarted: GettingStartedContent()
        case .loadingImages:  LoadingImagesContent()
        case .screens:        ScreensContent()
        case .fitModes:       FitModesContent()
        case .anchor:         AnchorContent()
        case .applying:       ApplyingContent()
        case .library:        LibraryContent()
        case .presets:        PresetsContent()
        case .browse:         BrowseContent()
        case .shortcuts:      ShortcutsContent()
        case .troubleshoot:   TroubleshootContent()
        }
    }
}

// MARK: - Help content views

private struct GettingStartedContent: View {
    var body: some View {
        HelpPage(title: "Getting Started", icon: "star.circle.fill", iconColor: .yellow) {
            HelpParagraph(
                text: "ImageSplitter takes a single image and splits it precisely across all your monitors, so the image looks seamless across your whole desk."
            )

            HelpSteps(steps: [
                ("photo.badge.plus",  "accent",   "Load an image", "Drag & drop, press ⌘O, or paste with ⌘V."),
                ("display.2",         "blue",     "Screens detected", "ImageSplitter automatically detects all connected monitors."),
                ("aspectratio",       "orange",   "Choose a fit mode", "Letterbox keeps the full image visible. Fill crops to cover every screen."),
                ("desktopcomputer",   "green",    "Apply", "Press ⌘⇧↵ or click the Apply Wallpapers button."),
            ])

            HelpNote(text: "Your current wallpapers are automatically backed up in the Library every time you apply new ones.")
        }
    }
}

private struct LoadingImagesContent: View {
    var body: some View {
        HelpPage(title: "Loading an Image", icon: "photo.badge.plus", iconColor: .blue) {
            HelpSection2(title: "Drag & Drop") {
                HelpParagraph(text: "Drag any image file from Finder directly onto the app window. Supports PNG, JPEG, TIFF, HEIC, BMP, and WebP.")
            }
            HelpSection2(title: "Open File (⌘O)") {
                HelpParagraph(text: "Use File → Open Image… or press ⌘O to open the standard file picker.")
            }
            HelpSection2(title: "Paste from Clipboard (⌘V)") {
                HelpParagraph(text: "Copy any image (e.g. screenshot with ⌘⇧4) and paste it directly into the app. The image is imported at full resolution.")
            }
            HelpSection2(title: "Browse Unsplash / Pexels") {
                HelpParagraph(text: "Use the Browse tab to search millions of free high-resolution wallpapers. Click \"Use as Wallpaper\" on any photo to import it directly.")
            }
            HelpNote(text: "After loading, ImageSplitter immediately generates a preview split across your screens. Nothing is changed on your desktop until you click Apply.")
        }
    }
}

private struct ScreensContent: View {
    var body: some View {
        HelpPage(title: "Screen Setup", icon: "display.2", iconColor: .blue) {
            HelpSection2(title: "Auto-detection") {
                HelpParagraph(text: "Screens are automatically detected when the app launches. Click Refresh Screens (⌘⇧R) whenever you plug in or unplug a monitor.")
            }
            HelpSection2(title: "Reorder screens") {
                HelpParagraph(text: "Drag screens in the main preview to match your physical arrangement. The positions are used to calculate which part of the image each screen receives.")
            }
            HelpSection2(title: "Edit screen properties") {
                HelpParagraph(text: "Click the pencil icon on a screen row in the sidebar to edit its name, width, height, and X/Y position. Useful if macOS reports wrong dimensions.")
            }
            HelpSection2(title: "Virtual screens") {
                HelpParagraph(text: "Add virtual screens with the + button to simulate setups before buying hardware, or to create multi-panel art installations.")
            }
            HelpSection2(title: "Desktop mapping") {
                HelpParagraph(text: "ImageSplitter automatically maps each NSScreen to the correct System Events desktop by matching their names. If the mapping is wrong, use the \"Test Mapping\" button to generate numbered test images, then swap external screens or set a manual override.")
            }
        }
    }
}

private struct FitModesContent: View {
    var body: some View {
        HelpPage(title: "Fit Modes", icon: "aspectratio", iconColor: .orange) {
            HelpParagraph(text: "The fit mode controls how the image is scaled and cropped across the combined bounding box of all screens.")

            HelpFitModeRow(
                icon: "rectangle.compress.vertical",
                name: "Letterbox (Fit)",
                color: .blue,
                description: "The entire image is visible. The image is scaled so it fits within the screen layout without cropping. Empty areas outside the image are filled with black. Use this when you don't want any part of the image cut off — every screen will show a portion of the complete image.",
                badge: "Default"
            )

            HelpFitModeRow(
                icon: "rectangle.fill",
                name: "Fill",
                color: .orange,
                description: "The image is scaled to cover the full bounding box without any black bars. Some edges of the image may be cropped. Use this for full coverage with no gaps. The Anchor Point controls which part of the image is kept visible when cropping occurs.",
                badge: nil
            )

            HelpFitModeRow(
                icon: "rectangle.dashed",
                name: "Stretch",
                color: .red,
                description: "The image is stretched (distorted) to exactly match the total screen width and height. Not recommended for photos with recognisable subjects, but can work well with abstract or gradient backgrounds.",
                badge: nil
            )

            HelpNote(text: "Tip: If you have a very wide multi-monitor setup (e.g. 3×16:9), look for images with a matching ratio in the Browse tab by enabling \"Match ratio\".")
        }
    }
}

private struct AnchorContent: View {
    var body: some View {
        HelpPage(title: "Anchor Point", icon: "move.3d", iconColor: .purple) {
            HelpParagraph(text: "In Fill mode, the image must be cropped to cover all screens. The anchor point controls which part of the image is preserved (i.e. \"kept in view\") when the image is larger than the screen layout.")

            HelpSection2(title: "The 3×3 grid") {
                HelpParagraph(text: "The toolbar shows a 3×3 grid of dots. Click any dot to set the anchor:")
                VStack(alignment: .leading, spacing: 4) {
                    ForEach([
                        "Top-left: preserves the top-left corner of the image.",
                        "Center (default): crops equally on all sides — the center of the image stays centered.",
                        "Bottom-right: preserves the bottom-right corner.",
                        "And so on for all 9 positions.",
                    ], id: \.self) { line in
                        HelpBullet(text: line)
                    }
                }
            }

            HelpSection2(title: "When does the anchor matter?") {
                HelpParagraph(text: "Only in Fill mode when the image aspect ratio does not exactly match your total screen ratio. In Letterbox mode, the anchor shifts which part of the background outside the image is visible (rarely noticeable).")
            }

            HelpNote(text: "Experiment freely — the preview updates live as you change the anchor.")
        }
    }
}

private struct ApplyingContent: View {
    var body: some View {
        HelpPage(title: "Applying Wallpapers", icon: "desktopcomputer", iconColor: .green) {
            HelpParagraph(text: "When you click Apply Wallpapers (⌘⇧↵), ImageSplitter:")

            VStack(alignment: .leading, spacing: 6) {
                HelpBullet(text: "Saves a backup of your current wallpapers to the Library.")
                HelpBullet(text: "Writes one image file per screen to ~/Library/Application Support/ImageSplitter/Wallpapers/.")
                HelpBullet(text: "Sets each screen's wallpaper via the native NSWorkspace API (immediate effect).")
                HelpBullet(text: "Also updates System Events desktops via AppleScript to cover additional virtual spaces.")
                HelpBullet(text: "Restarts the Dock after ~1 second to refresh wallpapers on all Mission Control spaces.")
            }
            .padding(.bottom, 8)

            HelpSection2(title: "Permissions required") {
                HelpParagraph(text: "The app needs Automation access to control System Events. On first use, macOS will ask for permission. If you denied it, go to:")
                HelpCode(text: "System Settings → Privacy & Security → Automation → ImageSplitter → System Events ✓")
            }

            HelpNote(text: "The Dock briefly disappears and reappears after applying — this is expected and necessary to refresh wallpapers on all spaces.")
        }
    }
}

private struct LibraryContent: View {
    var body: some View {
        HelpPage(title: "Library", icon: "photo.stack", iconColor: .indigo) {
            HelpParagraph(text: "The Library stores complete wallpaper sets so you can recall, rotate, or re-edit them at any time.")

            HelpSection2(title: "Saving to the library") {
                HelpBullet(text: "\"Save Split to Library\": saves the current split (one image per screen) plus the original source image.")
                HelpBullet(text: "\"Backup Current Wallpapers\": reads and copies whatever wallpapers are currently set on all desktops.")
                HelpBullet(text: "A backup is also created automatically every time you apply new wallpapers.")
            }

            HelpSection2(title: "Import Folder") {
                HelpParagraph(text: "Point ImageSplitter at a folder of images and it will split each one with the current settings and save them all as individual library sets. Useful for building a rotation library in bulk.")
            }

            HelpSection2(title: "Random & Auto-Rotate") {
                HelpBullet(text: "\"Random Wallpaper\": instantly applies a random set from the library.")
                HelpBullet(text: "The toggle + interval picker enables automatic rotation (every 15 min, 30 min, 1 h, 3 h, or daily).")
            }

            HelpSection2(title: "Load for editing (✏️)") {
                HelpParagraph(text: "Hover over a library set — if the original image was saved with it, a pencil button appears. Click it to reload the original image into the editor. You can then adjust the fit mode, anchor point, or screen layout and apply or save a new version.")
            }

            HelpNote(text: "Library sets are stored in ~/Library/Application Support/ImageSplitter/Library/. Each set has its own folder with the tile images, a thumbnail, and the original source image (when available).")
        }
    }
}

private struct PresetsContent: View {
    var body: some View {
        HelpPage(title: "Presets", icon: "bookmark", iconColor: .orange) {
            HelpParagraph(text: "Presets save your screen configuration — screen layout, fit mode, and output format — not the image itself. Use them when you frequently switch between different monitor arrangements.")

            HelpSection2(title: "Saving a preset (⌘S)") {
                HelpParagraph(text: "After configuring your screens and choosing a fit mode, press ⌘S or click \"Save Preset…\". Give it a name (e.g. \"Home 3 screens\" or \"Laptop only\"). If a source image is loaded, a bookmark to it is saved as well.")
            }

            HelpSection2(title: "Loading a preset") {
                HelpParagraph(text: "Double-click a preset in the sidebar or hover and click the load button. The screen layout, fit mode, and output format are restored. If the original image is still accessible, it is reloaded too.")
            }

            HelpNote(text: "Presets store screen positions, sizes, and names but not the split images. The Library is the right place to save complete wallpaper sets.")
        }
    }
}

private struct BrowseContent: View {
    var body: some View {
        HelpPage(title: "Browse Photos", icon: "photo.on.rectangle.angled", iconColor: .teal) {
            HelpParagraph(text: "The Browse tab lets you search and download free wallpapers from Unsplash and Pexels without leaving the app.")

            HelpSection2(title: "Setting up API keys") {
                HelpParagraph(text: "Both services require a free API key. Go to Settings (⌘,) → APIs and paste your keys:")
                VStack(alignment: .leading, spacing: 4) {
                    HelpBullet(text: "Unsplash: create a developer app at unsplash.com/developers. Use the Access Key.")
                    HelpBullet(text: "Pexels: request a free key at pexels.com/api. Approval is instant.")
                }
            }

            HelpSection2(title: "Searching") {
                HelpBullet(text: "Type any keyword and press ↵ or click Search.")
                HelpBullet(text: "Use the quick-tag buttons (Nature, Space, City…) for instant searches.")
                HelpBullet(text: "Click the shuffle button for random photos on the current topic.")
                HelpBullet(text: "Scroll to the bottom to load more results (infinite scroll).")
            }

            HelpSection2(title: "Ratio filter") {
                HelpParagraph(text: "Enable \"Match ratio\" to show only photos whose aspect ratio matches your total screen layout. A green badge marks matching photos. This is especially useful for ultra-wide or triple-monitor setups.")
            }

            HelpSection2(title: "Using a photo") {
                HelpParagraph(text: "Hover over any photo and click \"Use as Wallpaper\". The full-resolution image is downloaded and automatically loaded into the editor. You can then adjust settings and apply it.")
            }

            HelpNote(text: "Unsplash images are free to use under the Unsplash License. Pexels images are free to use under the Pexels License. Always credit the photographer when required.")
        }
    }
}

private struct ShortcutsContent: View {
    var body: some View {
        HelpPage(title: "Keyboard Shortcuts", icon: "keyboard", iconColor: .secondary) {
            VStack(spacing: 0) {
                ShortcutRow(keys: "⌘O",           action: "Open image…")
                ShortcutRow(keys: "⌘V",           action: "Paste image from clipboard")
                ShortcutRow(keys: "⌘⇧R",          action: "Refresh screens")
                ShortcutRow(keys: "⌘⇧↵",          action: "Apply wallpapers")
                ShortcutRow(keys: "⌘E",           action: "Export tiles to folder…")
                ShortcutRow(keys: "⌘S",           action: "Save preset…")
                ShortcutRow(keys: "⌘,",           action: "Settings (API keys)")
                ShortcutRow(keys: "⌘?",           action: "This help window")
                ShortcutRow(keys: "⌘W",           action: "Close window / panel")
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        }
    }
}

private struct TroubleshootContent: View {
    var body: some View {
        HelpPage(title: "Troubleshooting", icon: "wrench.and.screwdriver", iconColor: .gray) {

            HelpSection2(title: "Wallpaper doesn't update") {
                HelpBullet(text: "Make sure the app has Automation permission: System Settings → Privacy & Security → Automation → ImageSplitter → System Events ✓")
                HelpBullet(text: "The Dock restarts ~1 s after applying. Wait a moment.")
                HelpBullet(text: "Try clicking Apply Wallpapers a second time.")
                HelpBullet(text: "If only one screen doesn't update, use the \"Test Mapping\" button to verify that each screen maps to the right desktop number.")
            }

            HelpSection2(title: "Wrong screen gets the wrong tile") {
                HelpBullet(text: "Click \"Test Mapping\" in the Screen Setup panel. Numbered images appear on each screen — note which number appears on which physical monitor.")
                HelpBullet(text: "Use \"Swap External Screens\" if two identical monitors are swapped.")
                HelpBullet(text: "Or drag the screen tiles in the preview to match your physical arrangement, then press Refresh Screens.")
            }

            HelpSection2(title: "Screen not detected") {
                HelpBullet(text: "Click Refresh Screens (⌘⇧R).")
                HelpBullet(text: "Make sure your monitor is on and connected before clicking Refresh.")
                HelpBullet(text: "Add it manually with the + button and enter the correct resolution.")
            }

            HelpSection2(title: "Image looks stretched or has black bars") {
                HelpBullet(text: "Switch between Fill and Letterbox modes.")
                HelpBullet(text: "For Fill without black bars, make sure your image is wide enough to cover the combined ratio of all screens.")
                HelpBullet(text: "Use the \"Match ratio\" filter in Browse to find appropriately sized images.")
            }

            HelpSection2(title: "\"Could not read current wallpapers\" on backup") {
                HelpBullet(text: "On macOS 14+, system wallpaper files may be in a protected location. This is a known limitation — the backup feature may not work for wallpapers that were never set by ImageSplitter.")
            }

            HelpSection2(title: "API key error in Browse") {
                HelpBullet(text: "Make sure you copied the correct key (Unsplash Access Key, not Secret Key).")
                HelpBullet(text: "Check that your Pexels key is approved (approval is usually instant).")
                HelpBullet(text: "Rate limits: Unsplash free tier allows 50 requests/hour. Pexels allows 200/hour.")
            }
        }
    }
}

// MARK: - Reusable help components

private struct HelpPage<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.title2.weight(.semibold))
            }

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                content()
            }
        }
    }
}

private struct HelpSection2<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
            content()
        }
    }
}

private struct HelpParagraph: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct HelpBullet: View {
    let text: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•").font(.callout).foregroundStyle(.tertiary)
            Text(text).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct HelpNote: View {
    let text: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "lightbulb").font(.caption).foregroundStyle(.orange)
            Text(text).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.07)))
    }
}

private struct HelpCode: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption.monospaced())
            .foregroundStyle(.primary)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
    }
}

private struct HelpSteps: View {
    let steps: [(String, String, String, String)]  // icon, color, title, detail

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(colorFromName(step.1).opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: step.0)
                            .font(.callout)
                            .foregroundStyle(colorFromName(step.1))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(index + 1). \(step.2)")
                            .font(.callout.weight(.semibold))
                        Text(step.3)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
                .padding(.bottom, index < steps.count - 1 ? 12 : 0)
            }
        }
    }

    private func colorFromName(_ name: String) -> Color {
        switch name {
        case "accent": return .accentColor
        case "blue":   return .blue
        case "orange": return .orange
        case "green":  return .green
        default:       return .secondary
        }
    }
}

private struct HelpFitModeRow: View {
    let icon: String
    let name: String
    let color: Color
    let description: String
    let badge: String?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(name).font(.callout.weight(.semibold))
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(color))
                    }
                }
                Text(description)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.15), lineWidth: 1))
    }
}

private struct ShortcutRow: View {
    let keys: String
    let action: String

    var body: some View {
        HStack {
            Text(action)
                .font(.callout).foregroundStyle(.primary)
            Spacer()
            Text(keys)
                .font(.callout.monospaced().weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color(nsColor: .controlColor)))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.primary.opacity(0.12), lineWidth: 1))
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        Divider().padding(.horizontal, 14)
    }
}
