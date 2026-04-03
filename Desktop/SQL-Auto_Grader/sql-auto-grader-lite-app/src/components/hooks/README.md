# `src/hooks` — README

## Overview

This folder contains custom React hooks and a usage example for the anti-cheat system used during exams.

---

## Files

### `useAntiCheat.js`

A custom React hook that monitors and prevents cheating behaviors during an exam session. It tracks violations and fires a callback whenever one is detected.

**What it blocks/detects:**

| Behavior | Action |
|---|---|
| Text selection | Disabled globally on `document.body` |
| Copy (`Ctrl+C`) | Blocked via `copy` event |
| Paste (`Ctrl+V`) | Blocked via `paste` event |
| Right-click | Blocked + violation logged |
| Tab/window switch | Detected via `visibilitychange` |
| App switch / window blur | Detected via `blur` on `window` |

> Note: Mouse leaving the screen / pointer going outside the window is partially covered by the `blur` event (when the user clicks outside the browser window).

---

### `ExamComponent.js`

A reference/demo component showing how to wire up `useAntiCheat` inside an exam page.

---

## How to Use `useAntiCheat` in Any Page

```jsx
import { useAntiCheat } from '../hooks/useAntiCheat';

function MyExamPage() {
  const { violations } = useAntiCheat((violation) => {
    console.warn('Violation:', violation);
    // violation = { type: 'tab_switch' | 'window_blur' | 'right_click', timestamp: '...' }
  });

  return (
    <div>
      {violations.length > 0 && <p>Violations: {violations.length}</p>}
      {/* exam content */}
    </div>
  );
}
```

The `onViolation` callback is optional — if you just want to track violations silently:

```jsx
const { violations } = useAntiCheat();
```

---

## Selectively Enabling/Disabling Behaviors

The hook currently enables everything at once. To control individual behaviors, extend it to accept an options object:

```jsx
export const useAntiCheat = (onViolation, options = {}) => {
  const {
    blockCopy = true,
    blockPaste = true,
    blockRightClick = true,
    detectTabSwitch = true,
    detectWindowBlur = true,
    disableTextSelection = true,
  } = options;
```

Then wrap each listener registration with its flag:

```jsx
if (blockCopy)        document.addEventListener('copy', handleCopy);
if (blockPaste)       document.addEventListener('paste', handlePaste);
if (detectTabSwitch)  document.addEventListener('visibilitychange', handleVisibilityChange);
if (detectWindowBlur) window.addEventListener('blur', handleBlur);
if (blockRightClick)  document.addEventListener('contextmenu', handleContextMenu);
```

Usage with selective options:

```jsx
// Block everything (default)
useAntiCheat(onViolation);

// Only detect tab switching, allow copy/paste
useAntiCheat(onViolation, { blockCopy: false, blockPaste: false });

// Disable all
useAntiCheat(onViolation, {
  blockCopy: false, blockPaste: false, blockRightClick: false,
  detectTabSwitch: false, detectWindowBlur: false, disableTextSelection: false,
});
```

---

## Detecting Mouse Leaving the Screen

The current `blur` event fires when the user clicks outside the browser window. To also detect the pointer leaving the viewport without clicking away, add a `mouseleave` listener:

```jsx
const handleMouseLeave = () => logViolation('mouse_left_window');
document.addEventListener('mouseleave', handleMouseLeave);
// cleanup:
document.removeEventListener('mouseleave', handleMouseLeave);
```

---

## Violation Object Shape

Every violation passed to `onViolation` looks like:

```js
{
  type: 'tab_switch' | 'window_blur' | 'right_click' | 'copy_attempt' | 'paste_attempt',
  timestamp: '2026-03-14T23:27:40.583Z'
}
```

You can use this to log to a server, show a warning modal, or auto-submit the exam after N violations.
