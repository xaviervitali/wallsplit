import SwiftUI
import Combine

// MARK: - Models

struct UnsplashPhoto: Identifiable, Codable {
    let id: String
    let width: Int
    let height: Int
    let color: String?
    let description: String?
    let alt_description: String?
    let urls: UnsplashURLs
    let user: UnsplashUser
    let links: UnsplashLinks
}

struct UnsplashURLs: Codable {
    let raw: String
    let full: String
    let regular: String
    let small: String
    let thumb: String
}

struct UnsplashUser: Codable {
    let name: String
    let username: String
}

struct UnsplashLinks: Codable {
    let download_location: String?
}

struct UnsplashSearchResult: Codable {
    let total: Int
    let total_pages: Int
    let results: [UnsplashPhoto]
}

// MARK: - Service

class UnsplashService: ObservableObject {
    @AppStorage("unsplashAccessKey") var accessKey: String = ""
    
    @Published var photos: [UnsplashPhoto] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentPage = 1
    @Published var totalPages = 0
    @Published var lastQuery = ""
    
    var hasApiKey: Bool { !accessKey.trimmingCharacters(in: .whitespaces).isEmpty }
    
    private let baseURL = "https://api.unsplash.com"
    
    /// Search photos by query, filtered for landscape orientation (ideal for wallpapers)
    func search(query: String, page: Int = 1) {
        guard hasApiKey else {
            errorMessage = "No API key. Go to Settings to add your Unsplash Access Key."
            return
        }
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        guard !trimmedQuery.isEmpty else { return }
        
        if page == 1 {
            photos = []
            lastQuery = trimmedQuery
        }
        currentPage = page
        isLoading = true
        errorMessage = nil
        
        let encoded = trimmedQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmedQuery
        let urlString = "\(baseURL)/search/photos?query=\(encoded)&page=\(page)&per_page=20&orientation=landscape&order_by=relevant"
        
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    return
                }
                
                // Check HTTP status
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    if httpResponse.statusCode == 401 {
                        self?.errorMessage = "Invalid API key. Check your Unsplash Access Key in Settings."
                    } else if httpResponse.statusCode == 403 {
                        self?.errorMessage = "Rate limit exceeded. Try again later."
                    } else {
                        self?.errorMessage = "HTTP \(httpResponse.statusCode)"
                    }
                    return
                }
                
                do {
                    let result = try JSONDecoder().decode(UnsplashSearchResult.self, from: data)
                    if page == 1 {
                        self?.photos = result.results
                    } else {
                        self?.photos.append(contentsOf: result.results)
                    }
                    self?.totalPages = result.total_pages
                } catch {
                    self?.errorMessage = "Parse error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    /// Load next page
    func loadMore() {
        guard !isLoading, currentPage < totalPages else { return }
        search(query: lastQuery, page: currentPage + 1)
    }
    
    /// Get random landscape photos (for "surprise me" / daily wallpaper)
    func fetchRandom(count: Int = 8, topic: String? = nil) {
        guard hasApiKey else {
            errorMessage = "No API key."
            return
        }
        
        isLoading = true
        errorMessage = nil
        photos = []
        
        var urlString = "\(baseURL)/photos/random?count=\(count)&orientation=landscape"
        if let topic = topic?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            urlString += "&query=\(topic)"
        }
        
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error { self?.errorMessage = error.localizedDescription; return }
                guard let data = data else { return }
                
                do {
                    let photos = try JSONDecoder().decode([UnsplashPhoto].self, from: data)
                    self?.photos = photos
                } catch {
                    self?.errorMessage = "Parse error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    /// Download full resolution image and return as NSImage
    func downloadImage(photo: UnsplashPhoto, targetWidth: Int? = nil, completion: @escaping (NSImage?) -> Void) {
        // Build URL with custom width if specified
        var urlString = photo.urls.raw
        if let w = targetWidth {
            urlString += "&w=\(w)&q=90&fm=jpg"
        } else {
            // Full resolution
            urlString = photo.urls.full
        }
        
        guard let url = URL(string: urlString) else { completion(nil); return }
        
        // Trigger download tracking (required by Unsplash TOS)
        if let downloadLocation = photo.links.download_location, hasApiKey {
            var trackRequest = URLRequest(url: URL(string: "\(baseURL)\(downloadLocation.replacingOccurrences(of: baseURL, with: ""))")!)
            trackRequest.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
            URLSession.shared.dataTask(with: trackRequest).resume()
        }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                if let data = data, let image = NSImage(data: data) {
                    completion(image)
                } else {
                    completion(nil)
                }
            }
        }.resume()
    }
    
    /// Get the URL for a specific resolution crop
    func imageURL(photo: UnsplashPhoto, width: Int, height: Int) -> String {
        "\(photo.urls.raw)&w=\(width)&h=\(height)&fit=crop&q=90&fm=jpg"
    }
}
