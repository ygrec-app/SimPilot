"""Unit tests for the SimPilot Python SDK.

All tests mock subprocess.run so no real simpilot binary is needed.
"""

from __future__ import annotations

import json
import subprocess
from typing import Any
from unittest.mock import MagicMock, patch

import pytest

from simpilot import ActionResult, SimPilot, SimPilotError


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def pilot() -> SimPilot:
    """Create a SimPilot instance with binary existence check bypassed."""
    with patch("simpilot.shutil.which", return_value="/usr/local/bin/simpilot"):
        return SimPilot()


def _ok(data: dict[str, Any] | list[Any] | None = None) -> MagicMock:
    """Build a successful subprocess.CompletedProcess mock."""
    mock = MagicMock(spec=subprocess.CompletedProcess)
    mock.returncode = 0
    mock.stdout = json.dumps(data) if data is not None else ""
    mock.stderr = ""
    return mock


def _ok_bytes(data: bytes = b"\x89PNG") -> MagicMock:
    mock = MagicMock(spec=subprocess.CompletedProcess)
    mock.returncode = 0
    mock.stdout = data
    mock.stderr = b""
    return mock


def _fail(stderr: str = "error", code: int = 1) -> MagicMock:
    mock = MagicMock(spec=subprocess.CompletedProcess)
    mock.returncode = code
    mock.stdout = ""
    mock.stderr = stderr
    return mock


# ---------------------------------------------------------------------------
# Constructor
# ---------------------------------------------------------------------------

class TestInit:
    def test_raises_when_binary_not_found(self) -> None:
        with patch("simpilot.shutil.which", return_value=None), \
             patch("simpilot.Path.is_file", return_value=False):
            with pytest.raises(FileNotFoundError, match="simpilot binary not found"):
                SimPilot(binary="nonexistent")

    def test_accepts_valid_binary(self) -> None:
        with patch("simpilot.shutil.which", return_value="/usr/local/bin/simpilot"):
            pilot = SimPilot()
            assert pilot.binary == "simpilot"
            assert pilot.device == "iPhone 16 Pro"
            assert pilot.timeout == 5.0


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

class TestLifecycle:
    @patch("subprocess.run")
    def test_boot(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok({"udid": "ABC", "state": "Booted"})
        result = pilot.boot("iPhone 16 Pro")
        assert result["state"] == "Booted"
        mock_run.assert_called_once()
        args = mock_run.call_args[0][0]
        assert args[:3] == ["simpilot", "devices", "boot"]
        assert "iPhone 16 Pro" in args

    @patch("subprocess.run")
    def test_boot_uses_default_device(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok({"udid": "ABC"})
        pilot.boot()
        args = mock_run.call_args[0][0]
        assert "iPhone 16 Pro" in args

    @patch("subprocess.run")
    def test_shutdown(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok({})
        pilot.shutdown("iPhone 16 Pro")
        args = mock_run.call_args[0][0]
        assert "shutdown" in args

    @patch("subprocess.run")
    def test_list_devices(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        devices = [{"name": "iPhone 16 Pro", "state": "Shutdown"}]
        mock_run.return_value = _ok({"devices": devices})
        result = pilot.list_devices()
        assert len(result) == 1
        assert result[0]["name"] == "iPhone 16 Pro"


# ---------------------------------------------------------------------------
# App lifecycle
# ---------------------------------------------------------------------------

class TestApp:
    @patch("subprocess.run")
    def test_launch(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok({"pid": 1234})
        result = pilot.launch("com.example.app")
        assert result["pid"] == 1234
        args = mock_run.call_args[0][0]
        assert "launch" in args
        assert "com.example.app" in args

    @patch("subprocess.run")
    def test_launch_with_app_path(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok({})
        pilot.launch("com.example.app", app_path="/build/App.app")
        args = mock_run.call_args[0][0]
        assert "--path" in args
        assert "/build/App.app" in args

    @patch("subprocess.run")
    def test_terminate(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok({})
        pilot.terminate("com.example.app")
        args = mock_run.call_args[0][0]
        assert "terminate" in args


# ---------------------------------------------------------------------------
# UI interactions
# ---------------------------------------------------------------------------

class TestInteractions:
    @patch("subprocess.run")
    def test_tap_by_text(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok({"success": True, "duration": 0.3, "strategy": "label"})
        result = pilot.tap(text="Sign In")
        assert isinstance(result, ActionResult)
        assert result.success is True
        assert result.strategy == "label"
        args = mock_run.call_args[0][0]
        assert "--text" in args
        assert "Sign In" in args

    @patch("subprocess.run")
    def test_tap_by_accessibility_id(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok({"success": True})
        pilot.tap(accessibility_id="loginButton")
        args = mock_run.call_args[0][0]
        assert "--id" in args
        assert "loginButton" in args

    @patch("subprocess.run")
    def test_tap_by_label(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok({"success": True})
        pilot.tap(label="Submit")
        args = mock_run.call_args[0][0]
        assert "--label" in args

    @patch("subprocess.run")
    def test_tap_with_custom_timeout(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok({"success": True})
        pilot.tap(text="OK", timeout=10.0)
        args = mock_run.call_args[0][0]
        assert "--timeout" in args
        idx = args.index("--timeout")
        assert args[idx + 1] == "10.0"

    @patch("subprocess.run")
    def test_type_text(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok({"success": True})
        result = pilot.type_text("hello@test.com", field="emailField")
        assert result.success is True
        args = mock_run.call_args[0][0]
        assert "--text" in args
        assert "hello@test.com" in args
        assert "--field" in args
        assert "emailField" in args

    @patch("subprocess.run")
    def test_type_text_no_clear(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok({"success": True})
        pilot.type_text("append", clear_first=False)
        args = mock_run.call_args[0][0]
        assert "--no-clear" in args

    @patch("subprocess.run")
    def test_swipe(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok({"success": True})
        result = pilot.swipe("up", distance=500)
        assert result.success is True
        args = mock_run.call_args[0][0]
        assert "up" in args
        assert "--distance" in args
        assert "500" in args


# ---------------------------------------------------------------------------
# Inspection
# ---------------------------------------------------------------------------

class TestInspection:
    @patch("subprocess.run")
    def test_screenshot_returns_bytes(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok_bytes(b"\x89PNGfakeimage")
        data = pilot.screenshot()
        assert isinstance(data, bytes)
        assert data.startswith(b"\x89PNG")

    @patch("subprocess.run")
    def test_screenshot_with_filename(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok_bytes(b"\x89PNG")
        pilot.screenshot("login_screen")
        args = mock_run.call_args[0][0]
        assert "login_screen" in args

    @patch("subprocess.run")
    def test_get_tree(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        tree = {"root": {"type": "other", "children": []}}
        mock_run.return_value = _ok(tree)
        result = pilot.get_tree()
        assert "root" in result

    @patch("subprocess.run")
    def test_get_tree_with_max_depth(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok({"root": {}})
        pilot.get_tree(max_depth=3)
        args = mock_run.call_args[0][0]
        assert "--max-depth" in args
        assert "3" in args


# ---------------------------------------------------------------------------
# Assertions
# ---------------------------------------------------------------------------

class TestAssertions:
    @patch("subprocess.run")
    def test_assert_visible(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok({"success": True, "strategy": "label"})
        result = pilot.assert_visible("Welcome")
        assert result.success is True
        args = mock_run.call_args[0][0]
        assert "assert" in args
        assert "visible" in args
        assert "Welcome" in args

    @patch("subprocess.run")
    def test_assert_not_visible(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok({"success": True})
        result = pilot.assert_not_visible("Loading...")
        assert result.success is True
        args = mock_run.call_args[0][0]
        assert "not-visible" in args

    @patch("subprocess.run")
    def test_wait_for(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok({"success": True})
        result = pilot.wait_for("Dashboard", timeout=15)
        assert result.success is True
        args = mock_run.call_args[0][0]
        assert "--timeout" in args
        idx = args.index("--timeout")
        assert args[idx + 1] == "15"


# ---------------------------------------------------------------------------
# System
# ---------------------------------------------------------------------------

class TestSystem:
    @patch("subprocess.run")
    def test_set_permission(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok({})
        pilot.set_permission("camera", True)
        args = mock_run.call_args[0][0]
        assert "permission" in args
        assert "camera" in args
        assert "yes" in args

    @patch("subprocess.run")
    def test_set_permission_revoke(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok({})
        pilot.set_permission("camera", False)
        args = mock_run.call_args[0][0]
        assert "no" in args

    @patch("subprocess.run")
    def test_set_location(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok({})
        pilot.set_location(48.8566, 2.3522)
        args = mock_run.call_args[0][0]
        assert "location" in args
        assert "48.8566" in args
        assert "2.3522" in args

    @patch("subprocess.run")
    def test_open_url(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok({})
        pilot.open_url("myapp://settings")
        args = mock_run.call_args[0][0]
        assert "url" in args
        assert "myapp://settings" in args

    @patch("subprocess.run")
    def test_send_push(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok({})
        pilot.send_push("Hello", "World", bundle_id="com.example.app")
        args = mock_run.call_args[0][0]
        assert "push" in args
        assert "Hello" in args
        assert "World" in args
        assert "--bundle-id" in args

    @patch("subprocess.run")
    def test_send_push_with_data(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _ok({})
        pilot.send_push("Hi", "Body", data={"type": "chat"})
        args = mock_run.call_args[0][0]
        assert "--data" in args
        data_idx = args.index("--data")
        parsed = json.loads(args[data_idx + 1])
        assert parsed["type"] == "chat"


# ---------------------------------------------------------------------------
# Error handling
# ---------------------------------------------------------------------------

class TestErrors:
    @patch("subprocess.run")
    def test_command_failure_raises(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock_run.return_value = _fail("device not found")
        with pytest.raises(SimPilotError, match="Command failed"):
            pilot.boot("Nonexistent")

    @patch("subprocess.run")
    def test_invalid_json_raises(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock = MagicMock(spec=subprocess.CompletedProcess)
        mock.returncode = 0
        mock.stdout = "not json {{"
        mock.stderr = ""
        mock_run.return_value = mock
        with pytest.raises(SimPilotError, match="Invalid JSON"):
            pilot.boot()

    @patch("subprocess.run")
    def test_screenshot_failure_raises(self, mock_run: MagicMock, pilot: SimPilot) -> None:
        mock = MagicMock(spec=subprocess.CompletedProcess)
        mock.returncode = 1
        mock.stdout = b""
        mock.stderr = b"screenshot error"
        mock_run.return_value = mock
        with pytest.raises(SimPilotError, match="Screenshot failed"):
            pilot.screenshot()

    def test_error_attributes(self) -> None:
        err = SimPilotError("test", command=["a", "b"], returncode=42, stderr="oops")
        assert err.command == ["a", "b"]
        assert err.returncode == 42
        assert err.stderr == "oops"
