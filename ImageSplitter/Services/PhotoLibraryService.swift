import Foundation
import Combine
import Photos
import AppKit

class PhotoLibraryService: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus
    @Published var albums: [PHAssetCollection] = []
    @Published var photos: [PHAsset] = []
    @Published var isLoading = false
    @Published var selectedAlbum: PHAssetCollection? = nil

    private let imageManager = PHCachingImageManager()

    init() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if authorizationStatus == .authorized || authorizationStatus == .limited {
            fetchAlbums()
            fetchPhotos(from: nil)
        }
    }

    // MARK: - Authorization

    func requestAuthorization() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                if status == .authorized || status == .limited {
                    self?.fetchAlbums()
                    self?.fetchPhotos(from: nil)
                }
            }
        }
    }

    // MARK: - Fetch

    func fetchAlbums() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var result: [PHAssetCollection] = []
            let imgOpts = PHFetchOptions()
            imgOpts.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

            PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
                .enumerateObjects { col, _, _ in
                    if PHAsset.fetchAssets(in: col, options: imgOpts).count > 0 { result.append(col) }
                }

            PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
                .enumerateObjects { col, _, _ in
                    if PHAsset.fetchAssets(in: col, options: imgOpts).count > 0 { result.append(col) }
                }

            DispatchQueue.main.async { self?.albums = result }
        }
    }

    func fetchPhotos(from collection: PHAssetCollection?) {
        isLoading = true
        selectedAlbum = collection

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

            let fetchResult: PHFetchResult<PHAsset>
            if let collection {
                fetchResult = PHAsset.fetchAssets(in: collection, options: options)
            } else {
                fetchResult = PHAsset.fetchAssets(with: .image, options: options)
            }

            var assets: [PHAsset] = []
            fetchResult.enumerateObjects { asset, _, _ in assets.append(asset) }

            DispatchQueue.main.async {
                self?.photos = assets
                self?.isLoading = false
            }
        }
    }

    // MARK: - Image Loading

    func loadThumbnail(for asset: PHAsset, size: CGSize, completion: @escaping (NSImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { image, _ in
            DispatchQueue.main.async { completion(image) }
        }
    }

    func loadFullImage(for asset: PHAsset, completion: @escaping (NSImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        imageManager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options) { image, info in
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            if !isDegraded { DispatchQueue.main.async { completion(image) } }
        }
    }
}
