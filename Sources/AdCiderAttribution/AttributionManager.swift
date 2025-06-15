import Foundation
import AdServices

actor AttributionManager {
    static let shared = AttributionManager()
    private init() {}
    
    private var uid: String = ""
    
    func start() async {
        logInfo("Starting AttributionManager")
        
        // Generate or retrieve UID (now async)
        self.uid = await KeychainHelper.shared.getUID()
        logDebug("Generated/retrieved UID: \(self.uid)")
        
        // Fetch attribution token
        await fetchAttributionToken { [weak self] token in
            guard let self = self else { return }
            
            Task {
                if let token = token {
                    logInfo("Attribution token fetched successfully")
                    // Queue attribution for batch sending
                    await NetworkManager.shared.queueAttribution(uid: await self.getUID(), appleAttributionToken: token, transactions: [])
                } else {
                    logInfo("No attribution token available")
                }
            }
        }
    }
    
    func stop() async {
        logInfo("Stopping AttributionManager")
        // Clean up if needed
    }
    
    private func fetchAttributionToken(completion: @escaping @Sendable (String?) -> Void) async {
        #if canImport(AdServices) && !targetEnvironment(simulator)
        do {
            let token = try await AAAttribution.attributionToken()
            completion(token)
        } catch {
            logError("Failed to fetch attribution token", error: error)
            completion(nil)
        }
        #else
        logError("Failed to fetch attribution token - Error: Attribution services are only available on iOS and iPadOS.")
        completion(nil)
        #endif
    }
    
    private func getUID() async -> String {
        return uid
    }
} 
