-- =======================================================
-- S3 ULTIMATE - INVADERS (320x240 SCALED & UI FIXED)
-- =======================================================

local getTime = function() 
    if millis then return millis() end
    if os and os.clock then return os.clock() * 1000 end
    return nil 
end

local sprite = {0x18, 0x3C, 0x7E, 0xDB, 0xFF, 0x24, 0x5A, 0xA5}
local waveColors = {0xF81F, 0x07E0, 0x001F, 0xFFE0, 0x07FF, 0xFFFF}

local function drawA(x, y, c)
    for i = 1, 8 do
        local r = sprite[i]
        local bitVal = 128 
        for j = 0, 7 do 
            if (r / bitVal) % 2 >= 1 then 
                fillRect(x+(j*2), y+(i*2), 2, 2, c) 
            end 
            bitVal = bitVal / 2
        end
    end
end

-- Game Variables
local px, bullets, enemyBullets, enemies, eDir, eY = 145, {}, {}, {}, 1, 30
local pSpeed = 6 
local pWidth = 24 
local score = 0
local wave = 1
local gameOver = false

-- Timing
local lastMoveTime = getTime() or 0
local moveInterval = 500 
local lastShotTime = 0
local shootDelay = 400   
local frameFallback = 0

local function initEnemies()
    enemies = {}
    for r = 0, 2 do 
        for c = 0, 5 do 
            table.insert(enemies, {x=c*40+45, y=r*25, a=true}) 
        end 
    end
end

-- --- FIXED UI DRAWING ---
local function drawUI()
    -- 1. Clear the Score Area (X:5-130, Y:5-15)
    -- We use a width of 125 to cover "SCORE: 99999"
    fillRect(5, 5, 125, 10, 0)
    
    -- 2. Clear the Wave Area (X:220-315, Y:5-15)
    fillRect(220, 5, 95, 10, 0)
    
    setTextSize(1)
    printAt(5, 5, "SCORE: " .. score, 0xFFFF)
    printAt(220, 5, "WAVE: " .. wave, 0xFFFF)
end

local function showGameOver()
    playSound(150, 500)
    cls(0)
    setTextSize(3)
    printAt(70, 80, "GAME OVER", 0xF800)
    setTextSize(2)
    printAt(100, 130, "Score: " .. score, 0xFFFF)
    delay(1000) 
    printAt(60, 190, "RELEASE BUTTON...", 0x07FF)
    while isKeyDown(0x28) do delay(10) end
    fillRect(40, 190, 240, 20, 0) 
    printAt(45, 190, "PRESS ENTER TO RETURN", 0x07FF)
    while not isKeyDown(0x28) do delay(10) end
    playSound(1200, 50)
    delay(300) 
end

initEnemies()
cls(0)
-- Draw initial player state
fillRect(px, 215, pWidth, 10, 0x07E0)

-- --- MAIN LOOP ---
while not gameOver do
    local now = getTime() or frameFallback
    if not getTime() then frameFallback = frameFallback + 10 end

    -- 1. PLAYER INPUT (Dirty Rects)
    local oPx = px
    if isKeyDown(0x04) or isKeyDown(0x50) then px = px - pSpeed 
    elseif isKeyDown(0x07) or isKeyDown(0x4F) then px = px + pSpeed end
    
    px = math.max(5, math.min(320 - pWidth - 5, px))
    
    if oPx ~= px then 
        fillRect(oPx, 215, pWidth, 10, 0)      -- Clear old position
        fillRect(px, 215, pWidth, 10, 0x07E0) -- Draw new position
    end

    -- 2. PLAYER SHOOTING
    if (isKeyDown(0x1A) or isKeyDown(0x2C)) and #bullets < 3 then
        if now - lastShotTime >= shootDelay then
            table.insert(bullets, {x=px + (pWidth/2) - 1, y=205}) 
            playSound(2000, 10)
            lastShotTime = now 
        end
    end

    -- 3. PLAYER BULLET LOGIC (Dirty Rects)
    for i = #bullets, 1, -1 do
        local b = bullets[i]
        fillRect(b.x, b.y, 2, 6, 0) -- Erase
        b.y = b.y - 8
        if b.y < 15 then 
            table.remove(bullets, i) 
        else
            local hit = false
            for _, e in ipairs(enemies) do
                if e.a and b.x > e.x and b.x < e.x+16 and b.y > (e.y+eY) and b.y < (e.y+eY+16) then
                    e.a, hit = false, true
                    score = score + 10
                    fillRect(e.x, e.y+eY, 18, 18, 0) -- Clear Alien
                    table.remove(bullets, i)
                    playSound(400, 10) 
                    break
                end
            end
            if not hit then fillRect(b.x, b.y, 2, 6, 0xFFFF) end
        end
    end

    -- 4. ENEMY BULLET LOGIC (Dirty Rects)
    for i = #enemyBullets, 1, -1 do
        local eb = enemyBullets[i]
        fillRect(eb.x, eb.y, 3, 6, 0) -- Erase
        eb.y = eb.y + 5 
        if eb.y > 240 then
            table.remove(enemyBullets, i)
        else
            if eb.x > px and eb.x < px + pWidth and eb.y > 210 then
                gameOver = true
                break
            else
                fillRect(eb.x, eb.y, 3, 6, 0xF800) -- Red enemy bullet
            end
        end
    end

    -- 5. ALIEN LOGIC
    local activeCount = 0
    for _, e in ipairs(enemies) do if e.a then activeCount = activeCount + 1 end end

    if activeCount == 0 then
        wave = wave + 1
        eY, lastMoveTime = 30, now
        initEnemies()
        -- Wipe game area for new wave (preserving UI at top)
        fillRect(0, 15, 320, 200, 0) 
    else
        if now - lastMoveTime >= moveInterval then
            for _, e in ipairs(enemies) do
                if e.a then fillRect(e.x, e.y+eY, 18, 18, 0) end
            end

            local edge = false
            for _, e in ipairs(enemies) do
                if e.a and (e.x + (eDir * 12) > 290 or e.x + (eDir * 12) < 5) then 
                    edge = true 
                end
            end

            if edge then 
                eDir = -eDir
                eY = eY + 12 
                if eY + 16 >= 210 then gameOver = true end
            else
                for _, e in ipairs(enemies) do
                    if e.a then 
                        e.x = e.x + (eDir * 12) 
                        if math.random(1, 100) > 94 and #enemyBullets < 3 then
                            table.insert(enemyBullets, {x=e.x+8, y=e.y+eY+16})
                        end
                    end
                end
            end
            lastMoveTime = now 
        end

        local currentColor = waveColors[(wave - 1) % #waveColors + 1]
        for _, e in ipairs(enemies) do 
            if e.a then drawA(e.x, e.y+eY, currentColor) end 
        end
    end

    drawUI() 
    if isKeyDown(0x29) then break end
    delay(5) 
end

showGameOver()