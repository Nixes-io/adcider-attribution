import XCTest
@testable import AdCiderAttribution

@MainActor
final class AdCiderAttributionTests: XCTestCase {
    
    override func setUp() async throws {
        // Clean up any previous state
        AdCiderAttribution.deinitialize()
    }
    
    override func tearDown() async throws {
        // Clean up after each test
        AdCiderAttribution.deinitialize()
    }
    
    func testInitializationWithValidConfiguration() async throws {
        let expectation = expectation(description: "Initialization should succeed")
        
        AdCiderAttribution.initialize(
            apiKey: "valid-api-key-12345",
            enableDebugLogging: true
        ) { result in
            switch result {
            case .success:
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Initialization should succeed, but failed with: \(error)")
            }
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
        let isInitialized = await AdCiderAttribution.initialized
        let currentApiKey = await AdCiderAttribution.apiKey
        let debugEnabled = await AdCiderAttribution.debugLoggingEnabled
        XCTAssertTrue(isInitialized)
        XCTAssertEqual(currentApiKey, "valid-api-key-12345")
        XCTAssertTrue(debugEnabled)
    }
    
    func testInitializationWithEmptyAPIKey() async throws {
        let expectation = expectation(description: "Initialization should fail")
        
        AdCiderAttribution.initialize(apiKey: "") { result in
            switch result {
            case .success:
                XCTFail("Initialization should fail with empty API key")
            case .failure(let error):
                if case .invalidConfiguration(let message) = error {
                    XCTAssertTrue(message.contains("API key cannot be empty"))
                    expectation.fulfill()
                } else {
                    XCTFail("Expected invalidConfiguration error, got: \(error)")
                }
            }
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
        let isInitialized = await AdCiderAttribution.initialized
        XCTAssertFalse(isInitialized)
    }
    
    func testConvenienceInitializer() async throws {
        let expectation = expectation(description: "Convenience initializer should work")
        
        AdCiderAttribution.initialize(apiKey: "valid-api-key-67890") { result in
            switch result {
            case .success:
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Convenience initializer should succeed, but failed with: \(error)")
            }
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
        let isInitialized = await AdCiderAttribution.initialized
        XCTAssertTrue(isInitialized)
    }
    
    func testDoubleInitialization() async throws {
        // First initialization
        let firstExpectation = expectation(description: "First initialization should succeed")
        
        AdCiderAttribution.initialize(apiKey: "valid-api-key-11111") { result in
            switch result {
            case .success:
                firstExpectation.fulfill()
            case .failure(let error):
                XCTFail("First initialization should succeed, but failed with: \(error)")
            }
        }
        
        await fulfillment(of: [firstExpectation], timeout: 5.0)
        
        // Second initialization should fail
        let secondExpectation = expectation(description: "Second initialization should fail")
        
        AdCiderAttribution.initialize(apiKey: "valid-api-key-22222") { result in
            switch result {
            case .success:
                XCTFail("Second initialization should fail")
            case .failure(let error):
                if case .initializationFailed(let message) = error {
                    XCTAssertTrue(message.contains("already initialized"))
                    secondExpectation.fulfill()
                } else {
                    XCTFail("Expected initializationFailed error, got: \(error)")
                }
            }
        }
        
        await fulfillment(of: [secondExpectation], timeout: 5.0)
    }
    
    func testDeinitializationAndReinitialization() async throws {
        // Initialize
        let initExpectation = expectation(description: "Initialization should succeed")
        
        AdCiderAttribution.initialize(apiKey: "valid-api-key-33333") { result in
            switch result {
            case .success:
                initExpectation.fulfill()
            case .failure(let error):
                XCTFail("Initialization should succeed, but failed with: \(error)")
            }
        }
        
        await fulfillment(of: [initExpectation], timeout: 5.0)
        let isInitialized1 = await AdCiderAttribution.initialized
        XCTAssertTrue(isInitialized1)
        
        // Deinitialize
        AdCiderAttribution.deinitialize()
        
        // Wait a moment for deinitialize to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        let isInitialized2 = await AdCiderAttribution.initialized
        let currentApiKey = await AdCiderAttribution.apiKey
        XCTAssertFalse(isInitialized2)
        XCTAssertNil(currentApiKey)
        
        // Reinitialize should work
        let reinitExpectation = expectation(description: "Reinitialization should succeed")
        
        AdCiderAttribution.initialize(apiKey: "valid-api-key-44444") { result in
            switch result {
            case .success:
                reinitExpectation.fulfill()
            case .failure(let error):
                XCTFail("Reinitialization should succeed, but failed with: \(error)")
            }
        }
        
        await fulfillment(of: [reinitExpectation], timeout: 5.0)
        let isInitialized3 = await AdCiderAttribution.initialized
        let finalApiKey = await AdCiderAttribution.apiKey
        XCTAssertTrue(isInitialized3)
        XCTAssertEqual(finalApiKey, "valid-api-key-44444")
    }
    
    func testDebugLoggingOption() async throws {
        let expectation = expectation(description: "Initialization with debug logging should succeed")
        
        AdCiderAttribution.initialize(
            apiKey: "valid-api-key-55555",
            enableDebugLogging: true
        ) { result in
            switch result {
            case .success:
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Initialization should succeed, but failed with: \(error)")
            }
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
        let debugEnabled = await AdCiderAttribution.debugLoggingEnabled
        XCTAssertTrue(debugEnabled)
    }
    
    func testDefaultDebugLoggingValue() async throws {
        let expectation = expectation(description: "Initialization with default debug logging should succeed")
        
        AdCiderAttribution.initialize(apiKey: "valid-api-key-66666") { result in
            switch result {
            case .success:
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Initialization should succeed, but failed with: \(error)")
            }
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
        let debugEnabled = await AdCiderAttribution.debugLoggingEnabled
        XCTAssertFalse(debugEnabled)
    }
} 