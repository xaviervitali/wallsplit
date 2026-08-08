import SwiftUI
import Combine

// MARK: - Models

struct PinterestBoard: Identifiable, Codable {
    let id: String
    let name: String
    let description: String?
    let pin_count: Int?
    let media: PinterestBoardMedia?
    let owner: PinterestOwner?
}

struct PinterestBoardMedia: Codable {
    let pin_thumbnail_urls: [String]?
    let image_cover_url: String?
}

struct PinterestOwner: Codable {
    let username: String?
}

struct PinterestBoardsResponse: Codable {
    let items: [PinterestBoard]
    let bookmark: String?
}

struct PinterestPin: Identifiable, Codable {
    let id: String
    let title: String?
    let description: String?
    let media: PinterestPinMedia?
    let created_at: String?
}

struct PinterestPinMedia: Codable {
    let media_type: String?
    let images: [String: PinterestImageSize]?

    var bestImageURL: String? {
        for key in ["originals", "1200x", "736x", "600x", "400x300", "150x150"] {
            if let url = images?[key]?.url { return url }
        }
        return images?.values.first?.url
    }

    var thumbnailURL: String? {
        for key in ["400x300", "600x", "736x", "150x150", "originals"] {
            if let url = images?[key]?.url { return url }
        }
        return images?.values.first?.url
    }

    var bestWidth: Int {
        for key in ["originals", "1200x", "736x", "600x"] {
            if let w = images?[key]?.width, w > 0 { return w }
        }
        return 1200
    }

    var bestHeight: Int {
        for key in ["originals", "1200x", "736x", "600x"] {
            if let h = images?[key]?.height, h > 0 { return h }
        }
        return 900
    }
}

struct PinterestImageSize: Codable {
    let url: String
    let width: Int?
    let height: Int?
}

struct PinterestPinsResponse: Codable {
    let items: [PinterestPin]
    let bookmark: String?
}

// MARK: - Service

class PinterestService: ObservableObject {
    /// Personal access token from developers.pinterest.com → your app → Generate access token
    /// Required scopes: boards:read, pins:read
    @AppStorage("pinterestAccessToken") var accessToken: String = ""

    @Published var boards: [PinterestBoard] = []
    @Published var pins: [PinterestPin] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedBoardId: String?
    @Published var pinsBookmark: String?
    @Published var hasNextPage = false

    var hasApiKey: Bool { !accessToken.trimmingCharacters(in: .whitespaces).isEmpty }
    var currentPage: Int { 1 }
    var lastQuery: String = ""

    private let baseURL = "https://api.pinterest.com/v5"

    // MARK: - Boards

    func fetchBoards() {
        guard hasApiKey else {
            errorMessage = "No access token. Add your Pinterest Access Token in Settings (⌘,)."
            return
        }
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "\(baseURL)/boards?page_size=50&fields=id,name,description,pin_count,media,owner") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                if let error { self.errorMessage = error.localizedDescription; return }
                guard let data else { self.errorMessage = "No data received"; return }
                if let http = response as? HTTPURLResponse {
                    if http.statusCode == 401 {
                        self.errorMessage = "Invalid access token. Check your Pinterest Access Token in Settings."
                        return
                    }
                    guard http.statusCode == 200 else { self.errorMessage = "HTTP \(http.statusCode)"; return }
                }
                do {
                    let result = try JSONDecoder().decode(PinterestBoardsResponse.self, from: data)
                    self.boards = result.items
                    if self.selectedBoardId == nil, let first = result.items.first {
                        self.selectedBoardId = first.id
                        self.fetchPins(boardId: first.id)
                    }
                } catch {
                    self.errorMessage = "Parse error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    // MARK: - Pins

    func fetchPins(boardId: String, bookmark: String? = nil) {
        guard hasApiKey else { return }
        isLoading = true
        errorMessage = nil

        var urlStr = "\(baseURL)/boards/\(boardId)/pins?page_size=25&fields=id,title,description,media,created_at"
        if let bm = bookmark { urlStr += "&bookmark=\(bm)" }
        guard let url = URL(string: urlStr) else { return }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                if let error { self.errorMessage = error.localizedDescription; return }
                guard let data else { self.errorMessage = "No data received"; return }
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    self.errorMessage = "HTTP \(http.statusCode)"; return
                }
                do {
                    let result = try JSONDecoder().decode(PinterestPinsResponse.self, from: data)
                    if bookmark == nil { self.pins = result.items } else { self.pins.append(contentsOf: result.items) }
                    self.pinsBookmark = result.bookmark
                    self.hasNextPage = result.bookmark != nil
                } catch {
                    self.errorMessage = "Parse error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    func selectBoard(_ boardId: String) {
        selectedBoardId = boardId
        pins = []
        pinsBookmark = nil
        hasNextPage = false
        fetchPins(boardId: boardId)
    }

    func loadMore() {
        guard !isLoading, hasNextPage, let boardId = selectedBoardId else { return }
        fetchPins(boardId: boardId, bookmark: pinsBookmark)
    }

    func search(query: String, page: Int = 1) {
        if boards.isEmpty { fetchBoards() }
    }

    func fetchRandom(topic: String? = nil) {
        if boards.isEmpty { fetchBoards() }
        else if let boardId = selectedBoardId { fetchPins(boardId: boardId) }
    }

    func downloadImage(pin: PinterestPin, completion: @escaping (NSImage?) -> Void) {
        let urlStr = pin.media?.bestImageURL ?? pin.media?.thumbnailURL
        guard let urlStr, let url = URL(string: urlStr) else { completion(nil); return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async { completion(data.flatMap { NSImage(data: $0) }) }
        }.resume()
    }
}
