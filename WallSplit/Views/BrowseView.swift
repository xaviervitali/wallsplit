import SwiftUI
import UniformTypeIdentifiers

// MARK: - Masonry layout

struct MasonryLayout: Layout {
    var minimumColumnWidth: CGFloat
    var spacing: CGFloat = 12

    private func safeCols(for width: CGFloat) -> Int {
        guard width.isFinite, width > 0, minimumColumnWidth > 0 else { return 1 }
        let raw = width / minimumColumnWidth
        guard raw.isFinite else { return 1 }
        return max(1, Int(raw))
    }

    private func compute(subviews: Subviews, totalWidth: CGFloat)
        -> (placements: [(x: CGFloat, y: CGFloat, h: CGFloat)], totalHeight: CGFloat)
    {
        guard totalWidth.isFinite, totalWidth > 0 else { return ([], 0) }
        let cols = safeCols(for: totalWidth)
        let colW = max(1, (totalWidth - spacing * CGFloat(cols - 1)) / CGFloat(cols))
        var colHeights = [CGFloat](repeating: 0, count: cols)
        var result: [(CGFloat, CGFloat, CGFloat)] = []
        for subview in subviews {
            let idx = colHeights.indices.min(by: { colHeights[$0] < colHeights[$1] }) ?? 0
            let h = subview.sizeThatFits(.init(width: colW, height: nil)).height
            guard h.isFinite else { continue }
            result.append((CGFloat(idx) * (colW + spacing), colHeights[idx], h))
            colHeights[idx] += h + spacing
        }
        return (result, max(0, (colHeights.max() ?? 0) - spacing))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let width = proposal.width ?? 0
        guard width.isFinite else { return .zero }
        let (_, h) = compute(subviews: subviews, totalWidth: width)
        return CGSize(width: width, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty, bounds.width.isFinite, bounds.width > 0 else { return }
        let cols = safeCols(for: bounds.width)
        let colW = max(1, (bounds.width - spacing * CGFloat(cols - 1)) / CGFloat(cols))
        let (placements, _) = compute(subviews: subviews, totalWidth: bounds.width)
        for (i, subview) in subviews.enumerated() {
            guard i < placements.count else { break }
            let p = placements[i]
            subview.place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y),
                          proposal: .init(width: colW, height: p.h))
        }
    }
}

// MARK: - Photo source

enum PhotoSource: String, CaseIterable {
    case myPresets = "My Presets"
    case unsplash  = "Unsplash"
    case pexels    = "Pexels"
    case wallhaven = "Wallhaven"
    case pixabay   = "Pixabay"
    case nasaApod  = "NASA"
    case pinterest = "Pinterest"
    case files     = "My Medias"

    var icon: String {
        switch self {
        case .myPresets:  return "star.fill"
        case .unsplash:   return "camera.aperture"
        case .pexels:     return "photo.artframe"
        case .wallhaven:  return "rectangle.stack.fill"
        case .pixabay:    return "photo.fill"
        case .nasaApod:   return "sparkles"
        case .pinterest:  return "pin.fill"
        case .files:      return "folder"
        }
    }

    /// Pro feature gate
    var requiresPro: Bool {
        switch self {
        case .myPresets, .files: return false
        default: return true
        }
    }

    var apiSettingsKey: String {
        switch self {
        case .unsplash:  return "unsplashAccessKey"
        case .pexels:    return "pexelsApiKey"
        case .pixabay:   return "pixabayApiKey"
        case .pinterest: return "pinterestAccessToken"
        default:         return ""
        }
    }

    var developerURL: URL {
        switch self {
        case .unsplash:  return URL(string: "https://unsplash.com/developers")!
        case .pexels:    return URL(string: "https://www.pexels.com/api/")!
        case .pixabay:   return URL(string: "https://pixabay.com/api/docs/")!
        case .nasaApod:  return URL(string: "https://api.nasa.gov/")!
        case .pinterest: return URL(string: "https://developers.pinterest.com/")!
        default:         return URL(string: "https://www.apple.com")!
        }
    }
}

// MARK: - Unified photo model

struct BrowsablePhoto: Identifiable {
    let id: String
    let width: Int
    let height: Int
    let colorHex: String
    let description: String?
    let authorName: String
    let thumbnailURL: String
    let source: PhotoSource

    var photoAspectRatio: CGFloat {
        guard height > 0 else { return 16.0 / 9.0 }
        return CGFloat(width) / CGFloat(height)
    }
}

// MARK: - Photo model conversions

extension UnsplashPhoto {
    func toBrowsable() -> BrowsablePhoto {
        BrowsablePhoto(
            id: "u_\(id)",
            width: width, height: height,
            colorHex: color ?? "#808080",
            description: alt_description ?? description,
            authorName: user.name,
            thumbnailURL: urls.small,
            source: .unsplash
        )
    }
}

extension PexelsPhoto {
    func toBrowsable() -> BrowsablePhoto {
        BrowsablePhoto(
            id: "p_\(id)",
            width: width, height: height,
            colorHex: avg_color ?? "#808080",
            description: alt,
            authorName: photographer,
            thumbnailURL: src.small,
            source: .pexels
        )
    }
}

extension WallhavenPhoto {
    func toBrowsable() -> BrowsablePhoto {
        BrowsablePhoto(
            id: "wh_\(id)",
            width: dimension_x, height: dimension_y,
            colorHex: "#808080",
            description: nil,
            authorName: "Wallhaven",
            thumbnailURL: thumbs.large,
            source: .wallhaven
        )
    }
}

extension PixabayPhoto {
    func toBrowsable() -> BrowsablePhoto {
        BrowsablePhoto(
            id: "px_\(id)",
            width: imageWidth, height: imageHeight,
            colorHex: "#808080",
            description: tags.isEmpty ? nil : tags,
            authorName: user,
            thumbnailURL: previewURL,
            source: .pixabay
        )
    }
}

extension NASAAPODPhoto {
    func toBrowsable() -> BrowsablePhoto {
        BrowsablePhoto(
            id: "nasa_\(date)",
            width: 3840, height: 2160,   // placeholder — actual size unknown from API
            colorHex: "#0d1b2a",
            description: title,
            authorName: "NASA",
            thumbnailURL: url,
            source: .nasaApod
        )
    }
}

// MARK: - BrowseView

struct BrowseView: View {
    @EnvironmentObject var viewModel: SplitterViewModel
    @ObservedObject private var proManager = ProManager.shared
    var onImageLoaded: (() -> Void)? = nil

    @StateObject private var unsplash  = UnsplashService()
    @StateObject private var pexels    = PexelsService()
    @StateObject private var wallhaven = WallhavenService()
    @StateObject private var pixabay   = PixabayService()
    @StateObject private var nasaApod  = NASAAPODService()
    @StateObject private var pinterest = PinterestService()

    @State private var selectedSource: PhotoSource = .myPresets
    @State private var searchText = ""
    @State private var downloadingId: String?
    @State private var filterByRatio = false
    @AppStorage("browseCardSize") private var cardSize: Double = 220

    // MARK: Helpers

    private var screenRatio: CGFloat {
        let bb = viewModel.screenManager.boundingBox
        guard bb.height > 0 else { return 16.0 / 9.0 }
        return bb.width / bb.height
    }

    private var ratioString: String {
        let r = screenRatio
        if abs(r - 48.0/9.0)  < 0.30 { return "48:9 (triple wide)" }
        if abs(r - 32.0/9.0)  < 0.20 { return "32:9 (super ultra-wide)" }
        if abs(r - 21.0/9.0)  < 0.15 { return "21:9 (ultra-wide)" }
        if abs(r - 16.0/9.0)  < 0.10 { return "16:9" }
        if abs(r - 16.0/10.0) < 0.10 { return "16:10" }
        return String(format: "%.1f:1", r)
    }

    private var minResolution: String {
        let bb = viewModel.screenManager.boundingBox
        let maxBacking = viewModel.screenManager.screens.map(\.backingScale).max() ?? 1.0
        return "\(Int(bb.width * maxBacking))×\(Int(bb.height * maxBacking))"
    }

    private func matchesRatio(_ photo: BrowsablePhoto) -> Bool {
        abs(photo.photoAspectRatio - screenRatio) < 0.4
    }

    // MARK: Computed photos

    private var allPhotos: [BrowsablePhoto] {
        switch selectedSource {
        case .unsplash:  return unsplash.photos.map  { $0.toBrowsable() }
        case .pexels:    return pexels.photos.map    { $0.toBrowsable() }
        case .wallhaven: return wallhaven.photos.map { $0.toBrowsable() }
        case .pixabay:   return pixabay.photos.map   { $0.toBrowsable() }
        case .nasaApod:  return nasaApod.photos.map  { $0.toBrowsable() }
        default:         return []
        }
    }

    private var displayedPhotos: [BrowsablePhoto] {
        filterByRatio ? allPhotos.filter { matchesRatio($0) } : allPhotos
    }

    private var isLoading: Bool {
        switch selectedSource {
        case .unsplash:  return unsplash.isLoading
        case .pexels:    return pexels.isLoading
        case .wallhaven: return wallhaven.isLoading
        case .pixabay:   return pixabay.isLoading
        case .nasaApod:  return nasaApod.isLoading
        case .pinterest: return pinterest.isLoading
        default:         return false
        }
    }

    private var errorMessage: String? {
        switch selectedSource {
        case .unsplash:  return unsplash.errorMessage
        case .pexels:    return pexels.errorMessage
        case .wallhaven: return wallhaven.errorMessage
        case .pixabay:   return pixabay.errorMessage
        case .nasaApod:  return nasaApod.errorMessage
        case .pinterest: return pinterest.errorMessage
        default:         return nil
        }
    }

    private var hasApiKey: Bool {
        switch selectedSource {
        case .unsplash:  return unsplash.hasApiKey
        case .pexels:    return pexels.hasApiKey
        case .wallhaven: return wallhaven.hasApiKey
        case .pixabay:   return pixabay.hasApiKey
        case .nasaApod:  return nasaApod.hasApiKey
        case .pinterest: return pinterest.hasApiKey
        default:         return true
        }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            // Source picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(PhotoSource.allCases, id: \.self) { source in
                        Button {
                            if source.requiresPro && !proManager.isPro {
                                viewModel.showUpgradeSheet = true
                            } else {
                                selectedSource = source
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Label(source.rawValue, systemImage: source.icon)
                                    .font(.callout.weight(selectedSource == source ? .semibold : .regular))
                                if source.requiresPro && !proManager.isPro {
                                    ProBadge()
                                }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(selectedSource == source
                                ? Color.accentColor.opacity(0.12)
                                : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(selectedSource == source ? Color.accentColor : .secondary)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "square.grid.3x3").font(.caption2).foregroundStyle(.tertiary)
                        Slider(value: $cardSize, in: 140...420, step: 10).frame(width: 110)
                        Image(systemName: "square.grid.2x2").font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(.trailing, 4)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }

            Divider()

            switch selectedSource {
            case .myPresets:
                MyPresetsView(onImageLoaded: onImageLoaded).environmentObject(viewModel)
            case .files:
                FileBrowserView(onImageLoaded: onImageLoaded).environmentObject(viewModel)
            case .pinterest:
                PinterestBoardsView(service: pinterest, onImageLoaded: onImageLoaded)
                    .environmentObject(viewModel)
            default:
                onlineContent
            }
        }
    }

    // MARK: Online content (Unsplash / Pexels / Wallhaven / Pixabay / NASA)

    private var onlineContent: some View {
        VStack(spacing: 0) {
            // API key warning
            if !hasApiKey { apiKeyWarning }

            // Search bar (hidden for NASA since it has no search)
            if selectedSource != .nasaApod {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search wallpapers… (nature, city, abstract…)", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit { performSearch() }

                    if isLoading { ProgressView().controlSize(.small) }

                    Button("Search") { performSearch() }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                        .disabled(searchText.isEmpty || !hasApiKey)

                    Button {
                        performRandom()
                    } label: {
                        Image(systemName: "shuffle")
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                    .disabled(!hasApiKey)
                    .help("Random wallpapers")
                }
                .padding(.horizontal, 16).padding(.vertical, 10)

                // Screen info + ratio filter + quick tags
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "display.2").font(.caption2)
                        Text(ratioString).font(.caption.weight(.medium))
                        Text("·").font(.caption)
                        Text("min \(minResolution)").font(.caption2.monospaced())
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))

                    Toggle(isOn: $filterByRatio) {
                        Label("Match ratio", systemImage: "aspectratio").font(.caption)
                    }
                    .toggleStyle(.button).controlSize(.mini)

                    Divider().frame(height: 14)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(["Nature", "Space", "Ocean", "Mountains", "City",
                                     "Abstract", "Minimal", "Dark", "Forest", "Sunset"], id: \.self) { tag in
                                Button(tag) {
                                    searchText = tag.lowercased()
                                    performSearch()
                                }
                                .buttonStyle(.bordered).controlSize(.mini)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 8)

                Divider()
            } else {
                // NASA: just a "Refresh" button
                HStack {
                    Text("Astronomy Picture of the Day — random selection")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if isLoading { ProgressView().controlSize(.small) }
                    Button {
                        nasaApod.fetchRandom()
                    } label: {
                        Label("Load More", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                Divider()
            }

            // Error banner
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                    Text(error).font(.callout).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Color.orange.opacity(0.08))
            }

            // Photo grid
            if displayedPhotos.isEmpty && !isLoading {
                emptyState
            } else {
                ScrollView {
                    MasonryLayout(minimumColumnWidth: CGFloat(cardSize), spacing: 12) {
                        ForEach(displayedPhotos) { photo in
                            BrowsePhotoCard(
                                photo: photo,
                                isDownloading: downloadingId == photo.id,
                                matchesRatio: matchesRatio(photo)
                            ) {
                                downloadAndSplit(photo: photo)
                            }
                            .onAppear { triggerLoadMoreIfNeeded(photo: photo) }
                        }
                    }
                    .padding(16)

                    if isLoading && !allPhotos.isEmpty {
                        ProgressView("Loading more…").padding()
                    }
                }
            }
        }
        .onAppear {
            // Auto-load NASA APOD when switched to
            if selectedSource == .nasaApod && nasaApod.photos.isEmpty {
                nasaApod.fetchRandom()
            }
        }
    }

    // MARK: Sub-views

    private var apiKeyWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "key.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(selectedSource.rawValue) API Key Required")
                    .font(.callout.weight(.medium))
                Text("Get a free key, then paste it in Settings (⌘,)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Get Key") {
                NSWorkspace.shared.open(selectedSource.developerURL)
            }
            .buttonStyle(.bordered).controlSize(.small)
        }
        .padding(12)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16).padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            if allPhotos.isEmpty {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 40, weight: .ultraLight)).foregroundStyle(.tertiary)
                if selectedSource == .nasaApod {
                    Text("Click Refresh to load NASA photos")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    Text("Search for wallpapers on \(selectedSource.rawValue)")
                        .font(.callout).foregroundStyle(.secondary)
                    Text("Millions of free high-resolution photos")
                        .font(.caption).foregroundStyle(.tertiary)
                }
            } else {
                Image(systemName: "aspectratio").font(.title2).foregroundStyle(.tertiary)
                Text("No images match your screen ratio (\(ratioString))")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Show all") { filterByRatio = false }
                    .buttonStyle(.bordered).controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Actions

    private func performSearch() {
        switch selectedSource {
        case .unsplash:  unsplash.search(query: searchText)
        case .pexels:    pexels.search(query: searchText)
        case .wallhaven: wallhaven.search(query: searchText)
        case .pixabay:   pixabay.search(query: searchText)
        case .nasaApod:  nasaApod.fetchRandom()
        default: break
        }
    }

    private func performRandom() {
        let q = searchText.isEmpty ? nil : searchText
        switch selectedSource {
        case .unsplash:  unsplash.fetchRandom(topic: q)
        case .pexels:    pexels.fetchRandom(topic: q)
        case .wallhaven: wallhaven.fetchRandom(topic: q)
        case .pixabay:   pixabay.fetchRandom(topic: q)
        case .nasaApod:  nasaApod.fetchRandom()
        default: break
        }
    }

    private func triggerLoadMoreIfNeeded(photo: BrowsablePhoto) {
        guard photo.id == displayedPhotos.last?.id else { return }
        switch selectedSource {
        case .unsplash:  unsplash.loadMore()
        case .pexels:    pexels.loadMore()
        case .wallhaven: wallhaven.loadMore()
        case .pixabay:   pixabay.loadMore()
        default: break
        }
    }

    private func downloadAndSplit(photo: BrowsablePhoto) {
        downloadingId = photo.id
        let bb = viewModel.screenManager.boundingBox

        func finish(_ image: NSImage?, _ name: String) {
            downloadingId = nil
            guard let image else { return }
            viewModel.loadImage(image, name: name)
            viewModel.showPreviewOverlay = true
        }

        switch photo.source {
        case .unsplash:
            guard let orig = unsplash.photos.first(where: { "u_\($0.id)" == photo.id }) else {
                downloadingId = nil; return
            }
            let targetWidth = max(Int(bb.width), orig.width)
            unsplash.downloadImage(photo: orig, targetWidth: targetWidth) { img in
                let name = photo.description?.prefix(40).replacingOccurrences(of: " ", with: "_") ?? "unsplash_\(orig.id)"
                finish(img, String(name))
            }

        case .pexels:
            guard let orig = pexels.photos.first(where: { "p_\($0.id)" == photo.id }) else {
                downloadingId = nil; return
            }
            pexels.downloadImage(photo: orig) { img in
                let name = photo.description?.prefix(40).replacingOccurrences(of: " ", with: "_") ?? "pexels_\(orig.id)"
                finish(img, String(name))
            }

        case .wallhaven:
            guard let orig = wallhaven.photos.first(where: { "wh_\($0.id)" == photo.id }) else {
                downloadingId = nil; return
            }
            wallhaven.downloadImage(photo: orig) { img in
                finish(img, "wallhaven_\(orig.id)")
            }

        case .pixabay:
            guard let orig = pixabay.photos.first(where: { "px_\($0.id)" == photo.id }) else {
                downloadingId = nil; return
            }
            pixabay.downloadImage(photo: orig) { img in
                let name = photo.description?.prefix(40).replacingOccurrences(of: " ", with: "_") ?? "pixabay_\(orig.id)"
                finish(img, String(name))
            }

        case .nasaApod:
            guard let orig = nasaApod.photos.first(where: { "nasa_\($0.date)" == photo.id }) else {
                downloadingId = nil; return
            }
            nasaApod.downloadImage(photo: orig) { img in
                finish(img, photo.description ?? "nasa_\(orig.date)")
            }

        default:
            downloadingId = nil
        }
    }
}

// MARK: - Pinterest Boards View

struct PinterestBoardsView: View {
    @ObservedObject var service: PinterestService
    @EnvironmentObject var viewModel: SplitterViewModel
    var onImageLoaded: (() -> Void)?

    @State private var downloadingId: String?
    @AppStorage("browseCardSize") private var cardSize: Double = 220

    var body: some View {
        VStack(spacing: 0) {
            // API key warning
            if !service.hasApiKey {
                HStack(spacing: 8) {
                    Image(systemName: "key.fill").foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pinterest Access Token Required")
                            .font(.callout.weight(.medium))
                        Text("Get a personal access token at developers.pinterest.com, then paste in Settings (⌘,)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Get Token") {
                        NSWorkspace.shared.open(URL(string: "https://developers.pinterest.com/")!)
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                }
                .padding(12)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16).padding(.top, 8)
            }

            // Board picker
            if !service.boards.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(service.boards) { board in
                            Button {
                                service.selectBoard(board.id)
                            } label: {
                                HStack(spacing: 4) {
                                    Text(board.name).font(.callout)
                                    if let count = board.pin_count {
                                        Text("(\(count))").font(.caption2).foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(
                                    service.selectedBoardId == board.id
                                        ? Color.accentColor.opacity(0.12) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(service.selectedBoardId == board.id ? Color.accentColor : .primary)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                }
                Divider()
            }

            // Error
            if let error = service.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                    Text(error).font(.callout).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Color.orange.opacity(0.08))
            }

            // Loading / empty state
            if service.isLoading && service.pins.isEmpty {
                ProgressView("Loading boards…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if service.pins.isEmpty && !service.isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "pin.slash")
                        .font(.system(size: 40, weight: .ultraLight)).foregroundStyle(.tertiary)
                    if service.hasApiKey {
                        Text("No pins in this board")
                            .font(.callout).foregroundStyle(.secondary)
                        Button("Load Boards") { service.fetchBoards() }
                            .buttonStyle(.bordered).controlSize(.small)
                    } else {
                        Text("Add your Pinterest Access Token in Settings")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    MasonryLayout(minimumColumnWidth: CGFloat(cardSize), spacing: 12) {
                        ForEach(service.pins) { pin in
                            PinterestPinCard(
                                pin: pin,
                                isDownloading: downloadingId == pin.id
                            ) {
                                downloadPin(pin)
                            }
                            .onAppear {
                                if pin.id == service.pins.last?.id { service.loadMore() }
                            }
                        }
                    }
                    .padding(16)

                    if service.isLoading && !service.pins.isEmpty {
                        ProgressView("Loading more…").padding()
                    }
                }
            }
        }
        .onAppear {
            if service.hasApiKey && service.boards.isEmpty { service.fetchBoards() }
        }
    }

    private func downloadPin(_ pin: PinterestPin) {
        downloadingId = pin.id
        service.downloadImage(pin: pin) { image in
            self.downloadingId = nil
            guard let image else { return }
            let name = pin.title ?? pin.description ?? "pinterest_\(pin.id)"
            self.viewModel.loadImage(image, name: String(name.prefix(40)))
            self.viewModel.showPreviewOverlay = true
        }
    }
}

// MARK: - Pinterest Pin Card

struct PinterestPinCard: View {
    let pin: PinterestPin
    let isDownloading: Bool
    let onSelect: () -> Void

    @State private var thumbnail: NSImage?
    @State private var isHovering = false

    private var aspectRatio: CGFloat {
        let w = CGFloat(pin.media?.bestWidth ?? 1200)
        let h = CGFloat(pin.media?.bestHeight ?? 900)
        guard h > 0 else { return 4.0 / 3.0 }
        return w / h
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    if let thumb = thumbnail {
                        Image(nsImage: thumb).resizable().aspectRatio(contentMode: .fill).clipped()
                    } else {
                        Rectangle().fill(Color.secondary.opacity(0.15))
                            .overlay(ProgressView().controlSize(.small))
                    }
                    if isHovering {
                        Color.black.opacity(0.3)
                        if isDownloading {
                            ProgressView().controlSize(.regular).tint(.white)
                        } else {
                            Button { onSelect() } label: {
                                Label("Use as Wallpaper", systemImage: "desktopcomputer")
                                    .font(.callout.weight(.medium)).foregroundStyle(.white)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(.white.opacity(0.2), in: Capsule())
                            }.buttonStyle(.borderless)
                        }
                    }
                }
                .aspectRatio(aspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(5)
                    .background(Color.red.opacity(0.7), in: Circle())
                    .padding([.top, .leading], 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            if let title = pin.title ?? pin.description {
                Text(title)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    .padding(.horizontal, 4).padding(.top, 4)
            }
        }
        .onHover { isHovering = $0 }
        .onAppear { loadThumbnail() }
    }

    private func loadThumbnail() {
        guard thumbnail == nil,
              let urlStr = pin.media?.thumbnailURL,
              let url = URL(string: urlStr) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data, let img = NSImage(data: data) {
                DispatchQueue.main.async { thumbnail = img }
            }
        }.resume()
    }
}

// MARK: - Photo card

struct BrowsePhotoCard: View {
    let photo: BrowsablePhoto
    let isDownloading: Bool
    let matchesRatio: Bool
    let onSelect: () -> Void

    @State private var thumbnail: NSImage?
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                // Image
                ZStack {
                    if let thumb = thumbnail {
                        Image(nsImage: thumb).resizable().aspectRatio(contentMode: .fill)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color(hex: photo.colorHex).opacity(0.3))
                            .overlay(ProgressView().controlSize(.small))
                    }

                    if isHovering {
                        Color.black.opacity(0.3)
                        if isDownloading {
                            ProgressView().controlSize(.regular).tint(.white)
                        } else {
                            Button { onSelect() } label: {
                                Label("Use as Wallpaper", systemImage: "desktopcomputer")
                                    .font(.callout.weight(.medium)).foregroundStyle(.white)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(.white.opacity(0.2), in: Capsule())
                            }.buttonStyle(.borderless)
                        }
                    }
                }
                .aspectRatio(photo.photoAspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                // Ratio badge
                if matchesRatio {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark").font(.system(size: 8, weight: .bold))
                        Text("ratio").font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color.green.opacity(0.85), in: Capsule())
                    .padding(6)
                }

                // Source badge
                Image(systemName: photo.source.icon)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(5)
                    .background(Color.black.opacity(0.35), in: Circle())
                    .padding([.top, .leading], 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            // Info row
            HStack(spacing: 4) {
                if photo.width > 0 {
                    Text("\(photo.width)×\(photo.height)")
                        .font(.caption2.monospaced()).foregroundStyle(.tertiary)
                    Text(String(format: "(%.1f:1)", photo.photoAspectRatio))
                        .font(.system(size: 9).monospaced())
                        .foregroundStyle(matchesRatio ? .green : .gray)
                }
                Spacer()
                Text("by \(photo.authorName)")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(.horizontal, 4).padding(.top, 4)

            if let desc = photo.description {
                Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    .padding(.horizontal, 4).padding(.top, 1)
            }
        }
        .onHover { isHovering = $0 }
        .onAppear { loadThumbnail() }
    }

    private func loadThumbnail() {
        guard thumbnail == nil, let url = URL(string: photo.thumbnailURL) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data, let img = NSImage(data: data) {
                DispatchQueue.main.async { thumbnail = img }
            }
        }.resume()
    }
}

// MARK: - My Presets

private struct MyPresetsView: View {
    @EnvironmentObject var viewModel: SplitterViewModel
    let onImageLoaded: (() -> Void)?
    @AppStorage("browseCardSize") private var cardSize: Double = 220

    var body: some View {
        if viewModel.presetManager.presets.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "star.slash")
                    .font(.system(size: 40, weight: .ultraLight)).foregroundStyle(.tertiary)
                Text("No presets saved yet").font(.callout).foregroundStyle(.secondary)
                Text("Split an image then use \"Save Preset\" in the toolbar")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                MasonryLayout(minimumColumnWidth: CGFloat(cardSize), spacing: 12) {
                    ForEach(viewModel.presetManager.presets) { preset in
                        PresetCard(preset: preset) {
                            viewModel.loadPreset(preset)
                            onImageLoaded?()
                        }
                    }
                }
                .padding(16)
            }
        }
    }
}

private struct PresetCard: View {
    let preset: Preset
    let onSelect: () -> Void
    @EnvironmentObject var viewModel: SplitterViewModel
    @State private var thumbnail: NSImage?
    @State private var cardAspectRatio: CGFloat = 16.0 / 9.0
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail
            ZStack {
                if let thumb = thumbnail {
                    Image(nsImage: thumb).resizable().aspectRatio(contentMode: .fill)
                        .clipped()
                } else {
                    Rectangle().fill(.quaternary)
                        .overlay(Image(systemName: "star").font(.title2).foregroundStyle(.tertiary))
                }

                if isHovering {
                    Color.black.opacity(0.28)
                    Button { onSelect() } label: {
                        Label("Charger", systemImage: "arrow.down.circle")
                            .font(.callout.weight(.medium)).foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(.white.opacity(0.2), in: Capsule())
                    }.buttonStyle(.borderless)
                }
            }
            .aspectRatio(cardAspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture(count: 2) { onSelect() }

            // Info row
            HStack(alignment: .top, spacing: 4) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.name).font(.callout.weight(.semibold)).lineLimit(1)
                    HStack(spacing: 6) {
                        Label("\(preset.screenCount)", systemImage: "display")
                        Text("·")
                        Text(preset.fitMode)
                        Text("·")
                        Text(canvasRatio)
                    }
                    .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if isHovering {
                    Button {
                        viewModel.presetManager.deletePreset(id: preset.id)
                    } label: {
                        Image(systemName: "trash").font(.caption).foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 4).padding(.top, 6).padding(.bottom, 2)
        }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button { onSelect() } label: { Label("Charger", systemImage: "arrow.down.circle") }
            Divider()
            Button(role: .destructive) {
                viewModel.presetManager.deletePreset(id: preset.id)
            } label: { Label("Supprimer", systemImage: "trash") }
        }
        .onAppear { loadThumbnail() }
    }

    private var canvasRatio: String {
        guard !preset.screens.isEmpty else { return "" }
        let allFrames = preset.screens.map(\.frame)
        let bb = allFrames.reduce(allFrames[0]) { $0.union($1) }
        guard bb.height > 0 else { return "" }
        let r = bb.width / bb.height
        if abs(r - 48.0/9.0)  < 0.30 { return "48:9" }
        if abs(r - 32.0/9.0)  < 0.20 { return "32:9" }
        if abs(r - 21.0/9.0)  < 0.15 { return "21:9" }
        if abs(r - 16.0/9.0)  < 0.10 { return "16:9" }
        if abs(r - 16.0/10.0) < 0.10 { return "16:10" }
        return String(format: "%.1f:1", r)
    }

    private func loadThumbnail() {
        guard thumbnail == nil,
              let url = viewModel.presetManager.imageURL(for: preset) else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let img = NSImage(contentsOf: url) else { return }
            let ratio = img.size.width > 0 && img.size.height > 0
                ? img.size.width / img.size.height : 16.0 / 9.0
            DispatchQueue.main.async { thumbnail = img; cardAspectRatio = ratio }
        }
    }
}

// MARK: - File Browser

struct FileItem: Identifiable {
    let id = UUID()
    let url: URL
    let isDirectory: Bool

    var name: String { url.lastPathComponent }
    var isImage: Bool {
        let ext = url.pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "gif", "tiff", "tif", "heic", "webp", "bmp"].contains(ext)
    }
}

struct FileBrowserView: View {
    @EnvironmentObject var viewModel: SplitterViewModel
    var onImageLoaded: (() -> Void)? = nil

    @State private var currentURL: URL = FileManager.default.homeDirectoryForCurrentUser
    @State private var items: [FileItem] = []
    @State private var navigationStack: [URL] = []
    @State private var loadingURL: URL?
    @State private var customBookmarks: [Bookmark] = []
    @AppStorage("browseCardSize") private var cardSize: Double = 220

    private struct Bookmark: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let url: URL
    }

    private var bookmarks: [Bookmark] {
        let fm = FileManager.default
        var list: [Bookmark] = []
        if let u = fm.urls(for: .desktopDirectory,   in: .userDomainMask).first { list.append(.init(name: "Bureau",           icon: "menubar.dock.rectangle", url: u)) }
        if let u = fm.urls(for: .documentDirectory,  in: .userDomainMask).first { list.append(.init(name: "Documents",        icon: "doc.fill",               url: u)) }
        if let u = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first { list.append(.init(name: "Téléchargements",  icon: "arrow.down.circle.fill", url: u)) }
        if let u = fm.urls(for: .picturesDirectory,  in: .userDomainMask).first { list.append(.init(name: "Images",           icon: "photo.fill",             url: u)) }
        list.append(.init(name: "Dossier personnel", icon: "house.fill", url: fm.homeDirectoryForCurrentUser))
        return list
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 2) {
                Text("Emplacements")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                ForEach(bookmarks) { bm in
                    Button { navigate(to: bm.url, clearStack: true) } label: {
                        Label(bm.name, systemImage: bm.icon)
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(
                                currentURL == bm.url ? Color.accentColor.opacity(0.12) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(currentURL == bm.url ? Color.accentColor : .primary)
                    .padding(.horizontal, 4)
                }

                if !customBookmarks.isEmpty {
                    Divider().padding(.horizontal, 12).padding(.vertical, 4)

                    ForEach(customBookmarks) { bm in
                        HStack(spacing: 0) {
                            Button { navigate(to: bm.url, clearStack: true) } label: {
                                Label(bm.name, systemImage: bm.icon)
                                    .font(.callout)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(
                                        currentURL == bm.url ? Color.accentColor.opacity(0.12) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 6)
                                    )
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(currentURL == bm.url ? Color.accentColor : .primary)

                            Button { removeCustomBookmark(bm) } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.borderless)
                            .padding(.trailing, 6)
                        }
                        .padding(.horizontal, 4)
                    }
                }

                Button { addCustomBookmark() } label: {
                    Label("Ajouter un dossier…", systemImage: "plus.circle")
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

                Spacer()
            }
            .frame(width: 164)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Main pane
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Button {
                        if let parent = navigationStack.popLast() {
                            currentURL = parent
                            loadItems()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.borderless)
                    .disabled(navigationStack.isEmpty)

                    Image(systemName: "folder").foregroundStyle(.secondary)
                    Text(currentURL.lastPathComponent)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)

                    Spacer()

                    Button { openFilePicker() } label: {
                        Label("Choisir un fichier…", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)

                Divider()

                if items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 40, weight: .ultraLight))
                            .foregroundStyle(.tertiary)
                        Text("Aucune image dans ce dossier")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        MasonryLayout(minimumColumnWidth: CGFloat(cardSize), spacing: 8) {
                            ForEach(items) { item in
                                FileItemCell(
                                    item: item,
                                    isLoading: loadingURL == item.url
                                ) {
                                    if item.isDirectory {
                                        navigationStack.append(currentURL)
                                        navigate(to: item.url, clearStack: false)
                                    } else {
                                        useAsWallpaper(url: item.url)
                                    }
                                }
                            }
                        }
                        .padding(12)
                    }
                }
            }
        }
        .onAppear {
            if let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first {
                currentURL = pictures
            }
            loadCustomBookmarks()
            loadItems()
        }
    }

    private func loadCustomBookmarks() {
        let paths = UserDefaults.standard.stringArray(forKey: "customFolderBookmarks") ?? []
        customBookmarks = paths.compactMap { path in
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            return Bookmark(name: url.lastPathComponent, icon: "folder.fill", url: url)
        }
    }

    private func saveCustomBookmarks() {
        UserDefaults.standard.set(customBookmarks.map { $0.url.path }, forKey: "customFolderBookmarks")
    }

    private func addCustomBookmark() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.prompt = "Ajouter"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard !customBookmarks.contains(where: { $0.url == url }) else { return }
        customBookmarks.append(Bookmark(name: url.lastPathComponent, icon: "folder.fill", url: url))
        saveCustomBookmarks()
    }

    private func removeCustomBookmark(_ bookmark: Bookmark) {
        customBookmarks.removeAll { $0.id == bookmark.id }
        saveCustomBookmarks()
    }

    private func navigate(to url: URL, clearStack: Bool) {
        if clearStack { navigationStack.removeAll() }
        currentURL = url
        loadItems()
    }

    private func loadItems() {
        let imageExts: Set<String> = ["png", "jpg", "jpeg", "gif", "tiff", "tif", "heic", "webp", "bmp"]
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: currentURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { items = []; return }

        items = contents.compactMap { url in
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir { return FileItem(url: url, isDirectory: true) }
            if imageExts.contains(url.pathExtension.lowercased()) { return FileItem(url: url, isDirectory: false) }
            return nil
        }
        .sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        useAsWallpaper(url: url)
    }

    private func useAsWallpaper(url: URL) {
        guard loadingURL == nil else { return }
        loadingURL = url
        DispatchQueue.global(qos: .userInitiated).async {
            let image = NSImage(contentsOf: url)
            DispatchQueue.main.async {
                self.loadingURL = nil
                guard let image else { return }
                let name = (url.lastPathComponent as NSString).deletingPathExtension
                self.viewModel.loadImage(image, name: name)
                self.viewModel.applyCurrentTiles()
                self.onImageLoaded?()
            }
        }
    }
}

// MARK: - File item cell

struct FileItemCell: View {
    let item: FileItem
    let isLoading: Bool
    let onSelect: () -> Void

    @State private var thumbnail: NSImage?
    @State private var imagePixelSize: CGSize?
    @State private var cellAspectRatio: CGFloat = 4.0 / 3.0
    @State private var isHovering = false

    var body: some View {
        ZStack {
            if item.isDirectory {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
                VStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.yellow.opacity(0.75))
                    Text(item.name)
                        .font(.caption).lineLimit(2).multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 6)
                }
            } else {
                if let thumb = thumbnail {
                    Image(nsImage: thumb)
                        .resizable().aspectRatio(contentMode: .fill).clipped()
                } else {
                    Color.secondary.opacity(0.15)
                        .overlay(ProgressView().controlSize(.small))
                }
            }

            if isHovering || isLoading {
                Color.black.opacity(0.35)
                if isLoading {
                    ProgressView().controlSize(.regular).tint(.white)
                } else {
                    VStack {
                        Spacer()
                        HStack {
                            if let sz = imagePixelSize, !item.isDirectory {
                                Text("\(Int(sz.width))×\(Int(sz.height))")
                                    .font(.system(size: 9).monospaced())
                                    .foregroundStyle(.white.opacity(0.9))
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background(Color.black.opacity(0.45), in: Capsule())
                            }
                            Spacer()
                        }
                        .padding(6)
                    }
                    Button { onSelect() } label: {
                        Label(item.isDirectory ? "Ouvrir" : "Utiliser",
                              systemImage: item.isDirectory ? "arrow.right.circle" : "desktopcomputer")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(.white.opacity(0.2), in: Capsule())
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .aspectRatio(cellAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovering = $0 }
        .onAppear { loadThumbnail() }
    }

    private func loadThumbnail() {
        guard !item.isDirectory, thumbnail == nil else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let img = NSImage(contentsOf: item.url) else { return }
            let rep = img.representations.first
            let px = CGSize(
                width:  rep.map { CGFloat($0.pixelsWide) } ?? img.size.width,
                height: rep.map { CGFloat($0.pixelsHigh) } ?? img.size.height
            )
            let ratio = px.width > 0 && px.height > 0 ? px.width / px.height : 4.0 / 3.0
            DispatchQueue.main.async { thumbnail = img; imagePixelSize = px; cellAspectRatio = ratio }
        }
    }
}

// MARK: - Color hex helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
