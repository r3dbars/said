import OSLog

enum SaidLogger {
    private static let subsystem = "app.said.Said"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let capture = Logger(subsystem: subsystem, category: "capture")
    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let model = Logger(subsystem: subsystem, category: "model")
    static let asr = Logger(subsystem: subsystem, category: "asr")
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
