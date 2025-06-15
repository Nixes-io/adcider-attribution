import Foundation
import StoreKit

actor TransactionObserver {
    static let shared = TransactionObserver()
    private init() {}
    
    private var transactionListener: Task<Void, Error>?
    private var uid: String = ""
    
    func start() async {
        logInfo("Starting TransactionObserver")
        
        // Get UID
        self.uid = await KeychainHelper.shared.getUID()
        
        // Start observing transactions
        await observeTransactions()
    }
    
    func stop() async {
        logInfo("Stopping TransactionObserver")
        transactionListener?.cancel()
        transactionListener = nil
    }
    
    private func observeTransactions() async {
        logInfo("Starting transaction observation")
        
        transactionListener = Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try result.payloadValue
                    await self?.handleTransaction(transaction)
                } catch {
                    logError("Failed to process transaction update", error: error)
                }
            }
        }
    }
    
    private func handleTransaction(_ transaction: Transaction) async {
        logDebug("Processing transaction \(transaction.id)")
        
        // Get product info for the transaction
        let product = await ProductCache.shared.product(for: transaction.productID)
        let codableTransaction = CodableTransaction(from: transaction, product: product)
        
        logDebug("Queuing transaction \(transaction.id) for UID: \(uid)")
        
        // Queue the transaction for batch sending
        await NetworkManager.shared.queueAttribution(uid: uid, appleAttributionToken: nil, transactions: [codableTransaction])
    }
} 