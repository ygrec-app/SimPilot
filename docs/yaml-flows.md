# YAML Flow Reference

YAML flows let you write declarative UI test scripts without any code. They are ideal for non-programmers, CI pipelines, and quick smoke tests.

## Quick Start

```yaml
# flows/login-test.yaml
name: Login Flow
device: iPhone 16 Pro
app:
  bundle_id: com.example.myapp
  path: build/MyApp.app  # optional

steps:
  - tap: { text: "Sign In" }
  - type: { field: emailField, text: "user@test.com" }
  - type: { field: passwordField, text: "secret123" }
  - tap: { accessibility_id: loginButton }
  - wait_for: { text: "Welcome", timeout: 10 }
  - assert_visible: { text: "Dashboard" }
  - screenshot: logged_in
```

Run it:

```bash
simpilot run flows/login-test.yaml
simpilot run flows/login-test.yaml --output ./reports
simpilot run flows/*.yaml  # Run all flows
```

## Full Schema

### Top-Level Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Human-readable flow name (used in reports) |
| `device` | No | Simulator device name (default: `iPhone 16 Pro`) |
| `app.bundle_id` | Yes | App bundle identifier |
| `app.path` | No | Path to `.app` bundle to install |
| `setup` | No | Pre-test setup steps (permissions, etc.) |
| `steps` | Yes | Ordered list of test steps |
| `teardown` | No | Cleanup steps (always run, even on failure) |

### Setup Steps

```yaml
setup:
  - permission: { name: camera, granted: true }
  - permission: { name: notifications, granted: true }
  - location: { latitude: 48.8566, longitude: 2.3522 }
  - url: "myapp://reset-state"
```

### Step Types

#### Interactions

```yaml
# Tap an element
- tap: { text: "Sign In" }
- tap: { accessibility_id: loginButton }
- tap: { label: "Submit", timeout: 10 }

# Type text
- type: { text: "hello@test.com" }
- type: { field: emailField, text: "hello@test.com" }
- type: { field: passwordField, text: "secret", clear_first: true }

# Swipe
- swipe: { direction: up }
- swipe: { direction: down, distance: 500 }

# Long press
- long_press: { text: "Item", duration: 1.5 }

# Press hardware button
- press_button: home
- press_button: lock
```

#### Assertions

```yaml
# Assert element is visible (waits up to timeout)
- assert_visible: { text: "Welcome" }
- assert_visible: { accessibility_id: dashboardView, timeout: 10 }

# Assert element is NOT visible
- assert_not_visible: { text: "Loading..." }
- assert_not_visible: { accessibility_id: errorBanner }
```

#### Wait

```yaml
# Wait for an element to appear (does not assert)
- wait_for: { text: "Dashboard", timeout: 15 }
```

#### Screenshots

```yaml
# Take a named screenshot
- screenshot: login_screen
- screenshot: final_state
```

#### System

```yaml
# Set permission
- permission: { name: camera, granted: true }
- permission: { name: location, granted: false }

# Set GPS location
- location: { latitude: 37.7749, longitude: -122.4194 }

# Open URL / deep link
- url: "myapp://settings/profile"

# Send push notification
- push: { title: "New Message", body: "You have mail", bundle_id: com.example.app }
```

### Teardown

Teardown steps always run, even if a step fails:

```yaml
teardown:
  - screenshot: final_state
  - terminate_app: com.example.myapp
```

## Variables

Use `${VAR_NAME}` to reference environment variables:

```yaml
steps:
  - type: { field: emailField, text: "${TEST_EMAIL}" }
  - type: { field: passwordField, text: "${TEST_PASSWORD}" }
```

```bash
TEST_EMAIL=user@test.com TEST_PASSWORD=secret simpilot run login.yaml
```

## Complete Example

```yaml
name: Full Authentication Flow
device: iPhone 16 Pro
app:
  bundle_id: com.example.myapp
  path: build/MyApp.app

setup:
  - permission: { name: camera, granted: true }
  - permission: { name: notifications, granted: true }

steps:
  # Verify launch screen
  - screenshot: 01_launch
  - assert_visible: { text: "Welcome to MyApp" }

  # Navigate to sign in
  - tap: { text: "Sign In with Email" }
  - screenshot: 02_sign_in_form

  # Fill form
  - type: { field: emailField, text: "${TEST_EMAIL}" }
  - type: { field: passwordField, text: "${TEST_PASSWORD}" }
  - screenshot: 03_filled_form

  # Submit
  - tap: { accessibility_id: loginButton }
  - wait_for: { text: "Welcome back", timeout: 10 }
  - screenshot: 04_authenticated

  # Verify authenticated state
  - assert_visible: { text: "Dashboard" }
  - assert_not_visible: { text: "Sign In" }

  # Navigate to settings
  - tap: { text: "Settings" }
  - swipe: { direction: up }
  - assert_visible: { text: "Account" }
  - screenshot: 05_settings

teardown:
  - screenshot: 99_final
  - terminate_app: com.example.myapp
```

## Output

Each flow run generates:
- A trace directory with screenshots and element tree snapshots
- An HTML report (viewable in any browser)
- A JUnit XML report (for CI integration)

```bash
simpilot run login.yaml --output ./reports
# Creates:
#   ./reports/2026-03-09T14-30-22/
#     ├── screenshots/
#     ├── trees/
#     ├── report.html
#     └── report.xml
```

## CI Usage

```yaml
# .github/workflows/e2e.yml
- name: Run E2E flows
  run: simpilot run flows/*.yaml --output ./test-reports

- name: Upload test results
  uses: actions/upload-artifact@v4
  with:
    name: simpilot-reports
    path: ./test-reports/

- name: Publish JUnit results
  uses: dorny/test-reporter@v1
  with:
    name: SimPilot E2E
    path: ./test-reports/**/report.xml
    reporter: java-junit
```
