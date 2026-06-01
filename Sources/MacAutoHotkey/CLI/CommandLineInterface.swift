import Foundation

final class CommandLineInterface {
    func run(arguments: [String]) throws {
        let args = Array(arguments.dropFirst())

        if args.isEmpty || args.contains("--help") || args.contains("-h") {
            printHelp()
            return
        }

        if args.contains("--check-accessibility") {
            let automation = MacAutomation()
            if automation.hasAccessibilityPermission(prompt: true) {
                print("Accessibility permission is granted.")
            } else {
                print("Accessibility permission is not granted. Enable it in System Settings > Privacy & Security > Accessibility.")
            }
            return
        }

        if args.contains("--check-script") {
            guard let scriptPath = args.first(where: { !$0.hasPrefix("-") }) else {
                throw AHKError("Missing script path.")
            }
            let script = try loadScript(at: scriptPath)
            print("Script OK: \(scriptPath)")
            print("Top-level actions: \(script.topLevelActions.count)")
            print("Hotkeys: \(script.hotkeys.count)")
            print("Hotstrings: \(script.hotstrings.count)")
            return
        }

        guard let scriptPath = args.first(where: { !$0.hasPrefix("-") }) else {
            throw AHKError("Missing script path.")
        }

        let script = try loadScript(at: scriptPath)

        let runtime = AHKScriptingRuntime(
            script: script,
            automation: MacAutomation(),
            hotkeyManager: GlobalHotkeyManager(),
            hotstringManager: HotstringManager()
        )

        try runtime.start()
    }

    private func loadScript(at scriptPath: String) throws -> AHKScript {
        let source = try String(contentsOfFile: scriptPath, encoding: .utf8)
        let parser = ScriptParser(source: source, fileName: scriptPath)
        return try parser.parse()
    }

    private func printHelp() {
        print("""
        macahk - experimental AutoHotkey v2 style runtime for macOS

        Usage:
          macahk <script.ahk>
          macahk --check-script <script.ahk>
          macahk --check-accessibility

        This prototype supports a focused v2-style subset:
          hotkeys, hotstrings, := variables, MsgBox, Send, MouseMove, Click, Sleep
        """)
    }
}
