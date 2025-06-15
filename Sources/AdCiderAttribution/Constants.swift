import Foundation

struct Constants {
    // Keychain
    static let keychainService = "com.adcider.attribution"
    static let keychainAccount = "installation_uid"
    
    // Retry queue
    static let retryQueueFileName = "adcider_retry_queue.json"
    
    // Backend
    static let backendURLString = "https://app.adcider.com/app-api/attribution"
} 