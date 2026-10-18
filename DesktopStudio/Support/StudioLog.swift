import os

enum StudioLog {
    static let persistence = Logger(subsystem: "com.desktopstudio.app", category: "persistence")
    static let editor = Logger(subsystem: "com.desktopstudio.app", category: "editor")
    static let runtime = Logger(subsystem: "com.desktopstudio.app", category: "runtime")
}
