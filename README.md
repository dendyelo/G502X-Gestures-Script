# Logitech G502 X Gestures Script

A high-performance Lua script for Logitech G Hub that adds advanced gesture functionality to the **Logitech G502 X**. This script is optimized for real-time responsiveness and instant execution.

## ✨ Features
- **Real-time Trigger**: Actions execute immediately when the movement threshold is reached.
- **Instant Quick Click**: A fast tap on the G9 button triggers Mission Control instantly (50ms ultra-low timeout).
- **Directional Swipes**: Supports Left, Right, Up, and Down gestures.
- **Optimized Performance**: Efficient polling loop with minimal CPU impact.

## 🎮 Default Mapping
| Gesture Mouse | Action | Shortcut Keyboard |
| :--- | :--- | :--- |
| **G9 (Quick Click)** | Mission Control | `Ctrl + Up` |
| **G9 + Swipe Left** | Move to Left Desktop | `Ctrl + Left` |
| **G9 + Swipe Right** | Move to Right Desktop | `Ctrl + Right` |
| **G9 + Swipe Up** | Mission Control | `Ctrl + Up` |
| **G9 + Swipe Down** | Application Windows | `Ctrl + Down` |

## 🚀 Installation
1. Open **Logitech G Hub**.
2. Go to General Settings, then disable Profile Switching
3. Navigate to Manage Profiles.
4. Select a profile and choose Scripting.
5. Create a new Lua script.
6. Paste the code from gestures.lua into the editor.
7. Click Save & Run to apply the script.

## ⚙️ Customization
Adjust these variables at the top of the script to fit your preference:
- `minimalHorizontalMovement`: Distance to trigger horizontal swipe (Default: `50`).
- `checkCount`: Timeout for Quick Click detection (Default: `20`).
- `delay`: Virtual keypress duration (Default: `10`).

## 📄 License
[MIT](LICENSE)
