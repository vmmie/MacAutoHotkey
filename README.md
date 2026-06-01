# MacAutoHotkey

MacAutoHotkey is an experimental native macOS runtime for a focused AutoHotkey v2-style subset. It is designed as a real foundation for a future macOS-compatible AutoHotkey implementation, not as a wrapper around Windows APIs.

The release ships as `MacAutoHotkey.app`, a menu-bar app that opens `.ahk` files and lets you stop running scripts from the menu bar. The app also contains the `macahk` CLI for terminal workflows. Both modes use the same parser/runtime and macOS Accessibility/CoreGraphics/AppKit automation layer.

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
- Basic expression operators: `+`, `-`, `*`, `/`, `.`, comparisons, `&&`, `||`, `!`
- Counted `Loop` blocks with `A_Index`
- Basic `if` blocks
- macOS menu-bar app with `Open Script...`, `Stop Running Script`, and `Quit`
- `.ahk` document registration for setting MacAutoHotkey as the default app in Finder

## Download and Use

Most users should download the release ZIP instead of building from source.

1. Open the GitHub Releases page for this repository.
2. Download `MacAutoHotkey-0.2.0-macos-arm64.zip`.
3. Unzip the file.
4. Drag `MacAutoHotkey.app` into `/Applications`.
5. Open `MacAutoHotkey.app` once. It runs as a menu-bar app and shows an `AHK` item in the macOS menu bar.

The menu-bar item lets you:

- open an `.ahk` script
- see which script is running
- stop the running script
- quit MacAutoHotkey

### Permissions

macOS must allow MacAutoHotkey to observe hotkeys and send keyboard/mouse events. Scripts that only use `MsgBox`, variables, and control flow can run without this permission, but hotkeys, hotstrings, `Send`, `MouseMove`, and `Click` need it. Enable it in:

`System Settings > Privacy & Security > Accessibility`

Grant permission to `/Applications/MacAutoHotkey.app`. Move the app to its final location before granting permission; if you move or replace the app later, macOS may require permission again. If macOS does not add it automatically, drag `MacAutoHotkey.app` from Finder into the Accessibility list.

Depending on your macOS version, keyboard monitoring may also require:

`System Settings > Privacy & Security > Input Monitoring`

After changing these permissions, quit and reopen MacAutoHotkey.

You can also check permission from Terminal:

```sh
/Applications/MacAutoHotkey.app/Contents/MacOS/macahk --check-accessibility
```

### Run Scripts

Use the menu-bar item and choose `Open Script...`, then select an `.ahk` file.

To make `.ahk` files open with MacAutoHotkey by default:

1. Select any `.ahk` file in Finder.
2. Choose `File > Get Info`.
3. In `Open with`, select `MacAutoHotkey.app`.
4. Click `Change All...`.

After that, double-clicking an `.ahk` file starts it with MacAutoHotkey, similar to AutoHotkey on Windows.

Try the included example:

1. Open `Examples/hello.ahk` with MacAutoHotkey.
2. Press `Control + J`.

A message box should appear with:

```text
Hello from macOS AHK
```

Stop the running script from the `AHK` menu-bar item with `Stop Running Script`.

You can still run scripts from Terminal:

```sh
/Applications/MacAutoHotkey.app/Contents/MacOS/macahk path/to/script.ahk
```

Example script:

```ahk
#Requires AutoHotkey v2.0

^j::MsgBox "Hello from macOS AHK"
```

### Gatekeeper

The current release app is ad-hoc signed but not notarized. macOS may block it after download. If that happens, right-click `MacAutoHotkey.app`, choose `Open`, and confirm.

If macOS still blocks it, remove the quarantine attribute:

```sh
xattr -dr com.apple.quarantine /Applications/MacAutoHotkey.app
```

## CLI Usage

The app bundle also contains the `macahk` CLI:

```sh
/Applications/MacAutoHotkey.app/Contents/MacOS/macahk --help
/Applications/MacAutoHotkey.app/Contents/MacOS/macahk --check-script Examples/hello.ahk
/Applications/MacAutoHotkey.app/Contents/MacOS/macahk Examples/hello.ahk
```

When running through the CLI, stop a persistent script with `Control + C` in Terminal.

For development builds, the CLI is also available at:

```sh
.build/release/macahk
```

## Build

Requirements:

- macOS 14 or newer
- Xcode command line tools
- Swift 6 or newer

Build the CLI:

```sh
swift build
```

Build the app bundle:

```sh
Scripts/build_app.sh
```

The app is created at:

```text
dist/MacAutoHotkey.app
```

Build a release ZIP:

```sh
Scripts/package_release.sh
```

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

`Examples/control-flow.ahk`:

```ahk
#Requires AutoHotkey v2.0

count := 2 + 3

^!l::
{
    Loop count
    {
        if A_Index <= 3
        {
            MsgBox "Loop item " . A_Index
        }
    }
}

^!c::
{
    if count >= 5 && count != 0
    {
        MsgBox "Expressions and conditions work"
    }
}
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
- Expressions support a small operator subset, but not the complete AutoHotkey v2 expression grammar.
- Function definitions, user-defined functions, objects, arrays, interpolation, `else`, `break`, and `continue` are not implemented yet.
- Hotkey parsing handles common keys but not the full AHK key grammar.
- `Send` is ASCII-oriented and falls back to pasteboard for unsupported characters.
- Hotstrings are simple suffix replacements and do not yet implement AHK options.
- Window, process, image search, clipboard, GUI, and file APIs are not implemented yet.
- macOS security prompts and permissions are required for useful automation.

## Roadmap

1. Replace the line parser with a lexer/parser that models more of AutoHotkey v2.
2. Add function calls, user functions, richer blocks, and broader control flow.
3. Expand key grammar and keyboard layout handling.
4. Add richer hotstring options and ending-character rules.
5. Implement window/application APIs on top of Accessibility.
6. Expand the menu-bar app with reload, logs, launch-at-login, and permission diagnostics.
7. Add conformance tests using representative AHK v2 scripts.
8. Investigate whether selected upstream AutoHotkey C++ parser/runtime pieces can be bridged cleanly without importing Win32 assumptions.

## License

MacAutoHotkey is licensed under the GNU General Public License v2.0. See `LICENSE`.
