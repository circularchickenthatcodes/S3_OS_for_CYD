-- CIRCLE.lua (CYD VERSION - 320x240)
setTextSize(1)
cls(0)

local difficulty = 1.0 
local pSpeed = 2.5 + (difficulty * 1.0)
local cSpeed = 0.4 + (difficulty * 0.4)

local score, r = 0, 12 -- Slightly smaller radius for smaller screen
local px, py = 40.0, 40.0
local oldX, oldY = 40, 40

local SCREEN_W, SCREEN_H = 320, 240
local tx = math.random(r, SCREEN_W - r)
local ty = math.random(r, SCREEN_H - r)

local cx, cy = SCREEN_W - 40.0, SCREEN_H - 40.0
local oldCx, oldCy = math.floor(cx), math.floor(cy)

circle(tx, ty, r + 2, 0xFFFF, false)
delay(150)

while true do
    local moveX, moveY = 0, 0
    if isKeyDown(0x04) or isKeyDown(0x50) then moveX = -1 
    elseif isKeyDown(0x07) or isKeyDown(0x4F) then moveX = 1 end
    if isKeyDown(0x1A) or isKeyDown(0x52) then moveY = -1 
    elseif isKeyDown(0x16) or isKeyDown(0x51) then moveY = 1 end

    px = math.max(r, math.min(SCREEN_W - r, px + (moveX * pSpeed)))
    py = math.max(r, math.min(SCREEN_H - r, py + (moveY * pSpeed)))
    local x, y = math.floor(px), math.floor(py)

    if cx < x then cx = cx + cSpeed elseif cx > x then cx = cx - cSpeed end
    if cy < y then cy = cy + cSpeed elseif cy > y then cy = cy - cSpeed end

    if ((x - cx)^2 + (y - cy)^2) < (r * 2)^2 then break end

    if ((x - tx)^2 + (y - ty)^2) < (r * 2)^2 then
        score = score + 1
        playSound(1200, 30)
        circle(tx, ty, r + 2, 0x0000, false) 
        tx = math.random(r, SCREEN_W - r)
        ty = math.random(r, SCREEN_H - r)
        circle(tx, ty, r + 2, 0xFFFF, false)
        if score % 5 == 0 then cSpeed = cSpeed + 0.15 end
    end

    local playerMoved = (x ~= oldX or y ~= oldY)
    local chaserMoved = (math.floor(cx) ~= oldCx or math.floor(cy) ~= oldCy)

    if playerMoved or chaserMoved then
        if playerMoved then circle(oldX, oldY, r, 0x0000, true) end
        if chaserMoved then circle(oldCx, oldCy, r, 0x0000, true) end
        circle(tx, ty, r + 2, 0xFFFF, false) -- Always redraw target
        circle(x, y, r, 0x07E0, true) 
        circle(math.floor(cx), math.floor(cy), r, 0xF800, true) 
        oldX, oldY, oldCx, oldCy = x, y, math.floor(cx), math.floor(cy)
    end

    if isKeyDown(0x29) then return end
    delay(5) 
end

-- --- CYD GAME OVER ---
cls(0)
setTextSize(4) -- Smaller size to fit screen
printAt(50, 50, "GAME OVER", 0xF800)
setTextSize(2)
printAt(110, 110, "Score: " .. score, 0xFFFF)
delay(1000)
printAt(60, 180, "RELEASE BUTTON...", 0x07FF)
while isKeyDown(0x28) do delay(10) end
fillRect(0, 180, 320, 40, 0)
printAt(40, 180, "PRESS ENTER TO RETURN", 0x07FF)
while not isKeyDown(0x28) do delay(10) end