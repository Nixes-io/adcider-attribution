import Foundation

// Simple exponential backoff calculation for retries
internal struct RetryHelper {
    // Calculate exponential backoff delay with jitter
    // - Parameters:
    //   - attempt: The retry attempt number (0-based)
    //   - baseDelay: Base delay in seconds (default: 60)
    //   - maxDelay: Maximum delay in seconds (default: 3600)
    // - Returns: Delay in seconds
    static func exponentialBackoffDelay(attempt: Int, baseDelay: TimeInterval = 60, maxDelay: TimeInterval = 3600) -> TimeInterval {
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt))
        let cappedDelay = min(exponentialDelay, maxDelay)
        
        // Add ±25% jitter to prevent thundering herd
        let jitterRange = cappedDelay * 0.25
        let randomJitter = Double.random(in: -jitterRange...jitterRange)
        
        return max(0, cappedDelay + randomJitter)
    }
} 