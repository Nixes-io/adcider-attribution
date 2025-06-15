import Foundation
import StoreKit

// Errors that can occur during AdCider Attribution operations
public enum AdCiderError: Error, LocalizedError {
    case invalidConfiguration(String)
    case initializationFailed(String)
    case networkError(Error)
    case attributionTokenFailed(Error)
    case keychainError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .initializationFailed(let message):
            return "Initialization failed: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .attributionTokenFailed(let error):
            return "Attribution token error: \(error.localizedDescription)"
        case .keychainError(let message):
            return "Keychain error: \(message)"
        }
    }
}

// Actor to manage SDK state safely across threads
private actor SDKState {
    private var isInitialized = false
    private var apiKey: String?
    private var enableDebugLogging: Bool = false
    
    func getInitializationState() -> (Bool, String?, Bool) {
        return (isInitialized, apiKey, enableDebugLogging)
    }
    
    func setInitialized(_ initialized: Bool, apiKey: String?, enableDebugLogging: Bool) {
        self.isInitialized = initialized
        self.apiKey = apiKey
        self.enableDebugLogging = enableDebugLogging
    }
}

// Main class for AdCider Attribution SDK
public class AdCiderAttribution {
    
    private static let sdkState = SDKState()
    
    // Initialize the AdCider Attribution SDK
    // - Parameters:
    //   - apiKey: API key for authentication
    //   - enableDebugLogging: Enable debug logging (default: false)
    //   - completion: Optional completion handler with success/error result
    public static func initialize(
        apiKey: String,
        enableDebugLogging: Bool = false,
        completion: (@Sendable (Result<Void, AdCiderError>) -> Void)? = nil
    ) {
        // Perform initialization off the main queue
        Task.detached(priority: .utility) {
            await performInitialization(apiKey: apiKey, enableDebugLogging: enableDebugLogging, completion: completion)
        }
    }
    
    private static func performInitialization(
        apiKey: String,
        enableDebugLogging: Bool,
        completion: (@Sendable (Result<Void, AdCiderError>) -> Void)?
    ) async {
        let (isInitialized, _, _) = await sdkState.getInitializationState()
        
        guard !isInitialized else {
            await MainActor.run {
                completion?(.failure(.initializationFailed("SDK already initialized")))
            }
            return
        }
        
        // Basic validation
        guard !apiKey.isEmpty else {
            await MainActor.run {
                completion?(.failure(.invalidConfiguration("API key cannot be empty")))
            }
            return
        }
        
        // Configure logging first (safe to do off main queue)
        AdCiderLogger.shared.configure(
            logLevel: enableDebugLogging ? .debug : .warning,
            enableDebugLogging: enableDebugLogging
        )
        
        logInfo("Initializing AdCider Attribution SDK")
        
        // All initialization happens off main queue
        await NetworkManager.shared.configure(apiKey: apiKey)
        await AttributionManager.shared.start()
        await TransactionObserver.shared.start()
        
        await sdkState.setInitialized(true, apiKey: apiKey, enableDebugLogging: enableDebugLogging)
        logInfo("AdCider Attribution SDK initialized successfully")
        
        // Call completion on main queue
        await MainActor.run {
            completion?(.success(()))
        }
    }
    
    // Deinitialize the SDK and clean up resources
    public static func deinitialize() {
        Task.detached(priority: .utility) {
            let (isInitialized, _, _) = await sdkState.getInitializationState()
            guard isInitialized else { return }
            
            await NetworkManager.shared.cleanup()
            await TransactionObserver.shared.stop()
            await AttributionManager.shared.stop()
            
            await sdkState.setInitialized(false, apiKey: nil, enableDebugLogging: false)
        }
    }
    
    // Check if the SDK is initialized
    public static var initialized: Bool {
        get async {
            let (isInitialized, _, _) = await sdkState.getInitializationState()
            return isInitialized
        }
    }
    
    // Get current API key (for debugging purposes)
    public static var apiKey: String? {
        get async {
            let (_, apiKey, _) = await sdkState.getInitializationState()
            return apiKey
        }
    }
    
    // Get current debug logging setting (for debugging purposes)
    public static var debugLoggingEnabled: Bool {
        get async {
            let (_, _, enableDebugLogging) = await sdkState.getInitializationState()
            return enableDebugLogging
        }
    }
}
