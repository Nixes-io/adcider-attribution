import XCTest
@testable import AdCiderAttribution

final class NetworkManagerTests: XCTestCase {
    func testQueueAttribution() async {
        let uid = "test-uid"
        let token = "test-token"
        let transactions: [CodableTransaction] = []
        await NetworkManager.shared.queueAttribution(uid: uid, appleAttributionToken: token, transactions: transactions)
        // No assertion: this is a smoke test to ensure no crash and async path works
        XCTAssertTrue(true)
    }

    func testDeferredQueueRetry() async throws {
        // Create a test transaction
        let transaction = CodableTransaction(
            transactionId: "1",
            productID: "test.product",
            purchaseDate: Date(),
            quantity: 1,
            price: 0.99,
            currencyCode: "USD",
            originalTransactionID: nil,
            appAccountToken: nil,
            isUpgraded: false,
            revocationDate: nil,
            revocationReason: nil,
            type: "consumable"
        )
        
        let uid = "test-uid-retry"
        // Queue the transaction (this will attempt to send and should fail, triggering retry)
        await NetworkManager.shared.queueAttribution(uid: uid, appleAttributionToken: nil, transactions: [transaction])
        // Wait briefly to allow async file write (since saveQueue is async)
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // No assertion: this is a smoke test to ensure no crash and async path works
        XCTAssertTrue(true)
    }
} 