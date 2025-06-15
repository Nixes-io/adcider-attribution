import Foundation
import os.log

// Logging levels for AdCider Attribution SDK
public enum AdCiderLogLevel: Int, CaseIterable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case none = 4
    
    var description: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .none: return "NONE"
        }
    }
}

// Internal logger for AdCider Attribution SDK
internal final class AdCiderLogger: @unchecked Sendable {
    static let shared = AdCiderLogger()
    
    private let osLog = OSLog(subsystem: "com.adcider.attribution", category: "AdCiderAttribution")
    private var currentLogLevel: AdCiderLogLevel = .warning
    private var enableDebugLogging: Bool = false
    
    private init() {}
    
    // Configure the logger with settings from AdCiderConfiguration
    func configure(logLevel: AdCiderLogLevel, enableDebugLogging: Bool) {
        self.currentLogLevel = logLevel
        self.enableDebugLogging = enableDebugLogging
    }
    
    // Log a debug message
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, file: file, function: function, line: line)
    }
    
    // Log an info message
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, file: file, function: function, line: line)
    }
    
    // Log a warning message
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, file: file, function: function, line: line)
    }
    
    // Log an error message
    func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var fullMessage = message
        if let error = error {
            fullMessage += " - Error: \(error.localizedDescription)"
        }
        log(level: .error, message: fullMessage, file: file, function: function, line: line)
    }
    
    // Internal logging method
    private func log(level: AdCiderLogLevel, message: String, file: String, function: String, line: Int) {
        guard level.rawValue >= currentLogLevel.rawValue else { return }
        
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(level.description)] [\(fileName):\(line)] \(function) - \(message)"
        
        // Use os_log for better performance and integration with system logging
        switch level {
        case .debug:
            if enableDebugLogging {
                os_log("%{public}@", log: osLog, type: .debug, logMessage)
            }
        case .info:
            os_log("%{public}@", log: osLog, type: .info, logMessage)
        case .warning:
            os_log("%{public}@", log: osLog, type: .default, logMessage)
        case .error:
            os_log("%{public}@", log: osLog, type: .error, logMessage)
        case .none:
            break
        }
        
        // Also print to console in debug builds for easier development
        #if DEBUG
        if enableDebugLogging || level.rawValue >= AdCiderLogLevel.warning.rawValue {
            print("[AdCider] \(logMessage)")
        }
        #endif
    }
}

// Convenience logging functions for internal use
internal func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    AdCiderLogger.shared.debug(message, file: file, function: function, line: line)
}

internal func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    AdCiderLogger.shared.info(message, file: file, function: function, line: line)
}

internal func logWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    AdCiderLogger.shared.warning(message, file: file, function: function, line: line)
}

internal func logError(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    AdCiderLogger.shared.error(message, error: error, file: file, function: function, line: line)
} 