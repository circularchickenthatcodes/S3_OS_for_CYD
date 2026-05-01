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

## 📜 LUA API REFERENCE

The following functions are exported from the C++ kernel to the Lua environment. You can call these directly within your `.lua` scripts.

### **Graphics & Display**
* `cls(color)`: Clears the screen with a specific 16-bit (RGB565) color.
* `setTextSize(size)`: Sets the font scale (e.g., 1, 2, or 3).
* `printAt(x, y, text, color)`: Draws text at specific coordinates with an optional color.
* `rect(x, y, w, h, color)`: Draws the outline of a rectangle.
* `fillRect(x, y, w, h, color)`: Draws a solid, filled rectangle.
* `circle(x, y, r, color, fill)`: Draws a circle. Set `fill` to `true` for a solid circle, `false` for an outline.
* `drawImg(path, x, y, scale)`: Renders a JPEG image from the SD card.
* `drawTrapezoid(x1, y1, w1, x2, y2, w2, color)`: Draws a filled trapezoid between two points with different widths. Useful for 3D floors/ceilings.

### **3D & Advanced Rendering**
* `loadTexture(path)`: Loads a 64x64 raw texture file into a dedicated RAM buffer for high-speed access.
* `drawTextureStrip(x, yStart, h, texX, shaded)`: Draws a vertical 2-pixel wide slice of the loaded texture. `shaded` applies a 50% brightness reduction.

### **Internal Canvas (HUD)**
* `initHUD()`: Creates a 200x100 off-screen drawing buffer in internal RAM to prevent flickering.
* `fillHUD(x, y, w, h, color)`: Draws a rectangle specifically onto the HUD buffer.
* `pushHUD(screenX, screenY)`: Flushes the HUD buffer onto the main display at the target coordinates.

### **System & Hardware**
* `getTouch()`: Returns `touched (bool), x, y`.
* `getPressedKey()`: Returns the ASCII character or the raw HID integer code of the last key pressed.
* `isKeyDown(key)`: Checks if a key is currently held down. Supports strings like `"w"`, `"a"`, `"s"`, `"d"`, `"space"`, `"esc"` or raw HID codes.
* `playSound(freq, ms)`: Beeps the onboard buzzer at a specific frequency for a set duration.
* `delay(ms)`: Pauses script execution for the specified milliseconds.

### **Flash Storage (LittleFS)**
* `flashWrite(key, data)`: Saves a string to the ESP32's internal flash memory as `key.txt`.
* `flashRead(key)`: Retrieves the string content from internal flash. Returns `nil` if not found.
* `flashExists(key)`: Returns `true` if the specified file exists in internal flash.

---

## ⌨️ CONTROLS & SHORTCUTS

| Action | Key / Gesture |
| :--- | :--- |
| **Navigate** | Arrow Keys / Swipe Up-Down |
| **Execute/Open** | Enter / Tap Item |
| **New File** | `N` |
| **MkDir** | `M` |
| **Delete** | `D` |
| **Rename** | `R` |
| **Save (Editor)** | `TAB` |
| **Exit/Back** | `Backspace` (0x2A) |

---

## ⚙️ TECHNICAL SPECIFICATIONS

* **Display (ILI9341):** DC: 2, CS: 15, CLK: 14, MOSI: 13
* **Touch (XPT2046):** CS: 33, CLK: 25, MOSI: 32, MISO: 39
* **RGB LED:** Red: 4, Green: 16, Blue: 17 (**Active Low**)
* **Buzzer:** Pin 26
* **Backlight:** Pin 21
* **Partition Scheme:** Huge APP (3MB No OTA)
