# Phase 5 — Distribution & CI/CD

**Goal:** Make SimPilot installable in one command, tested in CI, and documented for open-source adoption.

**Depends on:** Phase 3 (functional CLI + MCP server).

**Team parallelism:** Homebrew, CI, and documentation can all be done simultaneously.

---

## 5.1 Package.swift (Final)

> **Assigned to:** Lead / Architect
> **File:** `Package.swift`

```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SimPilot",
    platforms: [
        .macOS(.v14)   // macOS 14+ for latest Vision and Accessibility APIs
    ],
    products: [
        // CLI + MCP binary
        .executable(name: "simpilot", targets: ["SimPilotCLI"]),

        // Core library (for Swift consumers and plugins)
        .library(name: "SimPilotCore", targets: ["SimPilotCore"]),
    ],
    dependencies: [
        // CLI
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),

        // MCP Server
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0"),

        // YAML parsing (for flow runner)
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        // Core library — all engine + drivers
        .target(
            name: "SimPilotCore",
            dependencies: [],
            path: "Sources/SimPilotCore",
            linkerSettings: [
                .linkedFramework("ApplicationServices"),   // AXUIElement
                .linkedFramework("Vision"),                 // OCR
                .linkedFramework("CoreImage"),              // Screenshot processing
                .linkedFramework("IOKit"),                  // HID events
            ]
        ),

        // CLI executable (includes MCP subcommand)
        .executableTarget(
            name: "SimPilotCLI",
            dependencies: [
                "SimPilotCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Yams", package: "Yams"),
            ],
            path: "Sources/SimPilotCLI"
        ),

        // Unit tests
        .testTarget(
            name: "SimPilotCoreTests",
            dependencies: ["SimPilotCore"],
            path: "Tests/SimPilotCoreTests"
        ),

        // Integration tests (require booted simulator)
        .testTarget(
            name: "SimPilotIntegrationTests",
            dependencies: ["SimPilotCore"],
            path: "Tests/IntegrationTests"
        ),
    ]
)
```

---

## 5.2 Homebrew Distribution

> **Assigned to:** Dev A
> **Files:** `Formula/simpilot.rb`, GitHub Release workflow

### Homebrew Tap

Create a separate repo: `github.com/yourorg/homebrew-simpilot`

```ruby
# Formula/simpilot.rb
class Simpilot < Formula
  desc "iOS Simulator automation framework — Playwright for iOS"
  homepage "https://github.com/yourorg/SimPilot"
  url "https://github.com/yourorg/SimPilot/releases/download/v1.0.0/simpilot-1.0.0.tar.gz"
  sha256 "..."
  license "MIT"

  depends_on :macos
  depends_on :xcode => ["15.0", :build]

  def install
    system "swift", "build",
           "-c", "release",
           "--disable-sandbox",
           "--arch", "arm64",
           "--arch", "x86_64"  # Universal binary
    bin.install ".build/release/simpilot"
  end

  test do
    assert_match "SimPilot", shell_output("#{bin}/simpilot version")
  end
end
```

### Installation

```bash
# Via tap
brew tap yourorg/simpilot
brew install simpilot

# Or direct
brew install yourorg/simpilot/simpilot
```

### Pre-built Binaries

For faster installation, publish pre-built universal binaries with each GitHub Release:

```bash
# Build universal binary
swift build -c release --arch arm64 --arch x86_64

# Archive
tar -czf simpilot-$(VERSION)-macos-universal.tar.gz \
    -C .build/release simpilot

# Attach to GitHub Release
gh release create v$(VERSION) \
    simpilot-$(VERSION)-macos-universal.tar.gz \
    --title "SimPilot v$(VERSION)" \
    --notes "Release notes..."
```

---

## 5.3 CI/CD Pipeline

> **Assigned to:** Dev B
> **File:** `.github/workflows/ci.yml`

### CI Workflow

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.app

      - name: Build
        run: swift build -c release

      - name: Unit Tests
        run: swift test --filter SimPilotCoreTests

      - name: Boot Simulator
        run: |
          UDID=$(xcrun simctl create "SimPilot-CI" "iPhone 16 Pro" "iOS18.0")
          xcrun simctl boot $UDID
          echo "SIMULATOR_UDID=$UDID" >> $GITHUB_ENV

      - name: Integration Tests
        run: swift test --filter SimPilotIntegrationTests
        env:
          SIMPILOT_TEST_UDID: ${{ env.SIMULATOR_UDID }}

      - name: Shutdown Simulator
        if: always()
        run: xcrun simctl shutdown all

  lint:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: SwiftLint
        run: |
          brew install swiftlint
          swiftlint lint --strict

  release:
    if: startsWith(github.ref, 'refs/tags/v')
    needs: [build, lint]
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.app

      - name: Build Universal Binary
        run: swift build -c release --arch arm64 --arch x86_64

      - name: Package
        run: |
          VERSION=${GITHUB_REF#refs/tags/v}
          tar -czf simpilot-${VERSION}-macos-universal.tar.gz \
              -C .build/release simpilot

      - name: Create Release
        uses: softprops/action-gh-release@v2
        with:
          files: simpilot-*.tar.gz
          generate_release_notes: true

      - name: Update Homebrew
        run: |
          # Update formula with new SHA and URL
          # Push to homebrew-simpilot tap repo
```

---

## 5.4 Documentation

> **Assigned to:** Dev C
> **Files:** `README.md`, `docs/`

### README.md Structure

```markdown
# SimPilot

iOS Simulator automation framework. Playwright for iOS.

## Quick Start

### Install
\`\`\`bash
brew install yourorg/simpilot/simpilot
\`\`\`

### Use with Claude Code (MCP)
Add to your MCP config:
\`\`\`json
{
  "mcpServers": {
    "simpilot": {
      "command": "simpilot",
      "args": ["mcp"]
    }
  }
}
\`\`\`

Then ask Claude: "Launch my app and test the login flow"

### Use from CLI
\`\`\`bash
simpilot devices boot "iPhone 16 Pro"
simpilot app launch com.example.myapp
simpilot tap --text "Sign In"
simpilot type --text "user@test.com" --field emailField
simpilot screenshot login.png
simpilot assert visible --text "Welcome"
\`\`\`

### Use from Python
\`\`\`bash
pip install simpilot
\`\`\`
\`\`\`python
from simpilot import SimPilot
pilot = SimPilot()
pilot.boot("iPhone 16 Pro")
pilot.launch("com.example.myapp")
pilot.tap(text="Sign In")
pilot.assert_visible(text="Welcome")
\`\`\`

### Use with YAML Flows
\`\`\`yaml
name: Login Test
device: iPhone 16 Pro
app:
  bundle_id: com.example.myapp
steps:
  - tap: { text: "Sign In" }
  - type: { field: emailField, text: "user@test.com" }
  - tap: { accessibility_id: loginButton }
  - assert_visible: { text: "Welcome" }
  - screenshot: logged_in
\`\`\`
\`\`\`bash
simpilot run login-flow.yaml
\`\`\`

## Works Great With

- **[XcodeBuildMCP](https://github.com/getsentry/XcodeBuildMCP)** — Build and run your app, then use SimPilot to drive the UI
- **Claude Code** — AI-driven E2E testing
- **Cursor / Windsurf** — Same MCP integration

## Documentation
- [Element Resolution Strategies](docs/element-resolution.md)
- [Writing Plugins](docs/plugins.md)
- [YAML Flow Reference](docs/yaml-flows.md)
- [Trace Reports](docs/reporting.md)
- [CI/CD Integration](docs/ci-cd.md)
- [Troubleshooting](docs/troubleshooting.md)

## Requirements
- macOS 14+
- Xcode 15+ (with iOS Simulator runtime)
- Accessibility permission granted to terminal
```

### docs/ Structure

```
docs/
├── element-resolution.md      # How SimPilot finds elements (ID → label → OCR)
├── plugins.md                 # Plugin authoring guide with examples
├── yaml-flows.md              # Complete YAML schema reference
├── reporting.md               # Trace format, HTML/JUnit reporters
├── ci-cd.md                   # GitHub Actions, Jenkins integration
├── troubleshooting.md         # Common issues (permissions, coordinate misalign)
├── api-reference.md           # Full API docs for SimPilotCore
└── mcp-tools-reference.md     # Complete MCP tool list with examples
```

---

## 5.5 Accessibility Permission Setup

> **Assigned to:** Dev A (part of installation)

SimPilot requires macOS Accessibility permission. Provide clear first-run experience:

```swift
// On first run, check and guide the user
func checkAccessibilityPermission() {
    if !AXIsProcessTrusted() {
        print("""
        ⚠️  SimPilot requires Accessibility permission.

        1. Open System Settings → Privacy & Security → Accessibility
        2. Add your terminal app (Terminal, iTerm2, VS Code, etc.)
        3. Toggle it ON
        4. Run simpilot again

        Opening System Settings now...
        """)

        // Open the right pane
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
        exit(1)
    }
}
```

---

## 5.6 Versioning & Release Process

### Semantic Versioning

- **1.0.0** — First stable release with MCP, CLI, core engine
- **1.x.0** — New features (new MCP tools, new assertions, new drivers)
- **1.x.y** — Bug fixes, performance improvements
- **2.0.0** — Breaking protocol/API changes

### Release Checklist

1. Update version in `Package.swift` and CLI `version` command
2. Update CHANGELOG.md
3. Tag: `git tag v1.0.0`
4. Push tag → CI builds universal binary → creates GitHub Release
5. Update Homebrew formula with new URL + SHA
6. Publish Python SDK to PyPI
7. Announce

---

## Phase 5 Deliverables Checklist

- [x] `Package.swift` finalized with all dependencies and targets
- [x] Homebrew formula + tap repo created (Formula/simpilot.rb)
- [ ] Pre-built universal binary (arm64 + x86_64) in GitHub Release
- [x] CI workflow: build, unit test, integration test (with real simulator)
- [x] CI workflow: lint (SwiftLint)
- [x] CI workflow: release automation (tag → build → release → homebrew update)
- [x] README.md with quick start for all interfaces
- [x] Documentation in `docs/` for all major topics
- [x] First-run accessibility permission check with user guidance
- [x] CHANGELOG.md
- [x] LICENSE (MIT)
- [ ] Python SDK published to PyPI
- [ ] `brew install simpilot` works end-to-end

---

## Phase 5 Exit Criteria

1. Fresh Mac with Xcode: `brew install simpilot` → `simpilot version` works
2. Add MCP config → Claude Code can drive a simulator
3. CI runs on every PR — build + test + lint
4. Tagged release auto-publishes binary + Homebrew + PyPI
5. README alone is sufficient for a new user to get started
