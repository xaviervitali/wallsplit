import SwiftUI
import Combine

// MARK: - Models

struct PixabayPhoto: Identifiable, Codable {
    let id: Int
    let previewURL: String
    let largeImageURL: String
    let imageWidth: Int
    let imageHeight: Int
    let user: String
    let tags: String
}

struct PixabaySearchResult: Codable {
    let total: Int
    let totalHits: Int
    let hits: [PixabayPhoto]
}

// MARK: - Service

class PixabayService: ObservableObject {
    @AppStorage("pixabayApiKey") var apiKey: String = ""

    @Published var photos: [PixabayPhoto] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentPage = 1
    @Published var hasNextPage = false
    @Published var lastQuery = ""

    var hasApiKey: Bool { !apiKey.trimmingCharacters(in: .whitespaces).isEmpty }

    private let perPage = 20
    private let baseURL = "https://pixabay.com/api/"

    func search(query: String, page: Int = 1) {
        guard hasApiKey else {
            errorMessage = "No API key. Add your Pixabay API Key in Settings (⌘,)."
            return
        }
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        if page == 1 { photos = []; lastQuery = q }
        currentPage = page
        isLoading = true
        errorMessage = nil

        let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)&q=\(encoded)&image_type=photo&orientation=horizontal&min_width=1920&per_page=\(perPage)&page=\(page)&safesearch=true") else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                if let error { self.errorMessage = error.localizedDescription; return }
                guard let data else { self.errorMessage = "No data received"; return }
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    self.errorMessage = http.statusCode == 400
                        ? "Invalid API key. Check your Pixabay API Key in Settings."
                        : "HTTP \(http.statusCode)"
                    return
                }
                do {
                    let result = try JSONDecoder().decode(PixabaySearchResult.self, from: data)
                    if page == 1 { self.photos = result.hits } else { self.photos.append(contentsOf: result.hits) }
                    let totalPages = Int(ceil(Double(result.totalHits) / Double(self.perPage)))
                    self.hasNextPage = page < totalPages
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
        let fallbacks = ["nature", "landscape", "city", "mountains", "ocean", "minimal", "forest", "sunset", "abstract"]
        let q = topic.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 } ?? (fallbacks.randomElement() ?? "nature")
        search(query: q, page: 1)
    }

    func downloadImage(photo: PixabayPhoto, completion: @escaping (NSImage?) -> Void) {
        guard let url = URL(string: photo.largeImageURL) else { completion(nil); return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async { completion(data.flatMap { NSImage(data: $0) }) }
        }.resume()
    }
}
