import ApplicationServices
import Foundation

/// Check whether the current process has Accessibility (AX) permission.
///
/// If the process is **not** trusted, this function prints instructions,
/// opens the Privacy & Security > Accessibility pane in System Settings,
/// and calls `exit(1)`.
///
/// Call this early — for example before any command that needs to
/// read the Simulator's UI tree or inject HID events.
func checkAccessibilityPermission() {
    guard !AXIsProcessTrusted() else { return }

    fputs("""

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      Accessibility permission required
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    SimPilot needs Accessibility access to read the
    Simulator's UI tree and inject tap/type events.

    Steps:
      1. System Settings will open automatically.
      2. Find your terminal app (Terminal, iTerm2, etc.)
         or "simpilot" in the Accessibility list.
      3. Toggle the switch ON.
      4. Re-run your simpilot command.

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    """, stderr)

    // Open the Accessibility pane in System Settings (macOS 13+).
    // The URL scheme x-apple.systempreferences works on Ventura and later.
    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/open")
    process.arguments = [url.absoluteString]
    try? process.run()
    process.waitUntilExit()

    exit(1)
}
