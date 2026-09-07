import SwiftUI
import Photos

// MARK: - PhotoLibraryView

struct PhotoLibraryView: View {
    @EnvironmentObject var viewModel: SplitterViewModel
    @StateObject private var library = PhotoLibraryService()

    @State private var loadingId: String?

    var body: some View {
        VStack(spacing: 0) {
            switch library.authorizationStatus {
            case .notDetermined:
                authorizationPrompt
            case .denied, .restricted:
                accessDeniedView
            case .authorized, .limited:
                albumBar
                Divider()
                photoGrid
            @unknown default:
                authorizationPrompt
            }
        }
        .animation(.easeInOut(duration: 0.2), value: library.authorizationStatus)
    }

    // MARK: - Authorization views

    private var authorizationPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(.tertiary)
            Text("Accéder à votre Photothèque")
                .font(.title3.weight(.semibold))
            Text("WallSplit a besoin d'accéder à vos photos pour les utiliser comme fond d'écran.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
            Button("Autoriser l'accès") { library.requestAuthorization() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var accessDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(.tertiary)
            Text("Accès refusé")
                .font(.title3.weight(.semibold))
            Text("Autorisez l'accès dans Réglages Système > Confidentialité & Sécurité > Photos.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
            Button("Ouvrir les Réglages Système") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos")!)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Album bar

    private var albumBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                albumChip(title: "Toutes les photos", icon: "photo.stack", collection: nil)
                if !library.albums.isEmpty { Divider().frame(height: 18) }
                ForEach(library.albums, id: \.localIdentifier) { album in
                    albumChip(
                        title: album.localizedTitle ?? "Album",
                        icon: album.assetCollectionType == .smartAlbum ? "sparkles" : "folder",
                        collection: album
                    )
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
    }

    private func albumChip(title: String, icon: String, collection: PHAssetCollection?) -> some View {
        let isSelected = library.selectedAlbum?.localIdentifier == collection?.localIdentifier
            && (collection != nil || library.selectedAlbum == nil)
        return Button {
            library.fetchPhotos(from: collection)
        } label: {
            Label(title, systemImage: icon)
                .font(.callout.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(
                    isSelected ? Color.accentColor.opacity(0.12) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
        }
        .buttonStyle(.borderless)
        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
    }

    // MARK: - Photo grid

    private var photoGrid: some View {
        Group {
            if library.photos.isEmpty && !library.isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundStyle(.tertiary)
                    Text("Aucune photo dans cet album")
                        .font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 8)],
                        spacing: 8
                    ) {
                        ForEach(library.photos, id: \.localIdentifier) { asset in
                            PhotoLibraryCell(
                                asset: asset,
                                library: library,
                                isLoading: loadingId == asset.localIdentifier
                            ) {
                                useAsWallpaper(asset: asset)
                            }
                        }
                    }
                    .padding(12)

                    if library.isLoading {
                        ProgressView("Chargement des photos…").padding()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func useAsWallpaper(asset: PHAsset) {
        guard loadingId == nil else { return }
        loadingId = asset.localIdentifier
        library.loadFullImage(for: asset) { (image: NSImage?) in
            self.loadingId = nil
            guard let image else { return }
            let filename = (asset.value(forKey: "filename") as? String) ?? "photo"
            let name = (filename as NSString).deletingPathExtension
            self.viewModel.loadImage(image, name: name)
        }
    }
}

// MARK: - PhotoLibraryCell

struct PhotoLibraryCell: View {
    let asset: PHAsset
    let library: PhotoLibraryService
    let isLoading: Bool
    let onSelect: () -> Void

    @State private var thumbnail: NSImage?
    @State private var isHovering = false

    private static let thumbSize = CGSize(width: 300, height: 300)

    var body: some View {
        ZStack {
            if let thumb = thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else {
                Color.secondary.opacity(0.15)
                    .overlay(ProgressView().controlSize(.small))
            }

            if isHovering || isLoading {
                Color.black.opacity(0.35)
                if isLoading {
                    ProgressView().controlSize(.regular).tint(.white)
                } else {
                    Button { onSelect() } label: {
                        Label("Utiliser", systemImage: "desktopcomputer")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(.white.opacity(0.2), in: Capsule())
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovering = $0 }
        .onAppear { loadThumbnail() }
    }

    private func loadThumbnail() {
        guard thumbnail == nil else { return }
        library.loadThumbnail(for: asset, size: Self.thumbSize) { image in
            self.thumbnail = image
        }
    }
}
