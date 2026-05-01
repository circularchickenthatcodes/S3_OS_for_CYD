S3-OS: LUA-POWERED MICRO-OS FOR ESP32
A modular operating system framework for the Cheap Yellow Display (CYD)
S3-OS is a lightweight multitasking operating system designed for the ESP32-S3 and WROOM architectures. It features a desktop environment, an integrated text editor, a multimedia player, and a Lua-based API that allows users to execute applications and games directly from an SD card without firmware modification.

NEW IN THIS VERSION
Visual Desktop & App Icons: A new GUI that supports icon.jpg thumbnails, grid-based navigation, and an "S3 Games" shortcut.

Touch Gesture Engine: Added vertical swipe detection to scroll through file lists and desktop menus seamlessly.

Horizontal Navigation: Full support for kbdX inputs, allowing for grid-based app selection on the desktop.

Refined File Management: Integrated shortcuts for creating files (N), folders (M), deleting (D), and renaming (R).

RGB Status Feedback: Utilization of the CYD's onboard RGB LEDs to indicate system states (Boot, Shutdown, Activity).

MJPEG Video Playback: High-performance video streaming from SD card with hardware-accelerated decoding.

CORE FEATURES

Dual-Core Task Distribution: The UI and OS kernel operate on Core 1, while the NimBLE stack is pinned to Core 0 to ensure radio operations do not interfere with display refresh rates.

Desktop and App Launcher: A visual icon-based desktop that scans the apps folder for bundles and a legacy S3 Games launcher for standalone scripts.

Integrated Code Editor: Build and modify Lua scripts directly on the device with keyboard support, real-time scrolling, and cursor blinking.

Multimedia Suite: Built-in support for rendering JPEG images and playback of MJPEG video files from the SD card.

Lua Virtual Machine: Provides a sandbox for third-party scripts with direct hooks into hardware functions via the custom os library.

SD CARD DIRECTORY STRUCTURE

The OS identifies applications by scanning for specific file flags. The SD card must follow this hierarchy:

SD Card Root/

├── apps/

│ └── Snake_Game/

│ ├── Snake.game (Flag file containing the Display Name)

│ ├── main.lua (Main Execution Logic)

│ └── icon.jpg (Launcher Thumbnail)

├── games/

│ └── (Standalone .lua files for the legacy launcher)

└── [Other Files] (Support for .txt, .jpg, and .mjpeg)

The .game File The .game file serves two purposes:

App Discovery: Its presence tells the OS that the parent folder is a valid application.

Metadata: The text content inside the file is read by the OS and displayed as the App Name on the desktop UI.

LUA API REFERENCE

The following functions are exported from the C++ kernel to the Lua environment:

Graphics and Display

cls(color): Fills the active display buffer with a specific 16-bit color.

setTextSize(size): Sets the global font scaling for text rendering.

printAt(x, y, text, color): Renders a string at the specified pixel coordinates.

rect(x, y, w, h, color): Draws a rectangle outline.

fillRect(x, y, w, h, color): Draws a solid, filled rectangle.

circle(x, y, r, color, fill): Draws or fills a circle based on the boolean fill parameter.

drawImg(path, x, y, scale): Renders a JPEG image from the application directory.

System and Hardware

getTouch(): Returns the current status and X/Y coordinates of a touch event.

getPressedKey(): Returns the ASCII string or the raw HID code of the current key press.

isKeyDown(key): Returns true if a specific key (string "w" or HID code) is held down.

playSound(freq, ms): Generates a tone on the onboard buzzer (GPIO 26).

delay(ms): Pauses script execution safely while maintaining system stability.

CONTROLS & GESTURES

Touchscreen Gestures

Swipe Up/Down: Scroll through file lists or the App grid.

Short Tap (<300ms): Select an item.

Double Tap (or Enter): Open/Execute the selected item.

Keyboard Shortcuts (HID Raw Codes)

N (0x11): Create New .lua File.

M (0x10): Create New Folder (MkDir).

D (0x07): Delete Selected Item.

R (0x15): Rename Selected Item.

Shift + Enter: Force-open a .lua file in the Code Editor.

Backspace: Return to previous directory or Desktop.

TECHNICAL REQUIREMENTS & PINS

Display: ILI9341 via HWSPI (Pins: DC:2, CS:15, CLK:14, MOSI:13).

Touch: XPT2046 via VSPI (Pins: CS:33, CLK:25, MOSI:32, MISO:39).

RGB LED: Red: 4, Green: 16, Blue: 17 (Active Low).

Buzzer: Pin 26.

Partition Scheme: Huge APP (3MB No OTA).

IMPLEMENTATION NOTES

Power Management: Holding the Boot button (GPIO 0) triggers a software-controlled shutdown. The system enters Deep Sleep and disables the backlight (GPIO 21) while maintaining a "HOLD" state on LEDs.

Dual Core: BLE Keyboard tasks are isolated to Core 0 to prevent UI micro-stuttering.

Color System: All graphics functions support 16-bit RGB565 colors. Lua globals like RED, GREEN, BLUE, and RAINBOW are pre-defined for ease of use.
