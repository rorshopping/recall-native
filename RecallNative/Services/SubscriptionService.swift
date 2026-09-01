import Foundation
import StoreKit

@MainActor
final class SubscriptionService: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isPremium = false

    private let productIDs = ["recall.premium.monthly", "recall.premium.yearly"]

    func load() async {
        products = (try? await Product.products(for: productIDs)) ?? []
        await refreshEntitlements()
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        if case .success(let verification) = result {
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await refreshEntitlements()
        }
    }

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

    enum StoreError: Error { case unverified }
}
