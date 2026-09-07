import SwiftUI
import Combine

// MARK: - Models

struct WallhavenPhoto: Identifiable, Codable {
    let id: String
    let path: String
    let dimension_x: Int
    let dimension_y: Int
    let resolution: String
    let ratio: String
    let thumbs: WallhavenThumbs
}

struct WallhavenThumbs: Codable {
    let large: String
    let original: String
    let small: String
}

struct WallhavenMeta: Codable {
    let total: Int
    let per_page: Int
    let current_page: Int
    let last_page: Int
}

struct WallhavenSearchResult: Codable {
    let data: [WallhavenPhoto]
    let meta: WallhavenMeta?
}

// MARK: - Service

class WallhavenService: ObservableObject {
    @AppStorage("wallhavenApiKey") var apiKey: String = ""

    @Published var photos: [WallhavenPhoto] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentPage = 1
    @Published var hasNextPage = false
    @Published var lastQuery = ""

    /// No key required for SFW content
    var hasApiKey: Bool { true }

    private let baseURL = "https://wallhaven.cc/api/v1"

    func search(query: String, page: Int = 1) {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        if page == 1 { photos = []; lastQuery = q }
        currentPage = page
        isLoading = true
        errorMessage = nil

        let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
        var urlStr = "\(baseURL)/search?q=\(encoded)&categories=100&purity=100&atleast=1920x1080&sorting=relevance&page=\(page)&per_page=24"
        let key = apiKey.trimmingCharacters(in: .whitespaces)
        if !key.isEmpty { urlStr += "&apikey=\(key)" }
        guard let url = URL(string: urlStr) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                if let error { self.errorMessage = error.localizedDescription; return }
                guard let data else { self.errorMessage = "No data received"; return }
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    self.errorMessage = "HTTP \(http.statusCode)"
                    return
                }
                do {
                    let result = try JSONDecoder().decode(WallhavenSearchResult.self, from: data)
                    if page == 1 { self.photos = result.data } else { self.photos.append(contentsOf: result.data) }
                    if let meta = result.meta { self.hasNextPage = meta.current_page < meta.last_page }
                } catch {
                    self.errorMessage = "Parse error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    func loadMore() {
        guard !isLoading, hasNextPage else { return }
        search(query: lastQuery, page: currentPage + 1)
    }

    func fetchRandom(topic: String? = nil) {
        let fallbacks = ["nature", "landscape", "space", "mountains", "ocean", "minimal", "forest", "sunset", "abstract", "city"]
        let q = topic.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 } ?? (fallbacks.randomElement() ?? "nature")
        search(query: q, page: 1)
    }

    func downloadImage(photo: WallhavenPhoto, completion: @escaping (NSImage?) -> Void) {
        guard let url = URL(string: photo.path) else { completion(nil); return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async { completion(data.flatMap { NSImage(data: $0) }) }
        }.resume()
    }
}
