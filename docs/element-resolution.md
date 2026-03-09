# Element Resolution Strategies

SimPilot uses a cascading resolution strategy to find UI elements. This means you can target elements by the most convenient identifier, and SimPilot will try multiple strategies until one succeeds.

## Resolution Order

When you query for an element, SimPilot tries the following strategies in order:

| Priority | Strategy | Source | Speed | Reliability |
|----------|----------|--------|-------|-------------|
| 1 | Accessibility ID | `accessibilityIdentifier` | Fastest | Most reliable |
| 2 | Accessibility Label | `accessibilityLabel` | Fast | Reliable |
| 3 | Type + Text match | Element tree walk | Fast | Good |
| 4 | Type only | Element tree walk | Fast | Ambiguous |
| 5 | Vision OCR | Screenshot text recognition | Slow (~200ms) | Fallback |

## Strategy Details

### 1. Accessibility ID (Recommended)

Matches the `accessibilityIdentifier` property set in code. This is the most reliable strategy because IDs are stable, unique, and do not change with localization.

```bash
simpilot tap --id "loginButton"
```

```python
pilot.tap(accessibility_id="loginButton")
```

**When to use:** Always, if your app sets accessibility identifiers. This is the gold standard.

### 2. Accessibility Label

Matches the `accessibilityLabel` property. Labels are what VoiceOver reads aloud. They may change with localization but are generally stable within a language.

```bash
simpilot tap --label "Sign In"
```

```python
pilot.tap(label="Sign In")
```

**When to use:** When the element has a descriptive label but no explicit ID.

### 3. Type + Text Match

Walks the accessibility tree looking for elements of a specific type that contain the given text. More specific than text-only search.

```bash
simpilot tap --text "Sign In" --type button
```

```python
pilot.tap(text="Sign In", element_type="button")
```

### 4. Type Only

Matches elements by type alone. Useful when combined with an index to get the Nth element of a type.

### 5. Vision OCR Fallback

When no accessibility match is found, SimPilot captures a screenshot and uses Apple's Vision framework (`VNRecognizeTextRequest`) to find text on screen. This can locate elements that have no accessibility metadata at all.

```bash
simpilot tap --text "Accept Cookies"
```

**Tradeoffs:**
- Adds ~200ms latency for OCR processing
- Slightly less precise pixel targeting (center of recognized text bounding box)
- Works with any text visible on screen, regardless of accessibility support
- Can be disabled via `ResolverConfig(enableOCRFallback: false)`

## Query Parameters

| Parameter | CLI Flag | Python Kwarg | Description |
|-----------|----------|--------------|-------------|
| Accessibility ID | `--id` | `accessibility_id` | Exact match on `accessibilityIdentifier` |
| Label | `--label` | `label` | Exact match on `accessibilityLabel` |
| Text | `--text` | `text` | Fuzzy match — tries label, then value, then OCR |
| Element Type | `--type` | `element_type` | Filter by type: `button`, `textField`, `cell`, etc. |
| Index | `--index` | `index` | Select Nth match (0-based) when multiple elements match |
| Timeout | `--timeout` | `timeout` | Max seconds to wait for element to appear (default: 5s) |

## Auto-Wait Behavior

All element queries include automatic waiting (polling). SimPilot will:

1. Query the accessibility tree immediately
2. If not found, wait `pollInterval` milliseconds (default: 250ms)
3. Re-query
4. Repeat until found or `timeout` is reached

This means you rarely need explicit `wait_for` calls — `tap`, `assert_visible`, etc. already wait.

### Configuring Wait Behavior

```swift
// Swift
let config = ResolverConfig(
    defaultTimeout: 10.0,      // Wait up to 10 seconds
    pollInterval: 100,          // Poll every 100ms
    enableOCRFallback: true     // Use Vision OCR as last resort
)
```

Presets:
- `ResolverConfig.default` — 5s timeout, 250ms poll
- `ResolverConfig.fast` — 2s timeout, 100ms poll
- `ResolverConfig.patient` — 15s timeout, 500ms poll

## Tips

- **Set accessibility identifiers** on key elements in your app. This makes tests faster, more reliable, and locale-independent.
- **Use `--text` for quick exploration**, then switch to `--id` for stable tests.
- **Combine type and text** to disambiguate: `--text "Submit" --type button` avoids matching a label that also says "Submit".
- **Use `get_tree`** to inspect the current accessibility tree and discover element IDs and labels.
