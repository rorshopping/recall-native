import Foundation
import StoreKit
import Combine
import UIKit

@MainActor
final class SubscriptionService: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isPremium = false
    @Published private(set) var purchaseError: String?
    private let productIDs: Set<String> = ["recall_yearly"]
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

    /// Opens Apple's native subscription management sheet for the current app.
    /// The caller does not need to know anything about UIWindowScene plumbing.
    func manageSubscriptions() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            purchaseError = "Subscription management is unavailable right now."
            return
        }
        Task {
            do {
                try await AppStore.showManageSubscriptions(in: scene)
            } catch {
                purchaseError = error.localizedDescription
            }
        }
    }

    func clearError() { purchaseError = nil }

    private func refreshEntitlements() async {
        var premium = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               productIDs.contains(transaction.productID) {
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
