import StoreKit
import SwiftUI
import Combine

// MARK: - ProManager
//
// StoreKit 2 — requires macOS 12+
//
// Setup steps:
//  1. Create a Non-Consumable IAP in App Store Connect with ID: "com.imageSplitter.pro"
//  2. Add a StoreKit Configuration file in Xcode for local testing
//  3. Ensure your app is signed with your Apple Developer account
//

@MainActor
class ProManager: ObservableObject {
    static let shared = ProManager()

    @Published private(set) var isPro = false
    @Published private(set) var isLoading = false
    @Published private(set) var proProduct: Product?
    @Published var purchaseError: String?

    static let productId = "com.imageSplitter.pro"

    private var transactionListenerTask: Task<Void, Error>?

    init() {
        transactionListenerTask = Task { [weak self] in
            await self?.listenForTransactions()
        }
        Task { [weak self] in
            guard let self else { return }
            self.isLoading = true
            await self.loadProducts()
            await self.refreshProStatus()
            self.isLoading = false
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Products

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [ProManager.productId])
            proProduct = products.first
        } catch {
            print("StoreKit: Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase() async {
        guard let product = proProduct else {
            purchaseError = "Product not available. Check your internet connection and try again."
            return
        }
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshProStatus()
                case .unverified:
                    purchaseError = "Purchase could not be verified. Please contact support."
                }
            case .pending:
                purchaseError = "Purchase is pending (check parental controls or Ask to Buy)."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshProStatus()
        } catch {
            purchaseError = "Restore failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Status

    func refreshProStatus() async {
        var hasActivePro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == ProManager.productId,
               transaction.revocationDate == nil {
                hasActivePro = true
            }
        }
        isPro = hasActivePro
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await refreshProStatus()
                await transaction.finish()
            }
        }
    }
}
