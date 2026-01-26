import Foundation

/// Lightweight debug logging - only prints in DEBUG builds
enum Log {
    /// Log a debug message (DEBUG builds only)
    static func debug(_ message: @autoclosure () -> String, file: String = #file, function: String = #function) {
        #if DEBUG
        let filename = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        print("[\(filename)] \(message())")
        #endif
    }
    
    /// Log an error (DEBUG builds only - use os_log for production logging)
    static func error(_ message: @autoclosure () -> String, file: String = #file) {
        #if DEBUG
        let filename = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        print("❌ [\(filename)] \(message())")
        #endif
    }
}
