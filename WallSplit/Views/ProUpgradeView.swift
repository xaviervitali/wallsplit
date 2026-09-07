import SwiftUI
import StoreKit

// MARK: - ProUpgradeView
//
// Shown as a sheet when a free user tries to access a Pro feature.

struct ProUpgradeView: View {
    @ObservedObject private var proManager = ProManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().padding(.vertical, 4)
            featureList
            Divider().padding(.vertical, 4)
            purchaseSection
        }
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.bottom, 20)
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 72, height: 72)
                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.top, 28)

            Text("Upgrade to Pro")
                .font(.title2.weight(.bold))
            Text("Unlock all features with a one-time purchase")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
    }

    // MARK: Feature list

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProFeatureRow(
                icon: "photo.stack",
                title: "All Photo APIs",
                description: "Unsplash, Pexels, Wallhaven, Pixabay, NASA & Pinterest"
            )
            ProFeatureRow(
                icon: "star.fill",
                title: "Unlimited Presets",
                description: "Save as many screen configurations as you want (free: 3 max)"
            )
            ProFeatureRow(
                icon: "arrow.triangle.2.circlepath",
                title: "Auto-Rotation",
                description: "Automatically change wallpapers every X minutes"
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: Purchase section

    private var purchaseSection: some View {
        VStack(spacing: 10) {
            if proManager.isLoading {
                ProgressView("Loading…").padding()
            } else if let product = proManager.proProduct {
                Button {
                    Task { await proManager.purchase() }
                } label: {
                    Text("Unlock Pro  —  \(product.displayPrice)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 20)

                Button("Restore Purchase") {
                    Task { await proManager.restorePurchases() }
                }
                .font(.callout)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    Text("Unable to load pricing").font(.callout).foregroundStyle(.secondary)
                    Button("Try Again") { Task { await proManager.loadProducts() } }
                        .buttonStyle(.bordered).controlSize(.small)
                }
                .padding()
            }

            if let error = proManager.purchaseError {
                Text(error)
                    .font(.caption).foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Button("Not now") { dismiss() }
                .font(.callout).buttonStyle(.borderless)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - ProFeatureRow

struct ProFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - ProBadge (inline badge for locked sources)

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 4).padding(.vertical, 2)
            .background(Color.accentColor, in: Capsule())
    }
}
