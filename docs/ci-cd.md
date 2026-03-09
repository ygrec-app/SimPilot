# CI/CD Integration

SimPilot is designed to run in CI environments. This guide covers GitHub Actions, Jenkins, and general CI setup.

## Requirements

- **macOS runner** (SimPilot requires macOS for the iOS Simulator)
- **Xcode 15+** with an iOS Simulator runtime installed
- **Accessibility permission** granted to the CI runner process
- `applesimutils` for permission management: `brew install applesimutils`

## GitHub Actions

### Basic Workflow

```yaml
name: E2E Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  e2e:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.app

      - name: Install SimPilot
        run: brew install yourorg/simpilot/simpilot

      - name: Install applesimutils
        run: brew install applesimutils

      - name: Build app
        run: |
          xcodebuild build \
            -scheme MyApp \
            -sdk iphonesimulator \
            -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
            -derivedDataPath build

      - name: Boot simulator
        run: simpilot devices boot "iPhone 16 Pro"

      - name: Run E2E tests
        run: simpilot run flows/*.yaml --output ./test-reports

      - name: Upload reports
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: simpilot-reports
          path: ./test-reports/

      - name: Publish JUnit results
        uses: dorny/test-reporter@v1
        if: always()
        with:
          name: SimPilot E2E
          path: ./test-reports/**/report.xml
          reporter: java-junit
```

### With Python SDK

```yaml
jobs:
  e2e-python:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install dependencies
        run: |
          brew install yourorg/simpilot/simpilot
          pip install simpilot pytest

      - name: Run Python E2E tests
        run: pytest tests/e2e/ -v --junitxml=test-reports/results.xml

      - name: Publish results
        uses: dorny/test-reporter@v1
        if: always()
        with:
          name: Python E2E
          path: test-reports/results.xml
          reporter: java-junit
```

## Jenkins

### Jenkinsfile

```groovy
pipeline {
    agent { label 'macos' }

    stages {
        stage('Setup') {
            steps {
                sh 'brew install yourorg/simpilot/simpilot || true'
                sh 'brew install applesimutils || true'
            }
        }

        stage('Build') {
            steps {
                sh '''
                    xcodebuild build \
                        -scheme MyApp \
                        -sdk iphonesimulator \
                        -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
                        -derivedDataPath build
                '''
            }
        }

        stage('E2E Tests') {
            steps {
                sh 'simpilot devices boot "iPhone 16 Pro"'
                sh 'simpilot run flows/*.yaml --output ./test-reports'
            }
        }
    }

    post {
        always {
            junit 'test-reports/**/report.xml'
            archiveArtifacts artifacts: 'test-reports/**/*.html', allowEmptyArchive: true
            sh 'xcrun simctl shutdown all || true'
        }
    }
}
```

## Simulator Management in CI

### Creating a Dedicated Simulator

```bash
# Create a fresh simulator for CI
UDID=$(xcrun simctl create "CI-Test" "iPhone 16 Pro" "iOS18.0")
xcrun simctl boot $UDID

# Use it
simpilot devices boot "CI-Test"

# Clean up
xcrun simctl shutdown $UDID
xcrun simctl delete $UDID
```

### Erasing Between Runs

```bash
# Reset simulator state between test suites
simpilot devices boot "iPhone 16 Pro"
# ... run tests ...
xcrun simctl erase "iPhone 16 Pro"
```

### Parallel Test Runs

Run multiple flows on different simulators simultaneously:

```yaml
strategy:
  matrix:
    flow: [auth, checkout, settings, onboarding]
    device: [iPhone 16 Pro, iPad Pro 13-inch (M4)]

steps:
  - run: simpilot run flows/${{ matrix.flow }}.yaml --device "${{ matrix.device }}"
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SIMPILOT_DEVICE` | Default simulator device name | `iPhone 16 Pro` |
| `SIMPILOT_TIMEOUT` | Default element query timeout (seconds) | `5` |
| `SIMPILOT_TRACE_DIR` | Trace output directory | `./simpilot-traces` |
| `SIMPILOT_TEST_UDID` | Specific simulator UDID for integration tests | — |

## Troubleshooting CI

### Common CI Issues

**Simulator fails to boot:**
```bash
# List available runtimes
xcrun simctl list runtimes

# List available device types
xcrun simctl list devicetypes

# Create with explicit runtime
xcrun simctl create "CI-Test" "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro" "com.apple.CoreSimulator.SimRuntime.iOS-18-0"
```

**Accessibility permission denied:**
On CI, the runner process needs Accessibility access. GitHub Actions macOS runners typically have this pre-configured. For self-hosted runners:
```bash
# Grant accessibility via tccutil (requires SIP disabled or MDM)
sudo tccutil reset Accessibility
```

**Tests timeout waiting for elements:**
CI machines are slower. Increase timeouts:
```yaml
# In YAML flows
- wait_for: { text: "Dashboard", timeout: 30 }

# Or via environment
SIMPILOT_TIMEOUT=15 simpilot run flows/*.yaml
```

**Screenshots are blank or wrong size:**
Ensure the simulator has fully booted before running tests:
```bash
xcrun simctl bootstatus "iPhone 16 Pro" -b  # Wait for boot to complete
```
