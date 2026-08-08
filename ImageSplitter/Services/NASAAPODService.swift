import SwiftUI
import Combine

// MARK: - Models

struct NASAAPODPhoto: Identifiable, Codable {
    var id: String { date }
    let date: String
    let title: String
    let explanation: String
    let url: String
    let hdurl: String?
    let media_type: String

    var isImage: Bool { media_type == "image" }
    var fullImageURL: String { hdurl ?? url }
}

// MARK: - Service

class NASAAPODService: ObservableObject {
    @AppStorage("nasaApiKey") var apiKey: String = ""

    @Published var photos: [NASAAPODPhoto] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Uses DEMO_KEY if no key is provided
    var hasApiKey: Bool { true }
    var hasNextPage: Bool { false }
    var currentPage: Int { 1 }
    var lastQuery: String = ""

    private let baseURL = "https://api.nasa.gov/planetary/apod"

    private var effectiveKey: String {
        let k = apiKey.trimmingCharacters(in: .whitespaces)
        return k.isEmpty ? "DEMO_KEY" : k
    }

    func search(query: String, page: Int = 1) {
        fetchRandom(topic: query)
    }

    func loadMore() {}

    func fetchRandom(topic: String? = nil) {
        isLoading = true
        errorMessage = nil
        guard let url = URL(string: "\(baseURL)?api_key=\(effectiveKey)&count=30") else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                if let error { self.errorMessage = error.localizedDescription; return }
                guard let data else { self.errorMessage = "No data received"; return }
                if let http = response as? HTTPURLResponse {
                    if http.statusCode == 429 {
                        self.errorMessage = "Rate limit reached (DEMO_KEY). Add your free NASA API key in Settings."
                        return
                    }
                    guard http.statusCode == 200 else {
                        self.errorMessage = "HTTP \(http.statusCode)"
                        return
                    }
                }
                do {
                    let results = try JSONDecoder().decode([NASAAPODPhoto].self, from: data)
                    let newPhotos = results.filter { $0.isImage }.shuffled()
                    let existingDates = Set(self.photos.map(\.date))
                    let unique = newPhotos.filter { !existingDates.contains($0.date) }
                    self.photos.append(contentsOf: unique)
                } catch {
                    self.errorMessage = "Parse error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    func downloadImage(photo: NASAAPODPhoto, completion: @escaping (NSImage?) -> Void) {
        guard let url = URL(string: photo.fullImageURL) else { completion(nil); return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async { completion(data.flatMap { NSImage(data: $0) }) }
        }.resume()
    }
}
