# Troubleshooting

Common issues and solutions when using SimPilot.

## Installation Issues

### `simpilot` command not found

**Cause:** The binary is not on your `$PATH`.

```bash
# Check if installed
which simpilot

# If installed via Homebrew
brew list simpilot

# Add to PATH if needed
export PATH="/opt/homebrew/bin:$PATH"
```

### `applesimutils` not found

SimPilot uses `applesimutils` for permission management. Install it:

```bash
brew install applesimutils
```

If you installed it to a non-standard location, specify the path:

```swift
let driver = PermissionDriver(executablePath: "/usr/local/bin/applesimutils")
```

## Accessibility Permission

### "Accessibility permission not granted"

SimPilot uses macOS Accessibility APIs to read the simulator's UI element tree. You must grant permission to your terminal app.

1. Open **System Settings** > **Privacy & Security** > **Accessibility**
2. Click the **+** button
3. Add your terminal app:
   - **Terminal.app** — `/Applications/Utilities/Terminal.app`
   - **iTerm2** — `/Applications/iTerm.app`
   - **VS Code** — `/Applications/Visual Studio Code.app`
   - **Cursor** — `/Applications/Cursor.app`
4. Toggle it **ON**
5. Restart your terminal

**Verify:**
```bash
# SimPilot checks this on startup
simpilot devices list
```

### Permission granted but still failing

Try removing and re-adding the permission:

1. System Settings > Privacy & Security > Accessibility
2. Remove your terminal app
3. Re-add it
4. Restart the terminal completely (not just a new tab)

## Simulator Issues

### "Simulator not found"

```bash
# List available simulators
xcrun simctl list devices

# SimPilot uses the device name — match exactly
simpilot devices boot "iPhone 16 Pro"  # Correct
simpilot devices boot "iPhone16Pro"    # Wrong — no spaces
simpilot devices boot "iphone 16 pro" # Wrong — case sensitive
```

### Simulator won't boot

```bash
# Check current state
xcrun simctl list devices | grep "iPhone 16 Pro"

# If stuck in "Creating" state, delete and recreate
xcrun simctl delete "iPhone 16 Pro"
# The device will be recreated automatically, or:
xcrun simctl create "iPhone 16 Pro" "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro"
```

### No iOS runtime available

```bash
# List runtimes
xcrun simctl list runtimes

# If empty, install via Xcode
# Xcode > Settings > Platforms > + > iOS
# Or via CLI:
xcodebuild -downloadPlatform iOS
```

## Element Not Found

### Element exists but SimPilot can't find it

**Check the accessibility tree:**
```bash
simpilot tree --format json
```

Look for your element. Common issues:

1. **No accessibility identifier set** — The element has no `id` in the tree. Set `accessibilityIdentifier` in your app code.

2. **Element is off-screen** — Scroll to make it visible first:
   ```bash
   simpilot swipe up
   simpilot tap --text "My Element"
   ```

3. **Element is in a different window/alert** — Check if there's a system alert blocking:
   ```bash
   simpilot tree  # Look for alert elements at the top of the tree
   ```

4. **Timing issue** — The element hasn't appeared yet. Increase timeout:
   ```bash
   simpilot tap --text "Dashboard" --timeout 15
   ```

### OCR fallback not finding text

Vision OCR may not recognize text in certain conditions:

- Very small text (< 8pt)
- Low contrast text
- Text in images or custom-rendered views
- Non-Latin scripts (configure recognition languages)
- Text that's partially obscured

**Debug OCR:**
```bash
simpilot screenshot debug.png  # Take a screenshot
# Visually verify the text is actually visible
```

## Interaction Issues

### Tap hits the wrong element

**Cause:** Coordinate mapping between the accessibility tree and the simulator window.

1. Verify the element's frame:
   ```bash
   simpilot tree --format json | grep -A5 "loginButton"
   ```

2. Ensure the simulator window is not scaled. Use **Window > Physical Size** in Simulator.app.

3. If using multiple displays, ensure the simulator is on the primary display.

### Type not working

1. **No focused field:** Type requires a focused text field. Tap the field first:
   ```bash
   simpilot tap --id emailField
   simpilot type --text "hello@test.com"
   ```

2. **Hardware keyboard connected:** If the iOS simulator's software keyboard is hidden because "Connect Hardware Keyboard" is enabled, typing via accessibility still works but may behave differently.
   - In Simulator: **I/O > Keyboard > Connect Hardware Keyboard** (toggle off)

3. **Secure text field:** Password fields work the same way but won't show the typed text in the accessibility value.

### Swipe doesn't scroll

- Increase the swipe distance:
  ```bash
  simpilot swipe up --distance 500
  ```
- Ensure you're swiping on a scrollable view, not a static element.

## Performance

### Actions are slow

1. **Disable screenshots on every action** (default is off):
   ```swift
   let config = SessionConfig(screenshotOnEveryAction: false)
   ```

2. **Reduce OCR fallback** — If most elements have accessibility IDs, disable OCR:
   ```swift
   let config = ResolverConfig(enableOCRFallback: false)
   ```

3. **Use shorter timeouts** for elements you know appear quickly:
   ```bash
   simpilot tap --id knownButton --timeout 2
   ```

### Memory usage is high

Large trace directories with many screenshots can consume significant disk space:

```bash
# Check trace size
du -sh simpilot-traces/

# Clean old traces
rm -rf simpilot-traces/2026-03-0*
```

## MCP Integration

### Claude Code can't find SimPilot tools

1. Verify MCP config is correct:
   ```json
   {
     "mcpServers": {
       "simpilot": {
         "command": "simpilot",
         "args": ["mcp"]
       }
     }
   }
   ```

2. Verify the binary path:
   ```bash
   which simpilot
   # Use absolute path in config if needed:
   # "command": "/opt/homebrew/bin/simpilot"
   ```

3. Restart Claude Code after modifying MCP config.

### MCP server crashes

Check stderr output:
```bash
simpilot mcp 2>mcp-errors.log
```

Common causes:
- Simulator not booted
- Accessibility permission not granted
- Binary compiled for wrong architecture

## Python SDK

### `FileNotFoundError: simpilot binary not found`

The Python SDK requires the `simpilot` CLI binary to be installed:

```bash
brew install yourorg/simpilot/simpilot

# Or specify the path explicitly
from simpilot import SimPilot
pilot = SimPilot(binary="/path/to/simpilot")
```

### `SimPilotError: Invalid JSON`

The CLI returned unexpected output. This usually means:

1. The `simpilot` binary version is outdated — update it
2. An error occurred that wasn't properly formatted as JSON
3. The binary is a different tool with the same name

## Getting Help

If your issue isn't covered here:

1. Run with verbose output: `simpilot --verbose <command>`
2. Check the accessibility tree: `simpilot tree`
3. Take a screenshot: `simpilot screenshot debug.png`
4. File an issue with the tree output and screenshot attached
