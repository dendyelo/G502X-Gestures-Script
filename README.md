# Logitech G502 X Gestures Script

A Lua script for **Logitech G HUB on macOS** that adds desktop and window gestures to the **Logitech G502 X**.

Hold G9 and flick the mouse. During the first **100 ms** after G9 is pressed, the script samples the cursor every **5 ms** and sends a shortcut as soon as movement exceeds the threshold. You can keep G9 held after the action; releasing it will not run a second action.

## ✨ Features

- **Real-time gestures:** actions fire as soon as movement exceeds a threshold during the initial detection window, preserving the original GitHub script's timing.
- **One action per hold:** after a gesture fires, further cursor movement and the eventual G9 release do not send another shortcut.
- **Mission Control click:** releasing G9 without a gesture detected in that window opens Mission Control.
- **Bounded polling:** sampling stops after a gesture fires or the 100 ms window ends.
- **Targeted key cleanup:** releases the arrow before Ctrl, then repeats key-up once after a short delay using only the same two keys.
- **Error recovery:** attempts key cleanup after errors, retains failed key-ups for retry, and waits for cleanup to succeed before sending another shortcut.
- **State reset:** cancels pending gestures when the profile changes and ignores duplicate presses or unmatched releases.
- **Optional logging:** records gesture events and shortcuts for troubleshooting; disabled by default.

## 🎮 Default Mapping

| Mouse gesture | Action | Keyboard shortcut |
| :--- | :--- | :--- |
| G9 without a detected gesture | Mission Control | `Ctrl + Up` |
| G9 + Swipe Left | Move to Left Desktop | `Ctrl + Left` |
| G9 + Swipe Right | Move to Right Desktop | `Ctrl + Right` |
| G9 + Swipe Up | Mission Control | `Ctrl + Up` |
| G9 + Swipe Down | Application Windows | `Ctrl + Down` |

Directional gestures fire during the initial detection window. The direction is calculated from the difference between the position at G9 press and each sampled position. Once a gesture fires, returning the cursor to its starting point does not undo it or send another shortcut.

If no gesture fires during the window, releasing G9 opens Mission Control, even if the cursor moved later. This preserves the original script's behavior; holding G9 beyond the window does not keep sampling. The click action has no hold-duration timeout.

## 🚀 Installation

1. Open **Logitech G HUB**.
2. Disable **Profile Switching**, or select a persistent profile, if you want these gestures available across applications.
3. Navigate to **Manage Profiles**.
4. Select your profile and choose **Scripting**.
5. Create a new Lua script.
6. Paste the complete contents of [gestures.lua](gestures.lua) into the editor.
7. Click **Save & Run**.

The script uses your macOS keyboard shortcuts for Mission Control, Application Windows, and moving between desktops. Make sure these shortcuts are enabled in macOS settings, and create multiple desktops to use the left/right gestures.

## ⚙️ Customization

Adjust these local variables at the top of the script:

| Variable | Default | Purpose |
| :--- | :--- | :--- |
| `gestureButtonNumber` | `9` | Mouse-button event argument used to start a gesture. |
| `minimalHorizontalMovement` | `50` | Horizontal displacement must exceed this threshold. |
| `minimalVerticalMovement` | `50` | Vertical displacement must exceed this threshold. |
| `gestureChecks` | `20` | Maximum number of cursor samples per press. |
| `sampleIntervalMs` | `5` | Delay before each cursor sample. |
| `modifierLeadMs` | `15` | Delay between pressing Ctrl and pressing the arrow. |
| `keyHoldMs` | `25` | Duration the arrow is held before releasing keys. |
| `keyReleaseGapMs` | `10` | Delay between the arrow key-up and Ctrl key-up. |
| `keyUpRetryMs` | `40` | Delay before repeating key-up for the same shortcut. |
| `debugLogging` | `false` | Set `true` to log gesture events and shortcut delivery. |

Movement thresholds use the values returned by `GetMousePosition()`. The vertical mapping preserves the tested setup: increasing Y triggers Swipe Up, and decreasing Y triggers Swipe Down. Button arguments and coordinate behavior should be checked on your own setup.

The default detection window is `gestureChecks × sampleIntervalMs`, or **100 ms** of sampling sleeps. Polling stops immediately when a gesture fires. Shortcut delivery adds about **100 ms** of sleeps in total; the shortcut key-down occurs before that cleanup finishes. The key-up retry sends no additional key-down or shortcut.

The documented `IsMouseButtonPressed()` API supports button values 1–5, so the script does not call it with G9 or wait indefinitely for a held-button check. Increasing the detection window also increases how long the press handler runs. [Logitech Lua API reference, page 21](https://douile.com/logitech-toggle-keys/APIDocs.pdf)

## 🛠️ Troubleshooting

Set `debugLogging = true`, click **Save & Run**, and reproduce the issue. Look for `SEND Ctrl+...` in the script console to identify the shortcut selected for each gesture.

`KEY-UP ... (API returned)` means the release call returned normally; it does not verify that macOS has processed the release. Errors are logged even when debug logging is disabled. Turn debug logging off once troubleshooting is complete.

## 🙏 Acknowledgments

Thanks to @devraan for sharing macOS feedback and key-release cleanup suggestions.

## 📄 License

[MIT](LICENSE)
