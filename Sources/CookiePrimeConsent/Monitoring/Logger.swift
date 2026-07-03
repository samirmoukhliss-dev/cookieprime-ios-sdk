// FILE: Sources/CookiePrimeConsent/Monitoring/Logger.swift
import Foundation
import OSLog

/// Unified logging system for CookiePrime SDK
public enum Logger {
    
    // MARK: - Types
    
    public enum Level: String, Sendable {
        case debug = "🐛 DEBUG"
        case info = "ℹ️ INFO"
        case warning = "⚠️ WARNING"
        case error = "❌ ERROR"
        case fatal = "💀 FATAL"
        
        public var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .fatal: return .fault
            }
        }
        
        public var emoji: String {
            switch self {
            case .debug: return "🐛"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .fatal: return "💀"
            }
        }
    }
    
    // MARK: - Properties
    
    private static let subsystem = "com.cookieprime.consent"
    private static let category = "SDK"
    
    private static let osLog = OSLog(subsystem: subsystem, category: category)
    
    /// Minimum log level to display (default: .info)
    public static var minimumLevel: Level = .info
    
    /// Whether to include timestamps in logs (default: true)
    public static var includeTimestamps = true
    
    /// Whether to include file/line information (default: true in debug)
    public static var includeSourceInfo = false
    
    #if DEBUG
    public static var includeSourceInfo = true
    #endif
    
    /// Whether to write logs to file (default: false)
    public static var writeToFile = false
    
    private static var logFileURL: URL? {
        guard writeToFile else { return nil }
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory.appendingPathComponent("cookieprime_logs.txt")
    }
    
    // MARK: - Public API
    
    /// Log a message at the specified level
    public static func log(_ level: Level, _ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        guard level.rawValue >= minimumLevel.rawValue else { return }
        
        let timestamp = includeTimestamps ? DateFormatter.iso8601.string(from: Date()) : ""
        let sourceInfo = includeSourceInfo ? " [\(URL(fileURLWithPath: file).lastPathComponent):\(line) \(function)]" : ""
        let fullMessage = "[CookiePrime] \(timestamp) \(level.emoji) \(level.rawValue)\(sourceInfo): \(message)"
        
        // Log to OSLog
        os_log("%{public}@", log: osLog, type: level.osLogType, fullMessage)
        
        // Also print in debug
        #if DEBUG
        print(fullMessage)
        #endif
        
        // Write to file if enabled
        if writeToFile {
            writeToLogFile(fullMessage)
        }
    }
    
    /// Log a debug message
    public static func debug(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        log(.debug, message, file: file, line: line, function: function)
    }
    
    /// Log an info message
    public static func info(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        log(.info, message, file: file, line: line, function: function)
    }
    
    /// Log a warning message
    public static func warning(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        log(.warning, message, file: file, line: line, function: function)
    }
    
    /// Log an error message
    public static func error(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        log(.error, message, file: file, line: line, function: function)
    }
    
    /// Log a fatal message
    public static func fatal(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        log(.fatal, message, file: file, line: line, function: function)
    }
    
    /// Log an error with its context
    public static func error(_ error: Error, context: String = "", file: String = #file, line: Int = #line, function: String = #function) {
        let message = "\(context)\(context.isEmpty ? "" : ": ")\(error.localizedDescription)"
        log(.error, message, file: file, line: line, function: function)
    }
    
    // MARK: - Private Helpers
    
    private static func writeToLogFile(_ message: String) {
        guard let url = logFileURL else { return }
        
        let messageWithNewline = message + "\n"
        
        if let data = messageWithNewline.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path) {
                if let fileHandle = try? FileHandle(forWritingTo: url) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    try? fileHandle.close()
                }
            } else {
                try? data.write(to: url)
            }
        }
    }
    
    /// Get the log file contents
    public static func getLogFileContents() -> String? {
        guard let url = logFileURL else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
    
    /// Clear the log file
    public static func clearLogFile() {
        guard let url = logFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}