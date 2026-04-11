S3-OS: LUA-POWERED MICRO-OS FOR ESP32
  
A modular operating system framework for the Cheap Yellow Display (CYD)
S3-OS is a lightweight multitasking operating system designed for the ESP32-S3 and WROOM architectures. It features a desktop environment, an integrated text editor, a multimedia player, and a Lua-based API that allows users to execute applications and games directly from an SD card without firmware modification.
________________
CORE FEATURES
  
* Dual-Core Task Distribution: The UI and OS kernel operate on Core 1, while the NimBLE stack is pinned to Core 0 to ensure radio operations do not interfere with display refresh rates.
* Desktop and App Launcher: A visual icon-based desktop that scans the apps folder for bundles and a legacy S3 Games launcher for standalone scripts.
* Integrated Code Editor: Build and modify Lua scripts directly on the device with keyboard support and real-time scrolling.
* Multimedia Suite: Built-in support for rendering JPEG images and playback of MJPEG video files from the SD card.
* Lua Virtual Machine: Provides a sandbox for third-party scripts with direct hooks into hardware functions via the custom os library.
________________
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
The .game File  
The .game file serves two purposes:  
1. App Discovery: Its presence tells the OS that the parent folder is a valid application.  
2. Metadata: The text content inside the file is read by the OS and displayed as the App Name on the desktop UI.  
________________
LUA API REFERENCE
  
The following functions are exported from the C++ kernel to the Lua environment:
Graphics and Display
* cls(color): Fills the active display buffer with a specific 16-bit color.
* setTextSize(size): Sets the global font scaling for text rendering.
* printAt(x, y, text, color): Renders a string at the specified pixel coordinates.
* rect(x, y, w, h, color): Draws a rectangle outline.
* fillRect(x, y, w, h, color): Draws a solid, filled rectangle.
* circle(x, y, r, color, fill): Draws or fills a circle based on the boolean fill parameter.
* drawImg(path, x, y, scale): Renders a JPEG image from the application directory.
System and Hardware
* getTouch(): Returns the current status and X/Y coordinates of a touch event.
* getPressedKey(): Returns the ASCII string (e.g., "a") or the raw HID integer code of the current key press. Returns nil if no key is detected.
* isKeyDown(hid_code): Returns boolean true if a specific HID key is currently held down.
* playSound(freq, ms): Generates a tone on the onboard buzzer at a specific frequency.
* delay(ms): Pauses script execution without blocking the core OS kernel tasks.
________________
FILE EXPLORER SHORTCUTS
  
When using the File Manager, the following keyboard shortcuts are available:
* N: Create New File
* M: Create New Directory (MkDir)
* D: Delete Selected Item
* R: Rename Selected Item
* Shift + Enter: Open selected file in the Code Editor
________________
TECHNICAL REQUIREMENTS
  
* Arduino Core: ESP32 by Espressif Systems v3.3.6. (Note: v3.3.7 contains regressions affecting NimBLE initialization).
* Partition Scheme: Huge APP (2MB No OTA / 2MB FATFS).
* Flash Mode: DIO @ 40MHz for standard ESP32.
* Required Libraries: NimBLE-Arduino (v1.4.2), GFX_Library_for_Arduino, and TJpg_Decoder.
________________
IMPLEMENTATION NOTES
  
* BLE Stack: The Bluetooth task is initialized with a 20,000 to 30,000-byte stack on Core 0 to ensure stability during active device scanning.
* Color Correction: If display colors appear inverted, the OS uses gfx->invertDisplay(true) to correct the signal for IPS panels.
* Bus Sharing: The SPI bus is shared between the display and the SD card. The kernel manages Chip Select (CS) logic and clock speeds to prevent data collision.
* Power Management: Holding the Boot button (GPIO 0) triggers a software-controlled shutdown sequence and enters Deep Sleep.
