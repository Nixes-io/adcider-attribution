import Foundation
import StoreKit

struct CodableTransaction: Codable {
    let transactionId: String
    let productID: String
    let purchaseDate: Date
    let quantity: Int
    let price: Decimal?
    let currencyCode: String?
    let originalTransactionID: UInt64?
    let appAccountToken: UUID?
    let isUpgraded: Bool
    let revocationDate: Date?
    let revocationReason: String?
    let type: String
    
    init(from transaction: Transaction, product: Product?) {
        self.transactionId = String(transaction.id)
        self.productID = transaction.productID
        self.purchaseDate = transaction.purchaseDate
        self.quantity = transaction.purchasedQuantity
        self.price = transaction.price
        self.currencyCode = transaction.currencyCode
        self.originalTransactionID = transaction.originalID
        self.appAccountToken = transaction.appAccountToken
        self.isUpgraded = transaction.isUpgraded
        self.revocationDate = transaction.revocationDate
        self.revocationReason = transaction.revocationReason.map {
            switch $0 {
            case .developerIssue: return "Developer Issue"
            case .other: return "Other"
            default: return "Unknown"
            }
        }
        self.type = CodableTransaction.classifyType(transaction: transaction, product: product)
    }

    static func classifyType(transaction: Transaction, product: Product?) -> String {
        guard let product = product else { return "unknown" }
        switch product.type {
        case .consumable: return "consumable"
        case .nonConsumable: return "non-consumable"
        case .autoRenewable, .nonRenewable:
            if let subscription = product.subscription, let offer = subscription.introductoryOffer, offer.type == .introductory {
                return "trial"
            }
            return "subscription"
        default: return "unknown"
        }
    }

    public init(
        transactionId: String,
        productID: String,
        purchaseDate: Date,
        quantity: Int,
        price: Decimal?,
        currencyCode: String?,
        originalTransactionID: UInt64?,
        appAccountToken: UUID?,
        isUpgraded: Bool,
        revocationDate: Date?,
        revocationReason: String?,
        type: String
    ) {
        self.transactionId = transactionId
        self.productID = productID
        self.purchaseDate = purchaseDate
        self.quantity = quantity
        self.price = price
        self.currencyCode = currencyCode
        self.originalTransactionID = originalTransactionID
        self.appAccountToken = appAccountToken
        self.isUpgraded = isUpgraded
        self.revocationDate = revocationDate
        self.revocationReason = revocationReason
        self.type = type
    }
}

struct BatchPayload: Codable {
    let uid: String
    let bundleId: String?
    let appleAttributionToken: String?
    let transactions: [CodableTransaction]
}

struct RetryRequest: Codable {
    let batch: BatchPayload
    let attemptCount: Int
    let lastAttempt: Date
}

actor NetworkManager {
    static let shared = NetworkManager()
    private init() {
        Task {
            await loadQueue()
            await scheduleRetryIfNeeded()
        }
    }
    
    private var apiKey: String? = nil
    
    public func configure(apiKey: String) {
        self.apiKey = apiKey
        logInfo("NetworkManager configured with backend URL: \(backendURL.absoluteString)")
    }
    
    public func cleanup() {
        logInfo("Cleaning up NetworkManager")
        retryQueue.removeAll()
        pendingTransactions.removeAll()
        pendingAppleAttributionToken = nil
        pendingUid = nil
        isRetryScheduled = false
        logDebug("NetworkManager cleanup completed")
    }
    
    private var retryQueue: [RetryRequest] = [] {
        didSet { Task { await saveQueue() } }
    }
    private var isRetryScheduled = false
    private let queueFileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("adcider_retry_queue.json")
    }()
    
    // Simple deduplication with sent transaction IDs
    private let sentTransactionIdsFileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("adcider_sent_transaction_ids.json")
    }()
    private var sentTransactionIds: Set<String> = []
    
    private var backendURL: URL {
        return URL(string: Constants.backendURLString)!
    }
    
    // Buffer for batching
    private var pendingAppleAttributionToken: String?
    private var pendingTransactions: [CodableTransaction] = []
    private var pendingUid: String?
    
    private func loadSentIds() async {
        do {
            let data = try Data(contentsOf: sentTransactionIdsFileURL)
            sentTransactionIds = try JSONDecoder().decode(Set<String>.self, from: data)
            logDebug("Loaded \(sentTransactionIds.count) sent transaction IDs")
        } catch {
            sentTransactionIds = []
        }
    }
    
    private func saveSentIds() async {
        do {
            let data = try JSONEncoder().encode(sentTransactionIds)
            try data.write(to: sentTransactionIdsFileURL)
        } catch {
            logError("Failed to save sent transaction IDs", error: error)
        }
    }
    
    public func queueAttribution(uid: String, appleAttributionToken: String?, transactions: [CodableTransaction]) async {
        await loadSentIds()
        
        self.pendingUid = uid
        if let token = appleAttributionToken {
            self.pendingAppleAttributionToken = token
        }
        self.pendingTransactions.append(contentsOf: transactions)
        
        await trySendBatch()
    }
    
    private func trySendBatch() async {
        guard let uid = pendingUid, (pendingAppleAttributionToken != nil || !pendingTransactions.isEmpty) else { return }
        
        let bundleId = Bundle.main.bundleIdentifier
        let newTransactions = pendingTransactions.filter { !sentTransactionIds.contains($0.transactionId) }
        
        if newTransactions.isEmpty && pendingAppleAttributionToken == nil { return }
        
        let batch = BatchPayload(
            uid: uid,
            bundleId: bundleId,
            appleAttributionToken: pendingAppleAttributionToken,
            transactions: newTransactions
        )
        
        let success = await sendBatch(batch)
        if success {
            logDebug("Successfully sent batch - UID: \(uid), Transactions: \(newTransactions.count)")
            for tx in newTransactions { sentTransactionIds.insert(tx.transactionId) }
            await saveSentIds()
            self.pendingAppleAttributionToken = nil
            self.pendingTransactions.removeAll(where: { tx in newTransactions.contains(where: { $0.transactionId == tx.transactionId }) })
            self.pendingUid = nil
        } else {
            logWarning("Failed to send batch, queuing for retry - UID: \(uid), Transactions: \(newTransactions.count)")
            await queueForRetry(batch)
        }
    }
    
    private func sendBatch(_ batch: BatchPayload) async -> Bool {
        return await postJSON(to: backendURL, body: batch)
    }
    
    private func postJSON<T: Codable>(to url: URL, body: T) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("AdCiderAttribution/1.0", forHTTPHeaderField: "User-Agent")
        
        request.timeoutInterval = 30 // Default timeout of 30 seconds
        
        if let apiKey = self.apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(body)
            request.httpBody = data
            
            logDebug("Sending POST to \(url.absoluteString)")
            if let jsonString = String(data: data, encoding: .utf8) {
                logDebug("Request payload: \(jsonString)")
            }
        } catch {
            logError("Failed to encode request", error: error)
            return false
        }
        
        return await withCheckedContinuation { continuation in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    logError("Network request failed", error: error)
                    continuation.resume(returning: false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    logError("Invalid response type")
                    continuation.resume(returning: false)
                    return
                }
                
                if (200...299).contains(httpResponse.statusCode) {
                    logInfo("Request succeeded with status \(httpResponse.statusCode)")
                    continuation.resume(returning: true)
                } else {
                    var errorMessage = "Server returned status \(httpResponse.statusCode)"
                    if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                        errorMessage += " - Response: \(responseBody)"
                    }
                    logError(errorMessage)
                    continuation.resume(returning: false)
                }
            }
            task.resume()
        }
    }
    
    private func queueForRetry(_ batch: BatchPayload) async {
        let retryRequest = RetryRequest(
            batch: batch,
            attemptCount: 0,
            lastAttempt: Date()
        )
        retryQueue.append(retryRequest)
        await scheduleRetryIfNeeded()
    }
    
    private func scheduleRetryIfNeeded() async {
        guard !isRetryScheduled, !retryQueue.isEmpty else { return }
        isRetryScheduled = true
        
        let retryDelay = RetryHelper.exponentialBackoffDelay(attempt: 0)
        let nanoseconds = UInt64(retryDelay * 1_000_000_000)
        
        logInfo("Scheduling retry in \(retryDelay) seconds for \(retryQueue.count) requests")
        
        Task.detached { [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            await self?.retryAll()
        }
    }
    
    private func retryAll() async {
        let queue = retryQueue
        retryQueue.removeAll()
        isRetryScheduled = false
        
        logInfo("Processing retry queue with \(queue.count) requests")
        
        for request in queue {
            let maxAttempts = 3 // Default max retry attempts
            
            guard request.attemptCount < maxAttempts else {
                logWarning("Max retry attempts reached for UID: \(request.batch.uid)")
                continue
            }
            
            let newAttemptCount = request.attemptCount + 1
            logInfo("Retrying batch for UID: \(request.batch.uid), attempt: \(newAttemptCount)")
            
            let success = await sendBatch(request.batch)
            if success {
                logInfo("Retry successful for UID: \(request.batch.uid)")
            } else {
                logWarning("Retry failed for UID: \(request.batch.uid), will try again later")
                let updatedRequest = RetryRequest(
                    batch: request.batch,
                    attemptCount: newAttemptCount,
                    lastAttempt: Date()
                )
                retryQueue.append(updatedRequest)
            }
        }
        
        if !retryQueue.isEmpty {
            await scheduleRetryIfNeeded()
        }
    }
    
    private func saveQueue() async {
        do {
            let data = try JSONEncoder().encode(retryQueue)
            try data.write(to: queueFileURL)
            logDebug("Saved retry queue with \(retryQueue.count) items")
        } catch {
            logError("Failed to save retry queue", error: error)
        }
    }
    
    private func loadQueue() async {
        do {
            let data = try Data(contentsOf: queueFileURL)
            retryQueue = try JSONDecoder().decode([RetryRequest].self, from: data)
            logDebug("Loaded retry queue with \(retryQueue.count) items")
        } catch {
            retryQueue = []
        }
    }
}

actor ProductCache {
    static let shared = ProductCache()
    private var cache: [String: Product] = [:]
    
    func product(for productID: String) async -> Product? {
        if let cached = cache[productID] {
            return cached
        }
        do {
            let products = try await Product.products(for: [productID])
            if let product = products.first {
                cache[productID] = product
                return product
            }
        } catch {
            print("[AdCider] Failed to fetch Product for id \(productID): \(error)")
        }
        return nil
    }
} 
