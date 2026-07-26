import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            ApiKeysTab()
                .tabItem { Label("APIs", systemImage: "key") }

            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 300)
    }
}

// MARK: - API Keys tab

private struct ApiKeysTab: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
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
            }
            .padding(20)
        }
    }
}

private struct ApiServiceSection: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let storageKey: String
    let placeholder: String
    let getKeyURL: URL
    let getKeyLabel: String

    @AppStorage var apiKey: String
    @State private var showKey = false

    init(title: String, subtitle: String, icon: String, iconColor: Color,
         storageKey: String, placeholder: String, getKeyURL: URL, getKeyLabel: String) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.storageKey = storageKey
        self.placeholder = placeholder
        self.getKeyURL = getKeyURL
        self.getKeyLabel = getKeyLabel
        self._apiKey = AppStorage(wrappedValue: "", storageKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.callout.weight(.semibold))
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !apiKey.isEmpty {
                    Label("Configured", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.green.opacity(0.1)))
                } else {
                    Text("No key").font(.caption).foregroundStyle(.tertiary)
                }
            }

            // Key field
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

                Button {
                    showKey.toggle()
                } label: {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                        .frame(width: 20)
                }
                .buttonStyle(.borderless)

                if !apiKey.isEmpty {
                    Button {
                        apiKey = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Remove key")
                }
            }

            // Footer link
            HStack(spacing: 4) {
                Text("Free key at").font(.caption).foregroundStyle(.tertiary)
                Button(getKeyLabel) {
                    NSWorkspace.shared.open(getKeyURL)
                }
                .font(.caption).buttonStyle(.link)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))
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
            }

            Spacer()
        }
        .padding(20)
    }
}
