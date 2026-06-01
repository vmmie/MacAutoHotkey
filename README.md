# MacAutoHotkey

MacAutoHotkey is an experimental native macOS runtime for a focused AutoHotkey v2-style subset. It is designed as a real foundation for a future macOS-compatible AutoHotkey implementation, not as a wrapper around Windows APIs.

The current executable is `macahk`, a CLI tool that loads `.ahk` files, parses a small v2-oriented syntax subset, registers global hotkeys/hotstrings, and uses macOS Accessibility/CoreGraphics/AppKit APIs for automation.

## Technology Choice

For the first macOS-native foundation, Swift is the most pragmatic primary language:

- macOS APIs are first-class from Swift: Accessibility, CoreGraphics event taps, AppKit dialogs, pasteboard, and run loop integration.
- A CLI can later grow an optional SwiftUI/AppKit GUI without replacing the runtime.
- The parser/runtime boundary is explicit, so a future C++ bridge to upstream AutoHotkey internals or a Rust parser can be introduced behind stable Swift protocols.
- Shipping and signing a native macOS tool is simpler than starting with a cross-platform GUI stack.

Why not directly port the official C++ AutoHotkey repository first? AutoHotkey is historically Windows automation software and its upstream runtime is deeply tied to Win32 concepts such as window handles, message loops, hooks, registry access, COM, and Windows control automation. Reusing syntax and semantic knowledge is valuable, but macOS input, windows, accessibility, and application automation need native implementations.

Sources checked during initial analysis:

- Official repository: <https://github.com/AutoHotkey/AutoHotkey>
- Official v2 documentation entry point: <https://www.autohotkey.com/docs/v2/>

## Current Features

Implemented in this prototype:

- `.ahk` file loading
- v2-style `:=` variable assignment
- Simple string, number, and variable expressions
- Global hotkeys with AHK modifier syntax:
  - `^` Control
  - `!` Option
  - `+` Shift
  - `#` Command
- Inline hotkeys, for example:
  - `^j::MsgBox "Hello from macOS AHK"`
- Block hotkeys with braces
- Simple hotstrings, for example:
  - `::brb::be right back`
- `MsgBox`
- `Send`
- `MouseMove`
- `Click`
- `Sleep`

## Download and Use

Most users should download the release ZIP instead of building from source.

1. Open the GitHub Releases page for this repository.
2. Download `MacAutoHotkey-0.1.0-macos-arm64.zip`.
3. Unzip the file.
4. Open Terminal in the unzipped `MacAutoHotkey-0.1.0` folder.
5. Make the executable runnable:

```sh
chmod +x macahk
```

Check whether macOS automation permission is available:

```sh
./macahk --check-accessibility
```

If permission is not granted, enable it in:

`System Settings > Privacy & Security > Accessibility`

Add Terminal, iTerm, or the `macahk` binary, depending on how you launch it. Depending on your macOS version, keyboard monitoring may also require:

`System Settings > Privacy & Security > Input Monitoring`

Run the included hotkey example:

```sh
./macahk Examples/hello.ahk
```

Then press `Control + J`. A message box should appear with:

```text
Hello from macOS AHK
```

Run your own script:

```sh
./macahk path/to/script.ahk
```

Example script:

```ahk
#Requires AutoHotkey v2.0

^j::MsgBox "Hello from macOS AHK"
```

Stop a running script with `Control + C` in Terminal.

### Gatekeeper

The current release binary is not code-signed or notarized. macOS may block it after download. If that happens, remove the quarantine attribute from the unzipped folder:

```sh
xattr -dr com.apple.quarantine .
```

Then run the permission check again:

```sh
./macahk --check-accessibility
```

## Build

Requirements:

- macOS 14 or newer
- Xcode command line tools
- Swift 6 or newer

Build:

```sh
swift build
```

Run the hello example:

```sh
swift run macahk Examples/hello.ahk
```

Check Accessibility permission:

```sh
swift run macahk --check-accessibility
```

macOS must allow the built tool or Terminal/iTerm in:

`System Settings > Privacy & Security > Accessibility`

Depending on your macOS version, keyboard monitoring may also require:

`System Settings > Privacy & Security > Input Monitoring`

## Examples

`Examples/hello.ahk`:

```ahk
#Requires AutoHotkey v2.0

^j::MsgBox "Hello from macOS AHK"
```

`Examples/automation.ahk`:

```ahk
#Requires AutoHotkey v2.0

name := "macOS"

^!h::
{
    MsgBox name
}

^!s::Send "Typed by macahk"

^!m::
{
    MouseMove 400, 400
    Click
}

::brb::be right back
```

## Architecture

The code is intentionally split into small layers:

- `Parsing`: reads a v2-style subset and produces a small AST.
- `Runtime`: evaluates actions and owns script state.
- `macOS`: implements platform-specific hotkeys, hotstrings, input synthesis, mouse events, and dialogs.
- `CLI`: command-line entry point and user-facing options.

This keeps AHK syntax compatibility separate from macOS automation. Future parser work should expand the AST and evaluator without leaking CoreGraphics or AppKit concepts into the language layer.

## Portability Assessment

Directly portable or mostly language-level:

- v2 expression grammar
- variable scoping rules
- function calls
- arrays/maps/objects, once implemented
- control flow
- script include/loading behavior
- many string and math built-ins

Needs macOS-specific implementation:

- hotkeys and low-level keyboard hooks
- hotstrings and text replacement
- `Send`, keyboard layouts, Unicode text input, dead keys
- mouse movement, click, drag, scroll
- `MsgBox` and future GUI APIs
- window discovery, activation, geometry, and focus
- application automation through Accessibility, AppleScript/JXA, or app-specific APIs

Windows-only or not directly portable:

- Win32 window handles and messages
- Registry APIs
- COM automation
- Windows controls and UI Automation assumptions
- DLL calls that target Windows libraries
- tray behavior that depends on Windows shell APIs

## Limitations

This is an early runtime, not a complete AutoHotkey implementation.

- The parser supports a narrow v2-style subset.
- Expressions do not yet support operators, function definitions, objects, arrays, or interpolation.
- Hotkey parsing handles common keys but not the full AHK key grammar.
- `Send` is ASCII-oriented and falls back to pasteboard for unsupported characters.
- Hotstrings are simple suffix replacements and do not yet implement AHK options.
- Window, process, image search, clipboard, GUI, and file APIs are not implemented yet.
- macOS security prompts and permissions are required for useful automation.

## Roadmap

1. Replace the line parser with a lexer/parser that models more of AutoHotkey v2.
2. Add expression operators, function calls, blocks, conditionals, and loops.
3. Expand key grammar and keyboard layout handling.
4. Add richer hotstring options and ending-character rules.
5. Implement window/application APIs on top of Accessibility.
6. Add a SwiftUI menu-bar companion app for script status, reload, logs, and permissions.
7. Add conformance tests using representative AHK v2 scripts.
8. Investigate whether selected upstream AutoHotkey C++ parser/runtime pieces can be bridged cleanly without importing Win32 assumptions.

## License

MacAutoHotkey is licensed under the GNU General Public License v2.0. See `LICENSE`.
