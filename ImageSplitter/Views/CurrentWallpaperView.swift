import SwiftUI
import AppKit
import UniformTypeIdentifiers

private let kScalingKey  = NSWorkspace.DesktopImageOptionKey(rawValue: "NSWorkspaceDesktopImageScalingKey")
private let kClippingKey = NSWorkspace.DesktopImageOptionKey(rawValue: "NSWorkspaceDesktopImageAllowClippingKey")

struct CurrentWallpaperView: View {

    struct Entry: Identifiable {
        let id = UUID()
        let screen: NSScreen
        let url: URL
        let image: NSImage?
        var fitMode: FitOption
    }

    enum FitOption: String, CaseIterable, Identifiable {
        case fill    = "Fill"
        case fit     = "Fit"
        case stretch = "Stretch"
        case center  = "Center"
        var id: String { rawValue }
    }

    @EnvironmentObject var viewModel: SplitterViewModel
    @State private var entries: [Entry] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Current Wallpaper")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button { load() } label: {
                    Image(systemName: "arrow.clockwise").font(.callout)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Refresh")
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 16)

            // Screen cards
            if entries.isEmpty {
                Text("No active wallpapers")
                    .font(.callout).foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            } else {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(entries.indices, id: \.self) { i in
                        WallpaperScreenCard(
                            entries: $entries,
                            index: i,
                            onFitChange: applyFit
                        )
                    }
                }
                .padding(.horizontal, 32)
            }

            Divider()
                .padding(.horizontal, 32)
                .padding(.vertical, 24)

            // Drop zone
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [10, 6])
                    )
                    .foregroundColor(
                        viewModel.isDragging
                            ? .accentColor
                            : .secondary.opacity(0.30)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                viewModel.isDragging
                                    ? Color.accentColor.opacity(0.06)
                                    : Color(nsColor: .controlBackgroundColor).opacity(0.3)
                            )
                    )

                VStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundStyle(.secondary)
                    VStack(spacing: 4) {
                        Text("Drop an image to split")
                            .font(.callout.weight(.medium))
                        Text("or")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Button("Browse…") { viewModel.openFilePicker() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
            .frame(height: 150)
            .padding(.horizontal, 32)
            .padding(.bottom, 28)
            .contentShape(Rectangle())
            .onTapGesture { viewModel.openFilePicker() }
            .onDrop(of: [.image, .fileURL], isTargeted: $viewModel.isDragging) {
                viewModel.handleDrop(providers: $0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { load() }
    }

    private func load() {
        entries = NSScreen.screens.compactMap { screen in
            guard let url = NSWorkspace.shared.desktopImageURL(for: screen) else { return nil }
            return Entry(
                screen: screen,
                url: url,
                image: NSImage(contentsOf: url),
                fitMode: readFit(for: screen)
            )
        }
    }

    private func readFit(for screen: NSScreen) -> FitOption {
        let opts = NSWorkspace.shared.desktopImageOptions(for: screen) ?? [:]
        let clipping = opts[kClippingKey] as? Bool ?? true
        if let num = opts[kScalingKey] as? NSNumber {
            switch NSImageScaling(rawValue: num.uintValue) {
            case .scaleAxesIndependently:      return .stretch
            case .scaleNone:                   return .center
            case .scaleProportionallyUpOrDown: return clipping ? .fill : .fit
            default:                           return .fill
            }
        }
        return .fill
    }

    private func applyFit(_ fit: FitOption, screen: NSScreen, url: URL) {
        var opts: [NSWorkspace.DesktopImageOptionKey: Any] = [:]
        switch fit {
        case .fill:
            opts[kScalingKey]  = NSNumber(value: NSImageScaling.scaleProportionallyUpOrDown.rawValue)
            opts[kClippingKey] = true
        case .fit:
            opts[kScalingKey]  = NSNumber(value: NSImageScaling.scaleProportionallyUpOrDown.rawValue)
            opts[kClippingKey] = false
        case .stretch:
            opts[kScalingKey]  = NSNumber(value: NSImageScaling.scaleAxesIndependently.rawValue)
        case .center:
            opts[kScalingKey]  = NSNumber(value: NSImageScaling.scaleNone.rawValue)
            opts[kClippingKey] = false
        }
        try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: opts)
    }
}

private struct WallpaperScreenCard: View {
    @Binding var entries: [CurrentWallpaperView.Entry]
    let index: Int
    let onFitChange: (CurrentWallpaperView.FitOption, NSScreen, URL) -> Void

    var entry: CurrentWallpaperView.Entry { entries[index] }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            Group {
                if let img = entry.image {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )

            Text(entry.screen.localizedName)
                .font(.callout.weight(.medium))
                .lineLimit(1)

            Picker("", selection: Binding(
                get: { entries[index].fitMode },
                set: { newFit in
                    let screen = entries[index].screen
                    let url    = entries[index].url
                    entries[index].fitMode = newFit
                    onFitChange(newFit, screen, url)
                }
            )) {
                ForEach(CurrentWallpaperView.FitOption.allCases) { opt in
                    Text(opt.rawValue).tag(opt)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
    }
}
