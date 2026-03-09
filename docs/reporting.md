# Trace Recording & Reports

SimPilot records every action, assertion, and screenshot during a session and can generate HTML and JUnit XML reports for debugging and CI integration.

## Trace Recording

When tracing is enabled (default), SimPilot captures:

- Every action (tap, type, swipe) with timing
- Every assertion (pass/fail with details)
- Screenshots at key moments
- Element tree snapshots
- Errors and wait events

### Trace Directory Structure

```
simpilot-traces/
└── 2026-03-09T14-30-22/
    ├── screenshots/
    │   ├── 001_launch.png
    │   ├── 003_login_form.png
    │   ├── 005_authenticated.png
    │   └── 008_settings.png
    ├── trees/
    │   ├── 002_tree.json
    │   └── 006_tree.json
    ├── report.html
    └── report.xml
```

### Enabling/Disabling Tracing

```swift
// Swift
let config = SessionConfig(
    traceEnabled: true,               // default: true
    traceOutputDir: "./my-traces",    // default: ./simpilot-traces
    screenshotOnEveryAction: false    // default: false
)
```

```bash
# CLI
simpilot run flow.yaml --output ./my-traces
simpilot run flow.yaml --no-trace  # disable
```

## Trace Events

Each event records:

| Field | Description |
|-------|-------------|
| `step` | Auto-incrementing step number |
| `timestamp` | When the event occurred |
| `type` | Event type (see below) |
| `details` | Human-readable description |
| `duration` | How long the action took |
| `screenshotPath` | Path to associated screenshot (if any) |
| `treePath` | Path to element tree snapshot (if any) |

### Event Types

| Type | Description |
|------|-------------|
| `sessionStart` | Session began |
| `sessionEnd` | Session ended |
| `tap` | Tap interaction |
| `doubleTap` | Double-tap interaction |
| `longPress` | Long press interaction |
| `type` | Text input |
| `swipe` | Swipe gesture |
| `screenshot` | Screenshot captured |
| `assertion` | Assertion evaluated (pass or fail) |
| `waitStarted` | Wait polling began |
| `waitCompleted` | Wait succeeded (element found) |
| `waitTimeout` | Wait timed out |
| `pluginAction` | Custom plugin action executed |
| `error` | An error occurred |

## HTML Report

The HTML reporter generates a self-contained, single-file report that can be opened in any browser. No external dependencies — all CSS is embedded inline.

### Features

- Session summary (device, app, duration, pass/fail counts)
- Step-by-step timeline with timestamps
- Embedded screenshots (base64-encoded, no external files needed)
- Color-coded assertions (green for pass, red for fail)
- Action type badges
- Dark theme, responsive layout

### Generating HTML Reports

```swift
// Swift
let html = HTMLReporter.generate(
    events: traceRecorder.finalize(),
    sessionInfo: SessionInfo(
        sessionID: "test-001",
        deviceName: "iPhone 16 Pro",
        bundleID: "com.example.app",
        startTime: startTime,
        endTime: Date()
    )
)
try html.write(toFile: "report.html", atomically: true, encoding: .utf8)
```

```bash
# CLI — reports are generated automatically
simpilot run flow.yaml --output ./reports
open ./reports/*/report.html
```

## JUnit XML Report

The JUnit reporter generates standard XML compatible with CI systems like GitHub Actions, Jenkins, CircleCI, and GitLab CI.

### Format

```xml
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="auth-flow" tests="8" failures="0" time="12.400">
    <testcase name="PASS: element visible - Welcome" time="0.500" />
    <testcase name="PASS: text matches" time="0.200" />
    <testcase name="FAIL: element not found - Settings">
      <failure message="FAIL: element not found - Settings">
        FAIL: element not found - Settings
      </failure>
    </testcase>
  </testsuite>
</testsuites>
```

### What Becomes a Test Case

Only **assertion** events become `<testcase>` entries. Actions (tap, type, swipe) are not included in JUnit output — they are context, not verifiable outcomes.

### CI Integration

#### GitHub Actions

```yaml
- name: Run SimPilot tests
  run: simpilot run flows/*.yaml --output ./test-reports

- name: Publish test results
  uses: dorny/test-reporter@v1
  if: always()
  with:
    name: SimPilot E2E Tests
    path: ./test-reports/**/report.xml
    reporter: java-junit
```

#### Jenkins

```groovy
post {
    always {
        junit 'test-reports/**/report.xml'
    }
}
```

## Screenshot Diff

SimPilot can compare screenshots pixel-by-pixel for visual regression testing.

### Comparing Screenshots

```swift
let result = ScreenshotDiff.compare(
    baselineImage,
    currentImage,
    tolerance: 0.01  // Allow 1% pixel difference
)

if !result.identical {
    print("Changed: \(result.diffPercentage * 100)% of pixels")
    print("Changed pixels: \(result.changedPixelCount)/\(result.totalPixelCount)")
}
```

### Visual Diff

Generate a highlighted diff image showing changed pixels in red:

```swift
if let diffImage = ScreenshotDiff.visualDiff(baseline, current) {
    try diffImage.write(to: URL(filePath: "diff.png"))
}
```

### Baseline Management

Use `ScreenshotManager` to save and compare baselines:

```swift
let manager = ScreenshotManager(
    introspectionDriver: driver,
    baselineDir: "./baselines"
)

// Save a baseline
try await manager.saveBaseline(name: "login_screen")

// Compare against baseline
let diff = try await manager.compareWithBaseline(
    name: "login_screen",
    tolerance: 0.02  // 2% tolerance
)
```

### DiffResult

| Field | Type | Description |
|-------|------|-------------|
| `identical` | `Bool` | Whether images match within tolerance |
| `diffPercentage` | `Float` | 0.0 (identical) to 1.0 (completely different) |
| `changedPixelCount` | `Int` | Number of pixels that differ |
| `totalPixelCount` | `Int` | Total pixels in the image |
| `diffImage` | `Data?` | Visual diff PNG (if generated) |
