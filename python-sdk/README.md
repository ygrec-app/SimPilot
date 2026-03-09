# SimPilot Python SDK

Python SDK for [SimPilot](https://github.com/yourorg/SimPilot) — iOS Simulator automation.

## Install

```bash
pip install simpilot
```

Requires the `simpilot` CLI binary: `brew install yourorg/simpilot/simpilot`

## Usage

```python
from simpilot import SimPilot

pilot = SimPilot()
pilot.boot("iPhone 16 Pro")
pilot.launch("com.example.myapp")

pilot.tap(text="Sign In")
pilot.type_text("user@test.com", field="emailField")
pilot.type_text("password123", field="passwordField")
pilot.tap(accessibility_id="loginButton")

pilot.wait_for("Welcome", timeout=10)
pilot.assert_visible("Dashboard")
pilot.screenshot("authenticated")
```
