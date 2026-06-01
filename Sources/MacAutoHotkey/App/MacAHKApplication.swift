import AppKit
import Foundation

@MainActor
final class MacAHKApplication: NSObject, NSApplicationDelegate {
    private static var delegate: MacAHKApplication?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var activeRuntime: AHKScriptingRuntime?
    private var activeScriptPath: String?
    private var pendingFiles: [String] = []

    static func shouldRun(arguments: [String]) -> Bool {
        let args = Array(arguments.dropFirst())
        if args.contains("--app") {
            return true
        }
        if args.contains("--help") || args.contains("-h") || args.contains("--check-accessibility") {
            return false
        }
        if args.contains(where: { !$0.hasPrefix("-") }) {
            return false
        }
        return Bundle.main.bundlePath.hasSuffix(".app")
    }

    static func run() {
        let app = NSApplication.shared
        let delegate = MacAHKApplication()
        Self.delegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        updateMenu()

        if pendingFiles.isEmpty {
            return
        } else {
            let files = pendingFiles
            pendingFiles.removeAll()
            files.forEach { runScript(at: $0) }
        }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        if statusItem.menu == nil {
            pendingFiles.append(contentsOf: filenames)
            sender.reply(toOpenOrPrint: .success)
            return
        }

        filenames.forEach { runScript(at: $0) }
        sender.reply(toOpenOrPrint: .success)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        activeRuntime?.stop()
        return .terminateNow
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "MacAutoHotkey")
            button.title = " AHK"
        }
        statusItem.menu = menu
    }

    private func updateMenu() {
        menu.removeAllItems()

        let title = activeScriptPath.map { "Running: \(URL(fileURLWithPath: $0).lastPathComponent)" } ?? "MacAutoHotkey"
        let titleItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        let openItem = NSMenuItem(title: "Open Script...", action: #selector(openScript), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        let stopItem = NSMenuItem(title: "Stop Running Script", action: #selector(stopScript), keyEquivalent: "s")
        stopItem.target = self
        stopItem.isEnabled = activeRuntime?.isRunning == true
        menu.addItem(stopItem)

        let reloadItem = NSMenuItem(title: "Reload Script", action: #selector(reloadScript), keyEquivalent: "r")
        reloadItem.target = self
        reloadItem.isEnabled = activeScriptPath != nil
        menu.addItem(reloadItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit MacAutoHotkey", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func openScript() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "ahk")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            runScript(at: url.path)
        }
    }

    @objc private func stopScript() {
        activeRuntime?.stop()
        activeRuntime = nil
        activeScriptPath = nil
        updateMenu()
    }

    @objc private func reloadScript() {
        guard let activeScriptPath else {
            return
        }
        runScript(at: activeScriptPath)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func runScript(at path: String) {
        do {
            activeRuntime?.stop()

            let source = try String(contentsOfFile: path, encoding: .utf8)
            let parser = ScriptParser(source: source, fileName: path)
            let script = try parser.parse()

            let runtime = AHKScriptingRuntime(
                script: script,
                automation: MacAutomation(),
                hotkeyManager: GlobalHotkeyManager(),
                hotstringManager: HotstringManager()
            )

            try runtime.start(enterRunLoop: false, announce: false)
            activeRuntime = runtime.isPersistent ? runtime : nil
            activeScriptPath = runtime.isPersistent ? path : nil
            updateMenu()
        } catch {
            activeRuntime = nil
            activeScriptPath = nil
            updateMenu()
            showError(error, scriptPath: path)
        }
    }

    private func showError(_ error: Error, scriptPath: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Could not run \(URL(fileURLWithPath: scriptPath).lastPathComponent)"
        alert.informativeText = (error as? AHKError)?.message ?? error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
