# S3-OS: LUA-POWERED MICRO-OS FOR ESP32

### **Modular Operating System Framework for the Cheap Yellow Display (CYD)**

**S3-OS** is a lightweight multitasking operating system designed for the **ESP32-S3 and WROOM** architectures. It features a desktop environment, an integrated text editor, a multimedia player, and a Lua-based API that allows users to execute applications and games directly from an SD card without firmware modification.

---

## 🆕 NEW IN THIS VERSION

* **Visual Desktop & App Icons:** A new GUI that supports `icon.jpg` thumbnails and grid-based navigation.
* **Touch Gesture Engine:** Integrated vertical swipe detection for scrolling and tap-to-select logic.
* **2D Navigation:** Added support for horizontal movement (`kbdX`) in the desktop grid.
* **Advanced File Explorer:** New keyboard shortcuts for **Create (N)**, **MkDir (M)**, **Delete (D)**, and **Rename (R)**.
* **RGB System LED:** Visual feedback using the CYD's onboard RGB LEDs (Red/Green/Blue).
* **Multimedia Upgrades:** Hardware-accelerated MJPEG video playback support.

---

## 🔄 VERSION COMPARISON

| Feature | Legacy Version | Current Version (2.0) |
| :--- | :--- | :--- |
| **Navigation** | List-based only | **Icon Grid Desktop** |
| **Input** | Vertical only | **XY Axis (Grid) Support** |
| **Media** | JPEG Images | **JPEG + MJPEG Video** |
| **File Logic** | Read/Open Only | **Full CRUD (Create/Delete/Rename)** |
| **Gestures** | Single Tap | **Vertical Swiping & Long Press** |

---

## 🛠 CORE FEATURES

* **Dual-Core Task Distribution:** The UI and OS kernel operate on Core 1, while the NimBLE stack is pinned to Core 0 to ensure radio operations do not interfere with display refresh rates.
* **Integrated Code Editor:** Build and modify Lua scripts directly on the device with keyboard support and real-time scrolling.
* **Multimedia Suite:** Built-in support for rendering JPEG images and playback of MJPEG video files from the SD card.
* **Lua Virtual Machine:** Provides a sandbox for third-party scripts with direct hooks into hardware functions.

---

## 📂 SD CARD DIRECTORY STRUCTURE

The OS identifies applications by scanning for specific file flags. The SD card must follow this hierarchy:

```text
SD Card Root/
├── apps/
│   └── Snake_Game/
│       ├── Snake.game (Flag file containing the Display Name)
│       ├── main.lua   (Main Execution Logic)
│       └── icon.jpg   (Launcher Thumbnail)
├── games/
│   └── (Standalone .lua files for the legacy launcher)
└── [Other Files] (Support for .txt, .jpg, and .mjpeg)
