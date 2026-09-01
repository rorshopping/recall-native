import Foundation
import StoreKit
import Combine

@MainActor
final class SubscriptionService: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isPremium = false
    @Published private(set) var purchaseError: String?

    private let productIDs: Set<String> = ["recall.premium.monthly", "recall.premium.yearly"]
    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await refreshEntitlements()
                }
            }
        }
    }

    deinit { updatesTask?.cancel() }

    func load() async {
        products = (try? await Product.products(for: Array(productIDs)))?.sorted { $0.price < $1.price } ?? []
        await refreshEntitlements()
    }

    func purchase(_ product: Product) async {
        purchaseError = nil
        do {
            switch try await product.purchase() {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func restore() async {
        purchaseError = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func clearError() { purchaseError = nil }

    private func refreshEntitlements() async {
        var premium = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement, productIDs.contains(transaction.productID) {
                premium = true
            }
        }
        isPremium = premium
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw StoreError.unverified
        }
    }

    enum StoreError: LocalizedError {
        case unverified
        var errorDescription: String? { "The App Store could not verify this purchase." }
    }
}
