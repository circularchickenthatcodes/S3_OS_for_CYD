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

    SD Card Root/
    ├── apps/
    │   └── Snake_Game/
    │       ├── Snake.game (Flag file containing the Display Name)
    │       ├── main.lua   (Main Execution Logic)
    │       └── icon.jpg   (Launcher Thumbnail)
    ├── games/
    │   └── (Standalone .lua files for the legacy launcher)
    └── [Other Files] (Support for .txt, .jpg, and .mjpeg)

> **The .game File:** Its presence tells the OS that the parent folder is a valid application. The text content inside the file is read by the OS and displayed as the App Name on the desktop UI.

---

## 📜 LUA API REFERENCE

The following functions are exported from the C++ kernel to the Lua environment:

### **Graphics and Display**
* `cls(color)`: Fills the active display buffer with a specific 16-bit color.
* `setTextSize(size)`: Sets the global font scaling for text rendering.
* `printAt(x, y, text, color)`: Renders a string at the specified pixel coordinates.
* `rect(x, y, w, h, color)`: Draws a rectangle outline.
* `fillRect(x, y, w, h, color)`: Draws a solid, filled rectangle.
* `circle(x, y, r, color, fill)`: Draws or fills a circle based on the boolean fill parameter.
* `drawImg(path, x, y, scale)`: Renders a JPEG image from the application directory.

### **System and Hardware**
* `getTouch()`: Returns the current status and X/Y coordinates of a touch event.
* `getPressedKey()`: Returns the ASCII string or the raw HID code of the current key press.
* `isKeyDown(key)`: Returns **true** if a specific key (string or HID code) is held down.
* `playSound(freq, ms)`: Generates a tone on the onboard buzzer (**GPIO 26**).
* `delay(ms)`: Pauses script execution safely.

---

## ⌨️ CONTROLS & SHORTCUTS

| Action | Key / Gesture |
| :--- | :--- |
| **Navigate** | Arrow Keys / Swipe Up-Down |
| **Execute/Open** | Enter / Tap Item |
| **New File** | `N` (0x11) |
| **MkDir** | `M` (0x10) |
| **Delete** | `D` (0x07) |
| **Rename** | `R` (0x15) |
| **Editor Mode** | `Shift + Enter` |
| **Exit/Back** | `Backspace` (0x2A) |

---

## ⚙️ TECHNICAL SPECIFICATIONS

* **Display (ILI9341):** DC: 2, CS: 15, CLK: 14, MOSI: 13
* **Touch (XPT2046):** CS: 33, CLK: 25, MOSI: 32, MISO: 39
* **RGB LED:** Red: 4, Green: 16, Blue: 17 (**Active Low**)
* **Buzzer:** Pin 26
* **Backlight:** Pin 21
* **Partition Scheme:** Huge APP (3MB No OTA)

---

## 📝 IMPLEMENTATION NOTES

* **Power Management:** Holding the **Boot button (GPIO 0)** triggers a software-controlled shutdown. The system enters Deep Sleep and disables the backlight to save power.
* **Bus Sharing:** The SPI bus is shared between the display, SD card, and touch. The kernel manages Chip Select (CS) logic to prevent data collision.
* **RGB Indicators:**
    * **Green:** System ready / Booted.
    * **Red:** Shutdown process / Deep Sleep.
