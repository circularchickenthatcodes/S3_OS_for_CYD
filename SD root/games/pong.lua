-- PONG.lua (CYD VERSION)
local bx, by, vx, vy = 160, 120, 3, 2
local py, botY, pScore, bScore = 90, 90, 0, 0
local oBx, oBy, oPy, oBotY = 160, 120, 90, 90
setTextSize(2)
cls(0)

while true do
    oPy, oBotY = py, botY
    if isKeyDown(0x1A) then py = py - 5 end
    if isKeyDown(0x16) then py = py + 5 end
    py = math.max(0, math.min(180, py))

    if vx > 0 and bx > 160 then -- Bot AI
        if botY < by - 30 then botY = botY + 3 elseif botY > by - 30 then botY = botY - 3 end
    end
    botY = math.max(0, math.min(180, botY))

    oBx, oBy = bx, by
    bx, by = bx + vx, by + vy
    if by <= 0 or by >= 232 then vy = -vy playSound(400, 10) end

    if bx <= 25 and bx >= 15 and by >= py and by <= py + 60 then
        vx, vy = math.abs(vx) + 0.3, (by - (py + 30)) * 0.2
        playSound(600, 15)
    end
    if bx >= 295 and bx <= 305 and by >= botY and by <= botY + 60 then
        vx, vy = -math.abs(vx) - 0.3, (by - (botY + 30)) * 0.2
        playSound(600, 15)
    end

    if bx < 0 or bx > 320 then
        if bx < 0 then bScore = bScore + 1 else pScore = pScore + 1 end
        fillRect(130, 0, 60, 30, 0)
        printAt(140, 5, pScore .. "-" .. bScore, 0xFFFF)
        if pScore == 10 or bScore == 10 then break end
        bx, by, vx, vy = 160, 120, (bx < 0 and 3 or -3), 2
    end

    if oPy ~= py then fillRect(15, oPy, 8, 60, 0) end
    if oBotY ~= botY then fillRect(300, oBotY, 8, 60, 0) end
    fillRect(oBx, oBy, 6, 6, 0)
    fillRect(15, py, 8, 60, 0x07E0)
    fillRect(300, botY, 8, 60, 0xF800)
    fillRect(bx, by, 6, 6, 0xFFFF)

    if isKeyDown(0x29) then break end
    delay(10)
end