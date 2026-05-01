-- --- BRESENHAM'S LINE ALGORITHM (WIDE BRUSH) ---
local brushSize = 6 -- Change this for a wider or thinner draw

function drawLine(x1, y1, x2, y2, col)
    local dx = math.abs(x2 - x1)
    local dy = math.abs(y2 - y1)
    local sx = (x1 < x2) and 1 or -1
    local sy = (y1 < y2) and 1 or -1
    local err = dx - dy
    
    local offset = math.floor(brushSize / 2)

    while true do
        -- Draw a square 'brush' at every coordinate
        -- Using (x-offset) centers the brush on your finger
        fillRect(x1 - offset, y1 - offset, brushSize, brushSize, col)
        
        if (x1 == x2 and y1 == y2) then break end
        local e2 = 2 * err
        if e2 > -dy then err = err - dy; x1 = x1 + sx end
        if e2 < dx then err = err + dx; y1 = y1 + sy end
    end
end

-- --- SETUP & UI ---
cls(0)
local color = 0x07E0
local lastX, lastY = -1, -1
local wasPressed = false

local function drawTopBar()
    fillRect(0, 0, 320, 15, 0x2104)
    -- Added Brush Size indicator to the UI
    printAt(5, 5, "COLOR: " .. string.format("0x%04X", color) .. " | BRUSH: " .. brushSize, 0xFFFF)
end

local function getHexInput()
    -- 1. WAIT for '0' to be released so it doesn't type itself
    while isKeyDown(0x27) do delay(10) end
    
    local bx, by, bw, bh = 40, 80, 240, 60
    fillRect(bx, by, bw, bh, 0x3186) -- Border
    fillRect(bx+2, by+2, bw-4, bh-4, 0x0000) -- Background
    
    setTextSize(1)
    printAt(bx+10, by+10, "ENTER 4-DIGIT HEX:", 0xFFFF)
    
    local tx, ty, tw, th = bx+10, by+25, 220, 20
    fillRect(tx, ty, tw, th, 0x1082) -- Input Field
    
    local hexStr = ""
    local hexKeys = {
        [0x27]="0", [0x1E]="1", [0x1F]="2", [0x20]="3", [0x21]="4",
        [0x22]="5", [0x23]="6", [0x24]="7", [0x25]="8", [0x26]="9",
        [0x04]="A", [0x05]="B", [0x06]="C", [0x07]="D", [0x08]="E", [0x09]="F"
    }

    while #hexStr < 4 do
        for code, char in pairs(hexKeys) do
            if isKeyDown(code) then
                -- THE FIX: Wipe the text area completely before updating the string
                -- This prevents the bottom bar of 'E' from sticking around for 'F'
                fillRect(tx + 2, ty + 2, tw - 4, th - 4, 0x1082)
                
                hexStr = hexStr .. char
                printAt(tx + 5, ty + 6, hexStr .. "_", 0x07FF)
                
                -- Wait for key release (Debounce)
                while isKeyDown(code) do delay(10) end 
            end
        end
        
        if isKeyDown(0x29) then return nil end -- ESC to cancel
        delay(10)
    end
    
    delay(200) -- Let the user see the final code
    return tonumber(hexStr, 16)
end
drawTopBar()

-- --- MAIN LOOP ---
while true do
    local pressed, tx, ty = getTouch()

    -- 1. DRAWING LOGIC
    if pressed and ty > 16 then
        if wasPressed then
            drawLine(lastX, lastY, tx, ty, color)
        else
            local offset = math.floor(brushSize / 2)
            fillRect(tx - offset, ty - offset, brushSize, brushSize, color)
        end
        lastX, lastY = tx, ty
        wasPressed = true
    else
        wasPressed = false
    end

    -- 2. COLOR & BRUSH CONTROLS
    if isKeyDown(0x1E) then color = 0xF800 drawTopBar() end -- 1
    if isKeyDown(0x1F) then color = 0x001F drawTopBar() end -- 2
    if isKeyDown(0x20) then color = 0xFFFF drawTopBar() end -- 3
    if isKeyDown(0x21) then color = 0x07E0 drawTopBar() end -- 4

    -- Adjust Brush Size with Keyboard [ + ] and [ - ]
    if isKeyDown(0x2E) then brushSize = math.min(20, brushSize + 1) drawTopBar() delay(100) end -- =/+ key
    if isKeyDown(0x2D) then brushSize = math.max(1, brushSize - 1) drawTopBar() delay(100) end  -- - key

    -- 3. HEX INPUT
    if isKeyDown(0x27) then -- '0'
        local newCol = getHexInput()
        if newCol then color = newCol end
        fillRect(40, 80, 240, 60, 0) 
        drawTopBar()
    end

    -- 4. UTILS
    if isKeyDown(0x2A) then -- BKSP
        cls(0)
        drawTopBar()
        wasPressed = false
    end
    if isKeyDown(0x29) then break end -- ESC
    
    delay(1)
end