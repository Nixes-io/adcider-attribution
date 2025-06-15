import XCTest
@testable import AdCiderAttribution

final class AttributionIntegrationTests: XCTestCase {
    
    func testSendRealAttribution() async throws {
        // Skip this test if no environment variables are set
        // This prevents the test from failing in CI/CD environments
        guard let backendURLString = ProcessInfo.processInfo.environment["ADCIDER_TEST_BACKEND_URL"],
              let apiKey = ProcessInfo.processInfo.environment["ADCIDER_TEST_API_KEY"],
              let backendURL = URL(string: backendURLString) else {
            throw XCTSkip("Integration test skipped: Set ADCIDER_TEST_BACKEND_URL and ADCIDER_TEST_API_KEY environment variables to run")
        }
        
        let payload = TestBatchPayload(
            uid: "test-uid-\(UUID().uuidString.prefix(8))",
            bundleId: "com.example.app",
            appleAttributionToken: "test-token",
            transactions: []
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(payload)
        print("[Test] Sending JSON: \(String(data: jsonData, encoding: .utf8)!)")

        let success = await NetworkManager.sendTestBatch(
            batch: payload,
            backendURL: backendURL,
            apiKey: apiKey
        )
        XCTAssertTrue(success, "Attribution POST should succeed (check backend logs for actual receipt)")
    }
}

// Test-only DTOs matching our current implementation
struct TestTransaction: Codable {
    let transactionId: String
    let productID: String
    let purchaseDate: String
    let quantity: Int
    let price: Double?
    let currencyCode: String?
    let originalTransactionID: String?
    let appAccountToken: String?
    let isUpgraded: Bool
    let revocationDate: String?
    let revocationReason: String?
    let type: String
}

struct TestBatchPayload: Codable {
    let uid: String
    let bundleId: String
    let appleAttributionToken: String?
    let transactions: [TestTransaction]
}

extension NetworkManager {
    static func sendTestBatch(batch: TestBatchPayload, backendURL: URL, apiKey: String) async -> Bool {
        var request = URLRequest(url: backendURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        do {
            let data = try JSONEncoder().encode(batch)
            request.httpBody = data
            print("[Test] Sending POST to \(backendURL): \(String(data: data, encoding: .utf8) ?? "<encoding error>")")
        } catch {
            print("[Test] Failed to encode request: \(error)")
            return false
        }
        return await withCheckedContinuation { continuation in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("[Test] Network error: \(error)")
                    continuation.resume(returning: false)
                    return
                }
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    print("[Test] Server error: \(http.statusCode)")
                    if let data = data, let body = String(data: data, encoding: .utf8) {
                        print("[Test] Response body: \(body)")
                    }
                    continuation.resume(returning: false)
                    return
                }
                print("[Test] Request succeeded: \(response.debugDescription)")
                continuation.resume(returning: true)
            }
            task.resume()
        }
    }
} 