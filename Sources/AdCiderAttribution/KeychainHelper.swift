import Foundation
import Security

actor KeychainHelper {
    static let shared: KeychainHelper = KeychainHelper()
    private init() {}
    
    private var service: String = Constants.keychainService
    private let account: String = Constants.keychainAccount
    
    // Configure the keychain service name (useful for testing or custom configurations)
    func configure(service: String) {
        self.service = service
        logDebug("KeychainHelper configured with service: \(service)")
    }
    
    func getUID() async -> String {
        if let uid: String = await read() {
            logDebug("Retrieved existing UID from keychain")
            return uid
        } else {
            let newUID: String = UUID().uuidString
            if await save(uid: newUID) {
                logInfo("Generated and saved new UID to keychain")
                return newUID
            } else {
                logError("Failed to save UID to keychain, using temporary UID")
                return newUID // Return the UID even if we can't save it
            }
        }
    }
    
    private func read() async -> String? {
        return await withCheckedContinuation { continuation in
            Task.detached(priority: .utility) {
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: await self.service,
                    kSecAttrAccount as String: self.account,
                    kSecReturnData as String: true,
                    kSecMatchLimit as String: kSecMatchLimitOne
                ]
                
                var dataTypeRef: AnyObject?
                let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
                
                switch status {
                case errSecSuccess:
                    if let data = dataTypeRef as? Data, let uid = String(data: data, encoding: .utf8) {
                        continuation.resume(returning: uid)
                    } else {
                        logError("Failed to decode UID data from keychain")
                        continuation.resume(returning: nil)
                    }
                case errSecItemNotFound:
                    logDebug("No UID found in keychain")
                    continuation.resume(returning: nil)
                default:
                    logError("Keychain read error: \(status)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    @discardableResult
    private func save(uid: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            Task.detached(priority: .utility) {
                guard let data = uid.data(using: .utf8) else {
                    logError("Failed to encode UID as UTF8 data")
                    continuation.resume(returning: false)
                    return
                }
                
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: await self.service,
                    kSecAttrAccount as String: self.account,
                    kSecValueData as String: data
                ]
                
                // Delete any existing item first
                SecItemDelete(query as CFDictionary)
                
                // Add the new item
                let status = SecItemAdd(query as CFDictionary, nil)
                
                switch status {
                case errSecSuccess:
                    logDebug("Successfully saved UID to keychain")
                    continuation.resume(returning: true)
                default:
                    logError("Failed to save UID to keychain: \(status)")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    // Remove the stored UID (useful for testing or reset scenarios)
    func removeUID() async -> Bool {
        return await withCheckedContinuation { continuation in
            Task.detached(priority: .utility) {
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: await self.service,
                    kSecAttrAccount as String: self.account
                ]
                
                let status = SecItemDelete(query as CFDictionary)
                
                switch status {
                case errSecSuccess:
                    logInfo("Successfully removed UID from keychain")
                    continuation.resume(returning: true)
                case errSecItemNotFound:
                    logDebug("No UID found to remove from keychain")
                    continuation.resume(returning: true) // Consider this success
                default:
                    logError("Failed to remove UID from keychain: \(status)")
                    continuation.resume(returning: false)
                }
            }
        }
    }
} 