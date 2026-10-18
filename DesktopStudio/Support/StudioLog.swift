import os

enum StudioLog {
    static let persistence = Logger(subsystem: "com.desktopstudio.app", category: "persistence")
    static let editor = Logger(subsystem: "com.desktopstudio.app", category: "editor")
}
