import SwiftUI
import Combine

// MARK: - Models

struct PexelsPhoto: Identifiable, Codable {
    let id: Int
    let width: Int
    let height: Int
    let photographer: String
    let avg_color: String?
    let alt: String?
    let src: PexelsSrc
}

struct PexelsSrc: Codable {
    let original: String
    let large2x: String
    let large: String
    let medium: String
    let small: String
    let tiny: String
}

struct PexelsSearchResult: Codable {
    let total_results: Int
    let page: Int
    let per_page: Int
    let photos: [PexelsPhoto]
    let next_page: String?
}

// MARK: - Service

class PexelsService: ObservableObject {
    @AppStorage("pexelsApiKey") var apiKey: String = ""

    @Published var photos: [PexelsPhoto] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentPage = 1
    @Published var hasNextPage = false
    @Published var lastQuery = ""

    var hasApiKey: Bool { !apiKey.trimmingCharacters(in: .whitespaces).isEmpty }

    private let baseURL = "https://api.pexels.com/v1"

    func search(query: String, page: Int = 1) {
        guard hasApiKey else {
            errorMessage = "No API key. Add your Pexels API Key in Settings (⌘,)."
            return
        }

        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }

        if page == 1 { photos = []; lastQuery = q }
        currentPage = page
        isLoading = true
        errorMessage = nil

        let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
        guard let url = URL(string: "\(baseURL)/search?query=\(encoded)&page=\(page)&per_page=20&orientation=landscape") else { return }

        var req = URLRequest(url: url)
        req.setValue(apiKey, forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error { self?.errorMessage = error.localizedDescription; return }
                guard let data = data else { self?.errorMessage = "No data received"; return }

                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    self?.errorMessage = http.statusCode == 401
                        ? "Invalid API key. Check your Pexels API Key in Settings."
                        : "HTTP \(http.statusCode)"
                    return
                }

                do {
                    let result = try JSONDecoder().decode(PexelsSearchResult.self, from: data)
                    if page == 1 { self?.photos = result.photos }
                    else { self?.photos.append(contentsOf: result.photos) }
                    self?.hasNextPage = result.next_page != nil
                } catch {
                    self?.errorMessage = "Parse error: \(error.localizedDescription)"
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
        let q = (topic?.trimmingCharacters(in: .whitespaces).isEmpty == false) ? topic! : (fallbacks.randomElement() ?? "nature")
        search(query: q, page: 1)
    }

    func downloadImage(photo: PexelsPhoto, completion: @escaping (NSImage?) -> Void) {
        guard let url = URL(string: photo.src.original) else { completion(nil); return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                completion(data.flatMap { NSImage(data: $0) })
            }
        }.resume()
    }
}
