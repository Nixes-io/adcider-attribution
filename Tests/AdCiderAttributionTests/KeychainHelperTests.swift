import XCTest
@testable import AdCiderAttribution

@MainActor
final class KeychainHelperTests: XCTestCase {
    
    override func setUp() async throws {
        // Configure with a test service name to avoid conflicts
        await KeychainHelper.shared.configure(service: "com.adcider.attribution.test")
        // Clean up any existing test data
        _ = await KeychainHelper.shared.removeUID()
    }
    
    override func tearDown() async throws {
        // Clean up test data
        _ = await KeychainHelper.shared.removeUID()
    }
    
    func testUIDGeneration() async {
        let uid1 = await KeychainHelper.shared.getUID()
        let uid2 = await KeychainHelper.shared.getUID()
        
        // Should return the same UID on subsequent calls
        XCTAssertEqual(uid1, uid2)
        XCTAssertFalse(uid1.isEmpty)
        XCTAssertTrue(UUID(uuidString: uid1) != nil, "UID should be a valid UUID")
    }
    
    func testUIDPersistence() async {
        let originalUID = await KeychainHelper.shared.getUID()
        
        // Reconfigure the same helper (simulating app restart)
        await KeychainHelper.shared.configure(service: "com.adcider.attribution.test")
        let retrievedUID = await KeychainHelper.shared.getUID()
        
        // Should retrieve the same UID
        XCTAssertEqual(originalUID, retrievedUID)
    }
    
    func testUIDRemoval() async {
        // Generate a UID
        let originalUID = await KeychainHelper.shared.getUID()
        XCTAssertFalse(originalUID.isEmpty)
        
        // Remove it
        let removeResult = await KeychainHelper.shared.removeUID()
        XCTAssertTrue(removeResult)
        
        // Generate a new UID - should be different
        let newUID = await KeychainHelper.shared.getUID()
        XCTAssertNotEqual(originalUID, newUID)
    }
    
    func testRemoveNonExistentUID() async {
        // Ensure no UID exists
        _ = await KeychainHelper.shared.removeUID()
        
        // Try to remove again - should still return true (success)
        let result = await KeychainHelper.shared.removeUID()
        XCTAssertTrue(result)
    }
    
    func testServiceConfiguration() async {
        // Configure with custom service
        await KeychainHelper.shared.configure(service: "com.test.custom")
        
        let uid1 = await KeychainHelper.shared.getUID()
        
        // Configure with different service
        await KeychainHelper.shared.configure(service: "com.test.different")
        
        let uid2 = await KeychainHelper.shared.getUID()
        
        // Should generate different UIDs for different services
        XCTAssertNotEqual(uid1, uid2)
    }
    
    func testUIDFormat() async {
        let uid = await KeychainHelper.shared.getUID()
        
        // Should be a valid UUID string
        XCTAssertNotNil(UUID(uuidString: uid), "Generated UID should be a valid UUID format")
        XCTAssertEqual(uid.count, 36, "UUID should be 36 characters long")
        XCTAssertTrue(uid.contains("-"), "UUID should contain hyphens")
    }
} 