"""SimPilot — Python SDK for iOS Simulator automation.

Thin wrapper around the ``simpilot`` CLI binary.  Every method translates to a
CLI invocation with ``--json`` output, parsed and returned as a Python dict
(or raw bytes for screenshots).

Example::

    from simpilot import SimPilot

    pilot = SimPilot()
    pilot.boot("iPhone 16 Pro")
    pilot.launch("com.example.myapp")
    pilot.tap(text="Sign In")
    pilot.type_text("user@test.com", field="emailField")
    pilot.assert_visible("Welcome", timeout=10)
    pilot.screenshot("authenticated")
"""

from __future__ import annotations

import json
import shutil
import subprocess
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional, Sequence

__version__ = "0.1.0"
__all__ = ["SimPilot", "SimPilotError", "ActionResult"]


class SimPilotError(Exception):
    """Raised when a simpilot CLI command fails."""

    def __init__(
        self,
        message: str,
        *,
        command: Sequence[str] = (),
        returncode: int = 1,
        stderr: str = "",
    ) -> None:
        super().__init__(message)
        self.command = list(command)
        self.returncode = returncode
        self.stderr = stderr


@dataclass(frozen=True)
class ActionResult:
    """Structured result returned by interaction methods."""

    success: bool
    duration: float = 0.0
    strategy: str = ""
    details: str = ""
    raw: dict[str, Any] = field(default_factory=dict)


class SimPilot:
    """Python SDK for SimPilot iOS Simulator automation.

    Parameters
    ----------
    binary:
        Path (or name on ``$PATH``) of the ``simpilot`` executable.
    device:
        Default device name used when none is specified per-call.
    timeout:
        Default timeout in seconds for element queries.
    """

    def __init__(
        self,
        binary: str = "simpilot",
        *,
        device: str = "iPhone 16 Pro",
        timeout: float = 5.0,
    ) -> None:
        self.binary = binary
        self.device = device
        self.timeout = timeout

        resolved = shutil.which(binary)
        if resolved is None and not Path(binary).is_file():
            raise FileNotFoundError(
                f"simpilot binary not found: '{binary}'. "
                "Install via: brew install simpilot"
            )

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _run(self, *args: str, parse_json: bool = True) -> dict[str, Any]:
        """Execute a simpilot CLI command and return parsed JSON."""
        cmd = [self.binary, *args]
        if parse_json:
            cmd.append("--json")

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
        )

        if result.returncode != 0:
            raise SimPilotError(
                f"Command failed ({result.returncode}): {' '.join(cmd)}\n{result.stderr}",
                command=cmd,
                returncode=result.returncode,
                stderr=result.stderr,
            )

        if not parse_json or not result.stdout.strip():
            return {}

        try:
            return json.loads(result.stdout)
        except json.JSONDecodeError as exc:
            raise SimPilotError(
                f"Invalid JSON from simpilot: {exc}\nOutput: {result.stdout!r}",
                command=cmd,
            ) from exc

    def _result(self, data: dict[str, Any]) -> ActionResult:
        return ActionResult(
            success=data.get("success", True),
            duration=data.get("duration", 0.0),
            strategy=data.get("strategy", ""),
            details=data.get("details", ""),
            raw=data,
        )

    # ------------------------------------------------------------------
    # Simulator lifecycle
    # ------------------------------------------------------------------

    def boot(self, device_name: Optional[str] = None) -> dict[str, Any]:
        """Boot a simulator by name.

        Returns device info (udid, name, state).
        """
        name = device_name or self.device
        return self._run("devices", "boot", name)

    def shutdown(self, device_name: Optional[str] = None) -> dict[str, Any]:
        """Shutdown a booted simulator."""
        name = device_name or self.device
        return self._run("devices", "shutdown", name)

    def list_devices(self) -> list[dict[str, Any]]:
        """List all available simulators."""
        data = self._run("devices", "list")
        if isinstance(data, list):
            return data
        return data.get("devices", [])

    # ------------------------------------------------------------------
    # App lifecycle
    # ------------------------------------------------------------------

    def launch(
        self,
        bundle_id: str,
        *,
        app_path: Optional[str] = None,
    ) -> dict[str, Any]:
        """Install (optionally) and launch an app.

        Parameters
        ----------
        bundle_id:
            The application bundle identifier.
        app_path:
            Path to the ``.app`` bundle to install before launching.
        """
        args: list[str] = ["app", "launch", bundle_id]
        if app_path:
            args.extend(["--path", app_path])
        return self._run(*args)

    def terminate(self, bundle_id: str) -> dict[str, Any]:
        """Terminate a running app."""
        return self._run("app", "terminate", bundle_id)

    # ------------------------------------------------------------------
    # UI interactions
    # ------------------------------------------------------------------

    def tap(
        self,
        *,
        text: Optional[str] = None,
        accessibility_id: Optional[str] = None,
        label: Optional[str] = None,
        element_type: Optional[str] = None,
        timeout: Optional[float] = None,
    ) -> ActionResult:
        """Tap a UI element.

        At least one of *text*, *accessibility_id*, or *label* must be provided.
        The element is located using SimPilot's cascading resolution strategy
        (accessibility ID -> label -> OCR).
        """
        args: list[str] = ["tap"]
        if accessibility_id:
            args.extend(["--id", accessibility_id])
        if label:
            args.extend(["--label", label])
        if text:
            args.extend(["--text", text])
        if element_type:
            args.extend(["--type", element_type])
        args.extend(["--timeout", str(timeout or self.timeout)])
        return self._result(self._run(*args))

    def type_text(
        self,
        text: str,
        *,
        field: Optional[str] = None,
        clear_first: bool = True,
    ) -> ActionResult:
        """Type text into a field.

        Parameters
        ----------
        text:
            The string to type.
        field:
            Accessibility ID of the field to focus first.
            If omitted, types into the currently focused field.
        clear_first:
            Whether to clear existing text before typing.
        """
        args: list[str] = ["type", "--text", text]
        if field:
            args.extend(["--field", field])
        if not clear_first:
            args.append("--no-clear")
        return self._result(self._run(*args))

    def swipe(
        self,
        direction: str,
        *,
        distance: int = 300,
    ) -> ActionResult:
        """Swipe in a direction.

        Parameters
        ----------
        direction:
            One of ``"up"``, ``"down"``, ``"left"``, ``"right"``.
        distance:
            Swipe distance in points (default 300).
        """
        return self._result(
            self._run("swipe", direction, "--distance", str(distance))
        )

    # ------------------------------------------------------------------
    # Inspection
    # ------------------------------------------------------------------

    def screenshot(self, filename: Optional[str] = None) -> bytes:
        """Capture a screenshot.

        Returns raw PNG bytes.  If *filename* is given the CLI also saves the
        file to disk.
        """
        args = ["screenshot"]
        if filename:
            args.append(filename)

        result = subprocess.run(
            [self.binary, *args],
            capture_output=True,
        )
        if result.returncode != 0:
            stderr = result.stderr.decode(errors="replace")
            raise SimPilotError(
                f"Screenshot failed: {stderr}",
                command=[self.binary, *args],
                returncode=result.returncode,
                stderr=stderr,
            )
        return result.stdout

    def get_tree(self, *, max_depth: Optional[int] = None) -> dict[str, Any]:
        """Get the accessibility element tree as JSON."""
        args: list[str] = ["tree", "--format", "json"]
        if max_depth is not None:
            args.extend(["--max-depth", str(max_depth)])
        return self._run(*args)

    # ------------------------------------------------------------------
    # Assertions
    # ------------------------------------------------------------------

    def assert_visible(
        self,
        text: str,
        *,
        timeout: Optional[float] = None,
    ) -> ActionResult:
        """Assert that a UI element matching *text* is visible."""
        return self._result(
            self._run(
                "assert", "visible",
                "--text", text,
                "--timeout", str(timeout or self.timeout),
            )
        )

    def assert_not_visible(self, text: str) -> ActionResult:
        """Assert that a UI element matching *text* is **not** visible."""
        return self._result(
            self._run("assert", "not-visible", "--text", text)
        )

    # ------------------------------------------------------------------
    # Wait
    # ------------------------------------------------------------------

    def wait_for(
        self,
        text: str,
        *,
        timeout: Optional[float] = None,
    ) -> ActionResult:
        """Wait until an element matching *text* appears.

        Does **not** assert — just blocks until found or timeout.
        """
        return self._result(
            self._run(
                "wait",
                "--text", text,
                "--timeout", str(timeout or self.timeout),
            )
        )

    # ------------------------------------------------------------------
    # System
    # ------------------------------------------------------------------

    def set_permission(
        self,
        permission: str,
        granted: bool,
        *,
        bundle_id: Optional[str] = None,
    ) -> dict[str, Any]:
        """Grant or revoke an app permission.

        Parameters
        ----------
        permission:
            One of ``camera``, ``microphone``, ``photos``, ``location``,
            ``contacts``, ``calendar``, ``reminders``, ``notifications``, etc.
        granted:
            ``True`` to grant, ``False`` to revoke.
        bundle_id:
            Override the session's bundle ID if needed.
        """
        args: list[str] = ["permission", "set", permission, "yes" if granted else "no"]
        if bundle_id:
            args.extend(["--bundle-id", bundle_id])
        return self._run(*args)

    def set_location(self, latitude: float, longitude: float) -> dict[str, Any]:
        """Simulate a GPS location on the booted simulator."""
        return self._run("location", str(latitude), str(longitude))

    def open_url(self, url: str) -> dict[str, Any]:
        """Open a URL in the simulator (deep links, universal links)."""
        return self._run("url", url)

    def send_push(
        self,
        title: str,
        body: str,
        *,
        bundle_id: Optional[str] = None,
        data: Optional[dict[str, Any]] = None,
    ) -> dict[str, Any]:
        """Send a simulated push notification.

        Parameters
        ----------
        title:
            Notification title.
        body:
            Notification body text.
        bundle_id:
            Target app bundle ID.
        data:
            Optional custom payload data.
        """
        args: list[str] = ["push", title, body]
        if bundle_id:
            args.extend(["--bundle-id", bundle_id])
        if data:
            args.extend(["--data", json.dumps(data)])
        return self._run(*args)
