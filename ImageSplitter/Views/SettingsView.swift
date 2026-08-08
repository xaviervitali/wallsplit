import SwiftUI
import StoreKit

struct SettingsView: View {
    var body: some View {
        TabView {
            ApiKeysTab()
                .tabItem { Label("APIs", systemImage: "key") }

            ProTab()
                .tabItem { Label("Pro", systemImage: "sparkles") }

            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 440)
    }
}

// MARK: - API Keys tab

private struct ApiKeysTab: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // --- Free APIs (no key required) ---

                SectionHeader(title: "FREE — No Key Required")

                ApiServiceSection(
                    title: "Wallhaven",
                    subtitle: "1M+ HD wallpapers — works without a key",
                    icon: "rectangle.stack.fill",
                    iconColor: .purple,
                    storageKey: "wallhavenApiKey",
                    placeholder: "Optional: paste your Wallhaven API key",
                    getKeyURL: URL(string: "https://wallhaven.cc/settings/account")!,
                    getKeyLabel: "wallhaven.cc/settings",
                    isOptional: true
                )

                ApiServiceSection(
                    title: "NASA APOD",
                    subtitle: "Astronomy Picture of the Day — uses DEMO_KEY if empty",
                    icon: "sparkles",
                    iconColor: .blue,
                    storageKey: "nasaApiKey",
                    placeholder: "Optional: paste your NASA API key",
                    getKeyURL: URL(string: "https://api.nasa.gov/")!,
                    getKeyLabel: "api.nasa.gov",
                    isOptional: true
                )

                // --- APIs requiring a key ---

                SectionHeader(title: "REQUIRES A FREE API KEY")

                ApiServiceSection(
                    title: "Unsplash",
                    subtitle: "4M+ free high-resolution photos",
                    icon: "camera.aperture",
                    iconColor: .primary,
                    storageKey: "unsplashAccessKey",
                    placeholder: "Paste your Unsplash Access Key",
                    getKeyURL: URL(string: "https://unsplash.com/developers")!,
                    getKeyLabel: "unsplash.com/developers"
                )

                ApiServiceSection(
                    title: "Pexels",
                    subtitle: "3M+ free stock photos",
                    icon: "photo.artframe",
                    iconColor: .green,
                    storageKey: "pexelsApiKey",
                    placeholder: "Paste your Pexels API Key",
                    getKeyURL: URL(string: "https://www.pexels.com/api/")!,
                    getKeyLabel: "pexels.com/api"
                )

                ApiServiceSection(
                    title: "Pixabay",
                    subtitle: "1.9M+ free photos, vectors & illustrations",
                    icon: "photo.fill",
                    iconColor: .orange,
                    storageKey: "pixabayApiKey",
                    placeholder: "Paste your Pixabay API Key",
                    getKeyURL: URL(string: "https://pixabay.com/api/docs/")!,
                    getKeyLabel: "pixabay.com/api/docs"
                )

                // --- Pinterest ---

                SectionHeader(title: "PINTEREST — PERSONAL ACCESS TOKEN")

                PinterestTokenSection()
            }
            .padding(16)
        }
    }
}

private struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1)
        }
    }
}

// MARK: - Pinterest token section

private struct PinterestTokenSection: View {
    @AppStorage("pinterestAccessToken") private var token: String = ""
    @State private var showToken = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "pin.fill")
                    .font(.title3).foregroundStyle(Color.red)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Pinterest").font(.callout.weight(.semibold))
                    Text("Browse your personal boards & pins").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !token.isEmpty {
                    Label("Configured", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium)).foregroundStyle(.green)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.green.opacity(0.1)))
                } else {
                    Text("No token").font(.caption).foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 6) {
                Group {
                    if showToken {
                        TextField("Paste your Pinterest Access Token", text: $token)
                    } else {
                        SecureField("Paste your Pinterest Access Token", text: $token)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

                Button { showToken.toggle() } label: {
                    Image(systemName: showToken ? "eye.slash" : "eye").frame(width: 20)
                }
                .buttonStyle(.borderless)

                if !token.isEmpty {
                    Button { token = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless).help("Remove token")
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("How to get your token:").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Text("1. Go to developers.pinterest.com and create a free app")
                    .font(.caption).foregroundStyle(.tertiary)
                Text("2. In your app settings, click \"Generate access token\"")
                    .font(.caption).foregroundStyle(.tertiary)
                Text("3. Enable scopes: boards:read, pins:read — then paste above")
                    .font(.caption).foregroundStyle(.tertiary)
            }

            HStack(spacing: 4) {
                Text("Developer portal at").font(.caption).foregroundStyle(.tertiary)
                Button("developers.pinterest.com") {
                    NSWorkspace.shared.open(URL(string: "https://developers.pinterest.com/")!)
                }
                .font(.caption).buttonStyle(.link)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Generic API service section

private struct ApiServiceSection: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let storageKey: String
    let placeholder: String
    let getKeyURL: URL
    let getKeyLabel: String
    var isOptional: Bool = false

    @AppStorage var apiKey: String
    @State private var showKey = false

    init(title: String, subtitle: String, icon: String, iconColor: Color,
         storageKey: String, placeholder: String, getKeyURL: URL, getKeyLabel: String,
         isOptional: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.storageKey = storageKey
        self.placeholder = placeholder
        self.getKeyURL = getKeyURL
        self.getKeyLabel = getKeyLabel
        self.isOptional = isOptional
        self._apiKey = AppStorage(wrappedValue: "", storageKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3).foregroundStyle(iconColor).frame(width: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.callout.weight(.semibold))
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !apiKey.isEmpty {
                    Label("Configured", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium)).foregroundStyle(.green)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.green.opacity(0.1)))
                } else if isOptional {
                    Text("Using default").font(.caption).foregroundStyle(.tertiary)
                } else {
                    Text("No key").font(.caption).foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 6) {
                Group {
                    if showKey {
                        TextField(placeholder, text: $apiKey)
                    } else {
                        SecureField(placeholder, text: $apiKey)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

                Button { showKey.toggle() } label: {
                    Image(systemName: showKey ? "eye.slash" : "eye").frame(width: 20)
                }
                .buttonStyle(.borderless)

                if !apiKey.isEmpty {
                    Button { apiKey = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless).help("Remove key")
                }
            }

            HStack(spacing: 4) {
                Text(isOptional ? "Optional — get a key at" : "Free key at")
                    .font(.caption).foregroundStyle(.tertiary)
                Button(getKeyLabel) { NSWorkspace.shared.open(getKeyURL) }
                    .font(.caption).buttonStyle(.link)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Pro tab

private struct ProTab: View {
    @ObservedObject private var proManager = ProManager.shared

    var body: some View {
        VStack(spacing: 20) {
            if proManager.isPro {
                proActiveView
            } else {
                proInactiveView
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var proActiveView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title).foregroundStyle(Color.accentColor)
                VStack(alignment: .leading) {
                    Text("Pro — Active").font(.headline)
                    Text("All features unlocked").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.08)))

            Divider()

            HStack {
                Text("Need to reinstall or switch Mac?")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Restore Purchase") {
                    Task { await proManager.restorePurchases() }
                }
                .buttonStyle(.bordered).controlSize(.small)
            }
        }
    }

    private var proInactiveView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Image(systemName: "sparkles").font(.title).foregroundStyle(Color.accentColor)
                Text("Upgrade to Pro").font(.headline)
                Text("One-time purchase — unlock everything").font(.callout).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                ProFeatureRow(icon: "photo.stack",        title: "All Photo APIs",     description: "Unsplash, Pexels, Wallhaven, Pixabay, NASA & Pinterest")
                ProFeatureRow(icon: "star.fill",          title: "Unlimited Presets",  description: "Save as many screen configurations as you want")
                ProFeatureRow(icon: "arrow.triangle.2.circlepath", title: "Auto-Rotation",  description: "Change wallpapers automatically every X minutes")
            }

            if proManager.isLoading {
                ProgressView()
            } else if let product = proManager.proProduct {
                VStack(spacing: 8) {
                    Button {
                        Task { await proManager.purchase() }
                    } label: {
                        Text("Unlock Pro  —  \(product.displayPrice)")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Restore Purchase") {
                        Task { await proManager.restorePurchases() }
                    }
                    .font(.callout).buttonStyle(.borderless).foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 6) {
                    Text("Unable to load pricing").foregroundStyle(.secondary).font(.callout)
                    Button("Try Again") { Task { await proManager.loadProducts() } }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }

            if let error = proManager.purchaseError {
                Text(error).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - About tab

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Image(systemName: "rectangle.split.3x1.fill")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Color.accentColor)
                Text("ImageSplitter")
                    .font(.title2.weight(.semibold))
                Text("Split wallpapers across multiple screens")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .padding(.top, 20)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Label("Photos by Unsplash contributors", systemImage: "camera.aperture")
                    .font(.caption).foregroundStyle(.secondary)
                Label("Photos by Pexels contributors", systemImage: "photo.artframe")
                    .font(.caption).foregroundStyle(.secondary)
                Label("Wallpapers by Wallhaven community", systemImage: "rectangle.stack.fill")
                    .font(.caption).foregroundStyle(.secondary)
                Label("Photos by Pixabay contributors", systemImage: "photo.fill")
                    .font(.caption).foregroundStyle(.secondary)
                Label("Astronomy images courtesy of NASA", systemImage: "sparkles")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(20)
    }
}
