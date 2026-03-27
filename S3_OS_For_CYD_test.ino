#include <Arduino_GFX_Library.h>
#include <SD.h>
#include <SPI.h>
#include <NimBLEDevice.h>
#include <set>
#include <vector>
#include <TJpg_Decoder.h>
#include <XPT2046_Touchscreen.h>
#include <functional>
#include "driver/gpio.h"
#include "esp_bt.h"

// --- LUA 5.1 HEADERS ---
extern "C" {
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}

// --- CYD (ESP32-2432S028) PINS ---
#define TFT_BL 21
#define TFT_DC 2
#define TFT_RST 12
#define TFT_CS 15
#define TFT_MOSI 13
#define TFT_CLK 14
#define TFT_MISO 12

#define SD_CS 5
#define SD_MOSI 23
#define SD_MISO 19
#define SD_SCK 18

#define TOUCH_CS 33
#define TOUCH_IRQ 36
#define TOUCH_MOSI 32
#define TOUCH_MISO 39
#define TOUCH_CLK 25

#define BUZZER_PIN 26

// --- RGB LED PINS (Active Low) ---
#define LED_RED 4
#define LED_GREEN 16
#define LED_BLUE 17

// --- SHARED INPUTS ---
volatile int8_t kbdY = 0;
volatile int8_t kbdX = 0;  // Added for horizontal nav
volatile bool kbdEnter = false;
volatile bool kbdBack = false;
volatile bool kbdShift = false;
volatile char lastKey = 0;
volatile uint8_t lastRawKey = 0;
std::set<uint8_t> pressedKeys;

const char *targetDeviceName = "JK-61 5.0";

// --- HARDWARE OBJECTS ---
SPIClass sdSPI(HSPI);
SPIClass touchSPI(VSPI);
XPT2046_Touchscreen touch(TOUCH_CS, TOUCH_IRQ);
Arduino_DataBus *bus = new Arduino_HWSPI(TFT_DC, TFT_CS, TFT_CLK, TFT_MOSI, TFT_MISO);
Arduino_GFX *gfx = new Arduino_ILI9341(bus, TFT_RST, 1 /* rotation */);

// --- STATE ---
String currentPath = "/";
String editorBuffer = "";
int cursor = 0, fileCount = 0, displayOffset = 0;
bool inEditor = false;

// ===================== POWER & LED LOGIC =====================

void checkPowerButton() {
  if (digitalRead(0) == LOW) {
    delay(200);
    gfx->setTextSize(2);
    gfx->fillScreen(0x0000);
    gfx->setTextColor(0x07E0);
    gfx->setCursor(80, 110);
    gfx->println("SHUTTING DOWN...");
    noTone(BUZZER_PIN);
    digitalWrite(BUZZER_PIN, LOW);
    digitalWrite(LED_GREEN, HIGH);
    digitalWrite(LED_RED, LOW);
    delay(1000);
    digitalWrite(TFT_BL, LOW);
    gfx->displayOff();
    gpio_hold_en((gpio_num_t)LED_RED);
    gpio_hold_en((gpio_num_t)LED_GREEN);
    gpio_deep_sleep_hold_en();
    esp_sleep_enable_ext0_wakeup(GPIO_NUM_0, 0);
    esp_deep_sleep_start();
  }
}

// ===================== JPG RENDERER CALLBACK =====================
bool tft_output(int16_t x, int16_t y, uint16_t w, uint16_t h, uint16_t *bitmap) {
  if (y >= gfx->height()) return false;
  int16_t draw_w = w;
  if (x + w > gfx->width()) draw_w = gfx->width() - x;
  if (draw_w > 0) gfx->draw16bitRGBBitmap(x, y, bitmap, draw_w, h);
  return true;
}

// ===================== EXPLORER DRAWING =====================
uint16_t getRainbow(int hue) {
  hue = hue % 360;
  float s = 1.0, v = 1.0;
  float c = v * s;
  float x = c * (1 - abs(fmod(hue / 60.0, 2) - 1));
  float m = v - c;
  float r, g, b;
  if (hue < 60) {
    r = c;
    g = x;
    b = 0;
  } else if (hue < 120) {
    r = x;
    g = c;
    b = 0;
  } else if (hue < 180) {
    r = 0;
    g = c;
    b = x;
  } else if (hue < 240) {
    r = 0;
    g = x;
    b = c;
  } else if (hue < 300) {
    r = x;
    g = 0;
    b = c;
  } else {
    r = c;
    g = 0;
    b = x;
  }
  return ((uint16_t)((r + m) * 31) << 11) | ((uint16_t)((g + m) * 63) << 5) | (uint16_t)((b + m) * 31);
}

void runLua(String filename);

void gameLauncherMenu() {
  const char *mOpts[] = { "CIRCLE", "SNAKE", "PONG", "INVADERS", "EXIT" };
  const char *fNames[] = { "circle.lua", "snake.lua", "pong.lua", "invaders.lua", "" };
  int sel = 0;
  bool redraw = true;
  bool inMenu = true;
  gfx->fillScreen(0x0000);

  while (inMenu) {
    checkPowerButton();
    gfx->setCursor(28, 15);
    gfx->setTextSize(4);
    gfx->setTextColor(getRainbow(millis() / 10), 0x0000);
    gfx->println("S3 ULTIMATE");

    if (redraw) {
      for (int i = 0; i < 5; i++) {
        gfx->setCursor(34, 65 + (i * 30));
        gfx->setTextSize(3);
        if (i == sel) {
          gfx->setTextColor(0xFFFF, 0x0000);
          gfx->printf("> %-10s <", mOpts[i]);
        } else {
          gfx->setTextColor(0x4208, 0x0000);
          gfx->printf("  %-10s  ", mOpts[i]);
        }
      }
      gfx->setTextSize(1);
      gfx->setTextColor(0xFFE0, 0x0000);
      gfx->setCursor(10, 225);
      gfx->print(" Done by: Ibrahim Malas assisted by Mr.Talha");
      redraw = false;
    }

    if (kbdY != 0) {
      if (kbdY > 0) sel = (sel + 1) % 5;
      else sel = (sel + 4) % 5;
      kbdY = 0;
      redraw = true;
      tone(BUZZER_PIN, 800, 5);
    }

    if (touch.touched()) {
      TS_Point p = touch.getPoint();
      int ty = map(p.y, 240, 3800, 0, 240);
      int tappedIdx = (ty - 50) / 30;
      if (tappedIdx >= 0 && tappedIdx <= 4) {
        if (sel == tappedIdx) kbdEnter = true;
        else {
          sel = tappedIdx;
          redraw = true;
          tone(BUZZER_PIN, 800, 5);
        }
      }
      delay(150);
    }

    if (kbdEnter) {
      kbdEnter = false;
      tone(BUZZER_PIN, 1500, 100);
      if (sel == 4) inMenu = false;
      else {
        String gamePath = "/games/" + String(fNames[sel]);
        runLua(gamePath);
        gfx->fillScreen(0x0000);
        redraw = true;
      }
    }
    if (kbdBack) {
      kbdBack = false;
      inMenu = false;
    }
    vTaskDelay(2);
  }
}

void drawFileLine(int index, bool highlight) {
  int y = 45 + (index * 24);
  if (currentPath == "/" && (index + displayOffset) == 0) {
    gfx->fillRect(0, y, 320, 24, highlight ? 0x07E0 : 0x0000);
    gfx->setCursor(10, y + 4);
    gfx->setTextColor(highlight ? 0x0000 : 0x07FF);
    gfx->setTextSize(2);
    gfx->print("[APP] S3 Games");
    return;
  }
  File root = SD.open(currentPath);
  int skipCount = (currentPath == "/") ? (displayOffset + index - 1) : (displayOffset + index);
  for (int i = 0; i < skipCount; i++) {
    File e = root.openNextFile();
    e.close();
  }
  File entry = root.openNextFile();
  if (!entry) {
    root.close();
    return;
  }
  gfx->fillRect(0, y, 320, 24, highlight ? 0x07E0 : 0x0000);
  gfx->setCursor(10, y + 4);
  gfx->setTextColor(highlight ? 0x0000 : (entry.isDirectory() ? 0x5DFF : 0xFFFF));
  gfx->setTextSize(2);
  gfx->printf("%s %s", entry.isDirectory() ? "[DIR]" : "     ", entry.name());
  entry.close();
  root.close();
}

void fullRedraw() {
  gfx->fillScreen(0x0000);
  gfx->setTextColor(0x07E0);
  gfx->setTextSize(2);
  gfx->setCursor(10, 5);
  gfx->print("PATH: ");
  gfx->println(currentPath);
  gfx->setCursor(10, 25);
  gfx->setTextColor(0xFFFF);
  gfx->setTextSize(1);
  gfx->println("N:New M:MkDir D:Del R:Ren S+ENT:Open");
  gfx->drawFastHLine(0, 40, 320, 0x07E0);
  fileCount = (currentPath == "/") ? 1 : 0;
  File root = SD.open(currentPath);
  while (File entry = root.openNextFile()) {
    fileCount++;
    entry.close();
  }
  root.close();
  for (int i = 0; i < 8; i++) {
    if (i + displayOffset < fileCount) drawFileLine(i, (i + displayOffset == cursor));
  }
}

// ===================== MJPEG PLAYER =====================
void playMJPEG(String path) {
  File mjpegFile = SD.open(path, FILE_READ);
  if (!mjpegFile) return;
  size_t buf_size = 32000;
  uint8_t *mjpeg_buf = (uint8_t *)malloc(buf_size);
  if (!mjpeg_buf) {
    mjpegFile.close();
    return;
  }
  gfx->fillScreen(0x0000);
  const int targetTime = 41;
  while (mjpegFile.available() && !kbdBack) {
    checkPowerButton();
    unsigned long frameStart = millis();
    bool foundStart = false;
    while (mjpegFile.available()) {
      if (mjpegFile.read() == 0xFF) {
        if (mjpegFile.peek() == 0xD8) {
          mjpeg_buf[0] = 0xFF;
          mjpeg_buf[1] = mjpegFile.read();
          foundStart = true;
          break;
        }
      }
    }
    if (!foundStart) break;
    int idx = 2;
    while (mjpegFile.available() && idx < buf_size - 1) {
      uint8_t b = mjpegFile.read();
      mjpeg_buf[idx++] = b;
      if (b == 0xFF && mjpegFile.peek() == 0xD9) {
        mjpeg_buf[idx++] = mjpegFile.read();
        break;
      }
    }
    TJpgDec.setJpgScale(2);
    TJpgDec.drawJpg(0, 0, mjpeg_buf, idx);
    int elapsed = millis() - frameStart;
    if (elapsed < targetTime) delay(targetTime - elapsed);
    vTaskDelay(1);
  }
  free(mjpeg_buf);
  mjpegFile.close();
  kbdBack = false;
  fullRedraw();
}

// ===================== UTILS & LUA =====================
String inputPrompt(String title) {
  String input = "";
  gfx->fillRect(20, 70, 280, 100, 0x18C3);
  gfx->drawRect(20, 70, 280, 100, 0xFFFF);
  gfx->setCursor(30, 90);
  gfx->setTextColor(0xFFFF);
  gfx->setTextSize(2);
  gfx->print(title);
  while (true) {
    checkPowerButton();
    gfx->fillRect(30, 120, 260, 30, 0x0000);
    gfx->setCursor(35, 125);
    gfx->print(input + "_");
    if (lastRawKey != 0) {
      uint8_t rk = lastRawKey;
      char c = lastKey;
      lastRawKey = 0;
      lastKey = 0;
      if (rk == 0x28) return input;
      if (rk == 0x29) return "";
      if (rk == 0x2A && input.length() > 0) input.remove(input.length() - 1);
      else if (c >= 32 && c <= 126 && input.length() < 20) input += c;
    }
    delay(10);
  }
}

static int l_getTouch(lua_State *L) {
  if (touch.touched()) {
    TS_Point p = touch.getPoint();
    int x = map(p.x, 200, 3700, 0, 320);
    int y = map(p.y, 240, 3800, 0, 240);
    lua_pushboolean(L, true);
    lua_pushinteger(L, x);
    lua_pushinteger(L, y);
    return 3;
  }
  lua_pushboolean(L, false);
  return 1;
}
static int l_setTextSize(lua_State *L) {
  gfx->setTextSize((int)luaL_optinteger(L, 1, 1));
  return 0;
}
static int l_cls(lua_State *L) {
  gfx->fillScreen((uint16_t)luaL_optinteger(L, 1, 0x0000));
  return 0;
}
static int l_printAt(lua_State *L) {
  gfx->setTextColor((uint16_t)luaL_optinteger(L, 4, 0xFFFF));
  gfx->setCursor(luaL_checkinteger(L, 1), luaL_checkinteger(L, 2));
  gfx->print(luaL_checkstring(L, 3));
  return 0;
}
static int l_isKeyDown(lua_State *L) {
  uint8_t keyCheck = (uint8_t)luaL_checkinteger(L, 1);
  lua_pushboolean(L, pressedKeys.find(keyCheck) != pressedKeys.end());
  return 1;
}
static int l_rect(lua_State *L) {
  gfx->drawRect(luaL_checkinteger(L, 1), luaL_checkinteger(L, 2), luaL_checkinteger(L, 3), luaL_checkinteger(L, 4), (uint16_t)luaL_checkinteger(L, 5));
  return 0;
}
static int l_fillRect(lua_State *L) {
  gfx->fillRect(luaL_checkinteger(L, 1), luaL_checkinteger(L, 2), luaL_checkinteger(L, 3), luaL_checkinteger(L, 4), (uint16_t)luaL_checkinteger(L, 5));
  return 0;
}
static int l_circle(lua_State *L) {
  if (lua_toboolean(L, 5)) gfx->fillCircle(luaL_checkinteger(L, 1), luaL_checkinteger(L, 2), luaL_checkinteger(L, 3), (uint16_t)luaL_checkinteger(L, 4));
  else gfx->drawCircle(luaL_checkinteger(L, 1), luaL_checkinteger(L, 2), luaL_checkinteger(L, 3), (uint16_t)luaL_checkinteger(L, 4));
  return 0;
}
static int l_playSound(lua_State *L) {
  tone(BUZZER_PIN, luaL_checkinteger(L, 1), luaL_checkinteger(L, 2));
  return 0;
}
static int l_getJoystick(lua_State *L) {
  int x = 2048, y = 2048;
  if (pressedKeys.count(0x04) || pressedKeys.count(0x50)) x = 0;
  if (pressedKeys.count(0x07) || pressedKeys.count(0x4F)) x = 4095;
  if (pressedKeys.count(0x1A) || pressedKeys.count(0x52)) y = 0;
  if (pressedKeys.count(0x16) || pressedKeys.count(0x51)) y = 4095;
  lua_pushinteger(L, x);
  lua_pushinteger(L, y);
  lua_pushboolean(L, kbdEnter);
  return 3;
}
static int l_delay(lua_State *L) {
  checkPowerButton();
  delay(luaL_checkinteger(L, 1));
  return 0;
}
static int l_drawImg(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
  int x = luaL_checkinteger(L, 2);
  int y = luaL_checkinteger(L, 3);
  int scale = (int)luaL_optinteger(L, 4, 1);
  String fullPath = currentPath + (currentPath.endsWith("/") ? "" : "/") + String(path);
  TJpgDec.setJpgScale(scale);
  TJpgDec.drawSdJpg(x, y, fullPath.c_str());
  return 0;
}

void runLua(String filename) {
  String fullPath = filename.startsWith("/") ? filename : (currentPath + (currentPath.endsWith("/") ? "" : "/") + filename);
  File f = SD.open(fullPath);
  if (!f) return;
  String code = f.readString();
  f.close();
  lua_State *L = luaL_newstate();
  luaL_openlibs(L);
  lua_register(L, "getTouch", l_getTouch);
  lua_register(L, "setTextSize", l_setTextSize);
  lua_register(L, "cls", l_cls);
  lua_register(L, "printAt", l_printAt);
  lua_register(L, "isKeyDown", l_isKeyDown);
  lua_register(L, "rect", l_rect);
  lua_register(L, "fillRect", l_fillRect);
  lua_register(L, "circle", l_circle);
  lua_register(L, "playSound", l_playSound);
  lua_register(L, "getJoystick", l_getJoystick);
  lua_register(L, "delay", l_delay);
  lua_register(L, "drawImg", l_drawImg);
  gfx->setTextSize(1);
  gfx->fillScreen(0x0000);
  if (luaL_dostring(L, code.c_str()) != 0) {
    gfx->setTextColor(0xF800);
    gfx->setCursor(10, 10);
    gfx->println("LUA ERROR:");
    gfx->println(lua_tostring(L, -1));
    while (!kbdBack) {
      checkPowerButton();
      delay(10);
    }
  } else {
    while (!kbdBack) {
      checkPowerButton();
      delay(10);
    }
  }
  lua_close(L);
  kbdBack = false;
}

// ===================== HID & BLE =====================
char hidToAscii(uint8_t key, uint8_t mod) {
  bool shift = (mod & 0x02) || (mod & 0x20);
  if (key >= 0x04 && key <= 0x1D) return (shift ? 'A' : 'a') + (key - 0x04);
  if (key >= 0x1E && key <= 0x27) {
    if (!shift) {
      if (key == 0x27) return '0';
      return '1' + (key - 0x1E);
    } else {
      const char shiftNumbers[] = "!@#$%^&*()";
      return shiftNumbers[key - 0x1E];
    }
  }
  if (key == 0x2C) return ' ';
  if (key == 0x28) return '\n';
  if (key == 0x2D) return (shift ? '_' : '-');
  if (key == 0x2E) return (shift ? '+' : '=');
  if (key == 0x33) return (shift ? ':' : ';');
  if (key == 0x34) return (shift ? '"' : '\'');
  if (key == 0x36) return (shift ? '<' : ',');
  if (key == 0x37) return (shift ? '>' : '.');
  if (key == 0x38) return (shift ? '?' : '/');
  return 0;
}

static void notifyCallback(NimBLERemoteCharacteristic *pChar, uint8_t *pData, size_t length, bool isNotify) {
  if (length < 3) return;
  uint8_t mod = pData[0];
  kbdShift = (mod & 0x02) || (mod & 0x20);
  pressedKeys.clear();
  bool hasKey = false;
  for (int i = 2; i < length; i++) {
    if (pData[i] != 0) {
      pressedKeys.insert(pData[i]);
      lastRawKey = pData[i];
      hasKey = true;
    }
  }
  if (!hasKey) {
    kbdY = 0;
    kbdX = 0;
    kbdEnter = false;
    kbdBack = false;
    lastRawKey = 0;
  } else {
    if (pressedKeys.count(0x1A) || pressedKeys.count(0x52)) kbdY = -1;
    if (pressedKeys.count(0x16) || pressedKeys.count(0x51)) kbdY = 1;
    if (pressedKeys.count(0x04) || pressedKeys.count(0x50)) kbdX = -1;
    if (pressedKeys.count(0x07) || pressedKeys.count(0x4F)) kbdX = 1;
    if (pressedKeys.count(0x28)) kbdEnter = true;
    if (pressedKeys.count(0x2A)) kbdBack = true;
    lastKey = hidToAscii(lastRawKey, mod);
  }
}

void BLETaskCode(void *pvParameters) {
  // Give the UI plenty of time to stabilize
  vTaskDelay(pdMS_TO_TICKS(10000));

  Serial.println("--- BLE HARDWARE RESET SEQUENCE ---");

  // Force release of Classic BT memory (frees DRAM and resets controller state)
  // This is the most common fix for 0x103 when NVS erase fails.
  esp_bt_controller_mem_release(ESP_BT_MODE_CLASSIC_BT);

  // If the controller is somehow already initialized, shut it down hard
  if (esp_bt_controller_get_status() != ESP_BT_CONTROLLER_STATUS_IDLE) {
    Serial.println("Controller busy, forcing deinit...");
    esp_bt_controller_disable();
    while (esp_bt_controller_get_status() == ESP_BT_CONTROLLER_STATUS_ENABLED)
      ;
    esp_bt_controller_deinit();
  }

  Serial.printf("Memory before NimBLE: %u bytes\n", ESP.getFreeHeap());

  // Now try NimBLE Init
  NimBLEDevice::init("S3-OS");
  NimBLEDevice::setPower(ESP_PWR_LVL_P3);

  Serial.println("--- BLE INITIALIZED SUCCESSFULLY ---");

  while (true) {
    if (NimBLEDevice::getClientListSize() == 0) {
      NimBLEScan *pScan = NimBLEDevice::getScan();
      pScan->setActiveScan(true);
      NimBLEScanResults results = pScan->start(3, false);

      for (int i = 0; i < results.getCount(); i++) {
        NimBLEAdvertisedDevice device = results.getDevice(i);
        if (device.getName() == targetDeviceName) {
          NimBLEClient *pClient = NimBLEDevice::createClient();
          if (pClient->connect(&device)) {
            NimBLERemoteService *pSvc = pClient->getService("1812");
            if (pSvc) {
              auto chars = pSvc->getCharacteristics(true);
              for (auto pChr : *chars) {
                if (pChr->getUUID() == NimBLEUUID((uint16_t)0x2A4D) && pChr->canNotify()) {
                  pChr->subscribe(true, notifyCallback);
                }
              }
            }
          }
        }
      }
      pScan->clearResults();
    }
    vTaskDelay(pdMS_TO_TICKS(10000));
  }
}
// ===================== EDITOR & SYSTEM =====================
String getNewFileName() {
  int i = 1;
  while (true) {
    String name = "file" + String(i) + ".lua";
    String fullPath = currentPath + (currentPath.endsWith("/") ? "" : "/") + name;
    if (!SD.exists(fullPath)) return name;
    i++;
  }
}

void runEditor(String filename) {
  inEditor = true;
  editorBuffer = "";
  int bufferIndex = 0;
  int scrollY = 0;
  String fullPath = currentPath + (currentPath.endsWith("/") ? "" : "/") + filename;
  File f = SD.open(fullPath, FILE_READ);
  if (f) {
    while (f.available()) editorBuffer += (char)f.read();
    f.close();
  }
  bufferIndex = editorBuffer.length();

  auto drawHeader = [&]() {
    gfx->fillRect(0, 0, 320, 33, 0x0000);
    gfx->setCursor(0, 0);
    gfx->setTextColor(0x07E0);
    gfx->printf("EDIT: %s", filename.c_str());
    gfx->setCursor(0, 18);
    gfx->println("[ ] Move | TAB Save | ESC Exit");
    gfx->drawFastHLine(0, 32, 320, 0x07E0);
  };

  gfx->fillScreen(0x0000);
  drawHeader();
  gfx->setCursor(0, 35 - scrollY);
  gfx->setTextColor(0xFFFF);
  gfx->print(editorBuffer);

  while (inEditor) {
    checkPowerButton();
    static unsigned long lastFlash = 0;
    static bool cursorOn = true;
    gfx->setCursor(0, 35 - scrollY);
    gfx->print(editorBuffer.substring(0, bufferIndex));
    int16_t curY = gfx->getCursorY();
    if (curY > 220 || (curY < 35 && scrollY > 0)) {
      if (curY > 220) scrollY += 40;
      else if (curY < 35) scrollY -= 40;
      if (scrollY < 0) scrollY = 0;
      gfx->fillRect(0, 33, 320, 207, 0x0000);
      drawHeader();
      gfx->setCursor(0, 35 - scrollY);
      gfx->setTextColor(0xFFFF);
      gfx->print(editorBuffer);
    }

    if (millis() - lastFlash > 400) {
      lastFlash = millis();
      cursorOn = !cursorOn;
      gfx->setCursor(0, 35 - scrollY);
      gfx->print(editorBuffer.substring(0, bufferIndex));
      gfx->fillRect(gfx->getCursorX(), gfx->getCursorY(), 3, 16, cursorOn ? 0x07E0 : 0x0000);
    }

    if (lastRawKey != 0) {
      uint8_t rk = lastRawKey;
      char c = lastKey;
      gfx->setCursor(0, 35 - scrollY);
      gfx->print(editorBuffer.substring(0, bufferIndex));
      int16_t oldX = gfx->getCursorX();
      int16_t oldY = gfx->getCursorY();

      if (rk == 0x2A) {
        if (bufferIndex > 0) {
          gfx->fillRect(oldX, oldY, 4, 16, 0x0000);
          editorBuffer = editorBuffer.substring(0, bufferIndex - 1) + editorBuffer.substring(bufferIndex);
          bufferIndex--;
          gfx->fillRect(0, 33, 320, 207, 0x0000);
          gfx->setCursor(0, 35 - scrollY);
          gfx->print(editorBuffer);
        }
        lastRawKey = 0;
      } else if (rk == 0x4F && bufferIndex < editorBuffer.length()) {
        gfx->fillRect(oldX, oldY, 4, 16, 0x0000);
        bufferIndex++;
        lastRawKey = 0;
      } else if (rk == 0x50 && bufferIndex > 0) {
        gfx->fillRect(oldX, oldY, 4, 16, 0x0000);
        bufferIndex--;
        lastRawKey = 0;
      } else if (c != 0 || rk == 0x28) {
        char toAdd = (rk == 0x28) ? '\n' : c;
        gfx->fillRect(oldX, oldY, 4, 16, 0x0000);
        editorBuffer = editorBuffer.substring(0, bufferIndex) + toAdd + editorBuffer.substring(bufferIndex);
        bufferIndex++;
        if (rk == 0x28) {
          gfx->fillRect(0, 33, 320, 207, 0x0000);
          gfx->setCursor(0, 35 - scrollY);
          gfx->print(editorBuffer);
        } else {
          gfx->setCursor(oldX, oldY);
          gfx->print(editorBuffer.substring(bufferIndex - 1));
        }
        lastRawKey = 0;
        lastKey = 0;
      } else if (rk == 0x29) {
        inEditor = false;
        lastRawKey = 0;
      } else if (rk == 0x2B) {
        SD.remove(fullPath);
        File saveF = SD.open(fullPath, FILE_WRITE);
        saveF.print(editorBuffer);
        saveF.close();
        lastRawKey = 0;
      }
    }
    vTaskDelay(5);
  }
  fullRedraw();
}

// ===================== DESKTOP ADDITIONS =====================
struct AppInfo {
  String folderPath;
  String displayName;
  String iconPath;
  String luaPath;
};
std::vector<AppInfo> installedApps;

void loadApps() {
  installedApps.clear();
  if (!SD.exists("/apps")) SD.mkdir("/apps");
  File appsDir = SD.open("/apps");
  if (!appsDir) return;

  File folder = appsDir.openNextFile();
  while (folder) {
    if (folder.isDirectory()) {
      AppInfo app;
      app.folderPath = "/apps/" + String(folder.name());
      app.iconPath = app.folderPath + "/icon.jpg";
      app.luaPath = app.folderPath + "/main.lua";

      File sub = SD.open(app.folderPath);
      if (sub) {
        File f = sub.openNextFile();
        while (f) {
          String fname = f.name();
          if (fname.endsWith(".game")) {
            app.displayName = fname.substring(0, fname.length() - 5);
          }
          f.close();
          f = sub.openNextFile();
        }
        sub.close();
      }
      if (app.displayName != "" && installedApps.size() < 12) {
        installedApps.push_back(app);
      }
    }
    folder.close();
    folder = appsDir.openNextFile();
  }
  appsDir.close();
}

void desktopMenu() {
  loadApps();
  int selectedApp = 0;  // 0 is "Files", 1+ are installedApps
  bool redraw = true;

  auto drawIcons = [&]() {
    gfx->fillScreen(0x0000);
    gfx->setTextColor(0xFFFF);
    gfx->setTextSize(3);
    gfx->setCursor(10, 10);
    gfx->print("S3 OS");

    // Draw Files App (Index 0)
    int fx = 20, fy = 50;
    if (selectedApp == 0) gfx->drawRect(fx - 2, fy - 2, 64, 64, 0xFFFF);
    gfx->drawRect(fx, fy, 60, 60, 0x07E0);
    gfx->setCursor(fx + 5, fy + 20);
    gfx->setTextSize(2);
    gfx->setTextColor(0x07E0);
    gfx->print("DIR");
    gfx->setCursor(fx, fy + 65);
    gfx->setTextSize(1);
    gfx->setTextColor(0xFFFF);
    gfx->print("Files");

    // Draw Installed Apps
    for (int i = 0; i < (int)installedApps.size(); i++) {
      int col = (i + 1) % 4;
      int row = (i + 1) / 4;
      int x = 20 + (col * 75);
      int y = 50 + (row * 90);

      if (selectedApp == i + 1) gfx->drawRect(x - 2, y - 2, 64, 64, 0xFFFF);

      if (SD.exists(installedApps[i].iconPath)) {
        TJpgDec.setJpgScale(1);
        TJpgDec.drawSdJpg(x, y, installedApps[i].iconPath.c_str());
      } else {
        gfx->fillRect(x, y, 60, 60, 0x3186);
      }
      gfx->setCursor(x, y + 65);
      gfx->setTextColor(0xFFFF);
      gfx->setTextSize(1);
      gfx->print(installedApps[i].displayName);
    }
  };

  while (true) {
    checkPowerButton();
    if (redraw) {
      drawIcons();
      redraw = false;
    }

    // Keyboard Navigation Logic
    if (kbdX != 0 || kbdY != 0) {
      int totalItems = installedApps.size() + 1;
      int oldSel = selectedApp;

      if (kbdX != 0) {
        selectedApp = constrain(selectedApp + kbdX, 0, totalItems - 1);
        kbdX = 0;
      }
      if (kbdY != 0) {
        if (kbdY > 0) selectedApp = constrain(selectedApp + 4, 0, totalItems - 1);
        else selectedApp = constrain(selectedApp - 4, 0, totalItems - 1);
        kbdY = 0;
      }

      if (oldSel != selectedApp) {
        tone(BUZZER_PIN, 800, 5);
        redraw = true;
      }
      delay(150);
    }

    if (kbdEnter) {
      kbdEnter = false;
      tone(BUZZER_PIN, 1000, 50);
      if (selectedApp == 0) return;  // Open Files
      else {
        runLua(installedApps[selectedApp - 1].luaPath);
        redraw = true;
      }
    }

    // Touch Support
    if (touch.touched()) {
      TS_Point p = touch.getPoint();
      int tx = map(p.x, 200, 3700, 0, 320);
      int ty = map(p.y, 240, 3800, 0, 240);

      if (tx >= 20 && tx <= 80 && ty >= 50 && ty <= 110) {
        selectedApp = 0;
        tone(BUZZER_PIN, 1000, 50);
        delay(200);
        return;
      }

      for (int i = 0; i < (int)installedApps.size(); i++) {
        int col = (i + 1) % 4;
        int row = (i + 1) / 4;
        int x = 20 + (col * 75);
        int y = 50 + (row * 90);
        if (tx >= x && tx <= x + 60 && ty >= y && ty <= y + 60) {
          selectedApp = i + 1;
          tone(BUZZER_PIN, 1000, 50);
          runLua(installedApps[i].luaPath);
          redraw = true;
        }
      }
      delay(200);
    }
    vTaskDelay(10);
  }
}

// ===================== CORE SETUP =====================
void setup() {

  gpio_hold_dis((gpio_num_t)LED_RED);
  gpio_hold_dis((gpio_num_t)LED_GREEN);
  gpio_deep_sleep_hold_dis();

  pinMode(LED_RED, OUTPUT);
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_BLUE, OUTPUT);
  digitalWrite(LED_RED, HIGH);
  digitalWrite(LED_BLUE, HIGH);
  digitalWrite(LED_GREEN, LOW);

  pinMode(0, INPUT_PULLUP);
  gfx->begin(30000000);
  gfx->setRotation(1);
  

  pinMode(TFT_BL, OUTPUT);
  digitalWrite(TFT_BL, HIGH);
  pinMode(BUZZER_PIN, OUTPUT);

  touchSPI.begin(TOUCH_CLK, TOUCH_MISO, TOUCH_MOSI, TOUCH_CS);
  touch.begin(touchSPI);
  touch.setRotation(1);
  gfx->invertDisplay(true);  // If colors are wrong, try true. If they are still wrong, try false.
  
  sdSPI.begin(SD_SCK, SD_MISO, SD_MOSI, SD_CS);
  SD.begin(SD_CS, sdSPI, 30000000);

  TJpgDec.setCallback(tft_output);
  TJpgDec.setJpgScale(1);

  xTaskCreatePinnedToCore(BLETaskCode, "BLETask", 20000, NULL, 1, NULL, 1);

  desktopMenu();
  fullRedraw();
}

void loop() {
  checkPowerButton();

  static int lastTouchY = -1;
  static unsigned long touchStartTime = 0;
  static bool isSwiping = false;

  if (touch.touched()) {
    TS_Point p = touch.getPoint();
    int ty = map(p.y, 240, 3800, 0, 240);
    if (lastTouchY == -1) {
      lastTouchY = ty;
      touchStartTime = millis();
      isSwiping = false;
    } else {
      int dy = ty - lastTouchY;
      if (dy > 20) {
        kbdY = -1;
        lastTouchY = ty;
        isSwiping = true;
      } else if (dy < -20) {
        kbdY = 1;
        lastTouchY = ty;
        isSwiping = true;
      }
    }
  } else {
    if (lastTouchY != -1) {
      if (!isSwiping && (millis() - touchStartTime) < 300) {
        if (lastTouchY > 45) {
          int idx = (lastTouchY - 45) / 24;
          if (idx >= 0 && idx < 8 && (idx + displayOffset) < fileCount) {
            if (cursor == idx + displayOffset) kbdEnter = true;
            else {
              cursor = idx + displayOffset;
              fullRedraw();
            }
          }
        }
      }
      lastTouchY = -1;
    }
  }

  if (kbdY != 0) {
    int oldCursor = cursor;
    cursor = constrain(cursor + kbdY, 0, fileCount - 1);
    if (cursor < displayOffset) {
      displayOffset = cursor;
      fullRedraw();
    } else if (cursor >= displayOffset + 8) {
      displayOffset = cursor - 7;
      fullRedraw();
    } else if (oldCursor != cursor) {
      drawFileLine(oldCursor - displayOffset, false);
      drawFileLine(cursor - displayOffset, true);
    }
    kbdY = 0;
    delay(150);
  }

  if (lastRawKey == 0x11) {
    lastRawKey = 0;
    String name = getNewFileName();
    File f = SD.open(currentPath + (currentPath.endsWith("/") ? "" : "/") + name, FILE_WRITE);
    f.close();
    runEditor(name);
  }
  if (lastRawKey == 0x10) {
    lastRawKey = 0;
    String folderName = inputPrompt("Folder Name:");
    if (folderName != "") {
      SD.mkdir(currentPath + (currentPath.endsWith("/") ? "" : "/") + folderName);
      fullRedraw();
    }
  }
  if (lastRawKey == 0x07) {
    lastRawKey = 0;
    File root = SD.open(currentPath);
    int t = (currentPath == "/" && cursor > 0) ? cursor - 1 : cursor;
    for (int i = 0; i < t; i++) {
      File e = root.openNextFile();
      e.close();
    }
    File entry = root.openNextFile();
    if (entry) {
      String full = currentPath + (currentPath.endsWith("/") ? "" : "/") + entry.name();
      entry.close();
      if (!SD.remove(full)) SD.rmdir(full);
      cursor = 0;
      displayOffset = 0;
      fullRedraw();
    }
    root.close();
  }
  if (lastRawKey == 0x15) {
    lastRawKey = 0;
    File root = SD.open(currentPath);
    int t = (currentPath == "/" && cursor > 0) ? cursor - 1 : cursor;
    for (int i = 0; i < t; i++) {
      File e = root.openNextFile();
      e.close();
    }
    File entry = root.openNextFile();
    if (entry) {
      String oldName = entry.name();
      entry.close();
      String newName = inputPrompt("Rename to:");
      if (newName != "") {
        SD.rename(currentPath + (currentPath.endsWith("/") ? "" : "/") + oldName, currentPath + (currentPath.endsWith("/") ? "" : "/") + newName);
        fullRedraw();
      }
    }
    root.close();
  }

  if (kbdBack) {
    if (currentPath != "/") {
      int lastSlash = currentPath.lastIndexOf('/', currentPath.length() - 2);
      currentPath = currentPath.substring(0, lastSlash + 1);
      cursor = 0;
      displayOffset = 0;
      kbdBack = false;
      fullRedraw();
      delay(300);
    } else {
      kbdBack = false;
      desktopMenu();
      fullRedraw();
    }
  }

  if (kbdEnter) {
    bool useEditor = kbdShift;
    kbdEnter = false;
    if (currentPath == "/" && cursor == 0) {
      gameLauncherMenu();
      fullRedraw();
    } else {
      File root = SD.open(currentPath);
      int target = (currentPath == "/") ? cursor - 1 : cursor;
      for (int i = 0; i < target; i++) {
        File e = root.openNextFile();
        e.close();
      }
      File entry = root.openNextFile();
      if (entry) {
        String name = entry.name();
        String fullFileName = currentPath + (currentPath.endsWith("/") ? "" : "/") + name;
        if (entry.isDirectory()) {
          currentPath += (currentPath.endsWith("/") ? "" : "/") + name;
          cursor = 0;
          displayOffset = 0;
          fullRedraw();
        } else if (name.endsWith(".lua")) {
          if (useEditor) runEditor(name);
          else runLua(name);
          fullRedraw();
        } else if (name.endsWith(".txt")) runEditor(name);
        else if (name.endsWith(".jpg") || name.endsWith(".jpeg")) {
          gfx->fillScreen(0x0000);
          TJpgDec.setJpgScale(1);
          TJpgDec.drawSdJpg(0, 0, fullFileName.c_str());
          while (!kbdBack) {
            checkPowerButton();
            vTaskDelay(10);
          }
          kbdBack = false;
          fullRedraw();
        } else if (name.endsWith(".mjpeg") || name.endsWith(".mjpg")) {
          playMJPEG(fullFileName);
          fullRedraw();
        }
        entry.close();
      }
      root.close();
    }
    delay(300);
  }
  vTaskDelay(10);
}