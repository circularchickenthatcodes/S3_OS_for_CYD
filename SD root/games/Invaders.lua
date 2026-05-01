-- =======================================================
-- S3 ULTIMATE - INVADERS (LUA PORT)
-- Matches C++ Logic 1:1
-- =======================================================

local SCREEN_W = 320
local SCREEN_H = 240
local MAX_ENEMIES = 30
local MAX_BULLETS = 5

-- Difficulty settings (mapped to your 0, 1, 2 system)
-- Change this variable to test different speeds
local difficulty = 1 

local playerX = SCREEN_W / 2
local invaderDir = 1
local invaderSpeed = 1 + difficulty
local lastShotTime = 0
local running = true

local enemies = {}
local bullets = {}

-- ===================== COLOR MATH =====================
-- Recreates the C++ getRainbow(x + y) logic
function getRainbow(h)
    h = math.abs(h) % 360
    local sector = math.floor(h / 60)
    local rel = (h % 60) / 60
    local c = 255
    local x = math.floor(c * (1 - math.abs((h / 60) % 2 - 1)))
    
    local r, g, b = 0, 0, 0
    if sector == 0 then r, g, b = c, x, 0
    elseif sector == 1 then r, g, b = x, c, 0
    elseif sector == 2 then r, g, b = 0, c, x
    elseif sector == 3 then r, g, b = 0, x, c
    elseif sector == 4 then r, g, b = x, 0, c
    else r, g, b = c, 0, x end

    -- Convert to RGB565
    return (math.floor(r / 8) << 11) | (math.floor(g / 4) << 5) | math.floor(b / 8)
end

-- ===================== GAME LOGIC =====================
function resetInvaders()
    playerX = SCREEN_W / 2
    invaderDir = 1
    invaderSpeed = 1 + difficulty
    
    enemies = {}
    for row = 0, 4 do
        for col = 0, 5 do
            table.insert(enemies, {
                x = 60 + col * 40, -- Adjusted for 320w
                y = 40 + row * 25,
                alive = true
            })
        end
    end
    
    bullets = {}
    for i = 1, MAX_BULLETS do
        table.insert(bullets, {x = 0, y = 0, active = false})
    end
end

function update()
    local jX, jY, jBtn = getJoystick()
    local speed = 6

    -- Movement (A/Left or D/Right or Joystick)
    if isKeyDown(0x04) or isKeyDown(0x50) or jX < 1500 then
        playerX = playerX - speed
    elseif isKeyDown(0x07) or isKeyDown(0x4F) or jX > 2500 then
        playerX = playerX + speed
    end
    
    playerX = math.max(20, math.min(SCREEN_W - 20, playerX))

    -- Shooting (Space or Joystick Button)
    -- 300ms cooldown as per C++ logic
    local now = os.clock() * 1000 
    if (isKeyDown(0x2C) or jBtn) and (now - lastShotTime > 300) then
        for _, b in ipairs(bullets) do
            if not b.active then
                b.active = true
                b.x = playerX
                b.y = SCREEN_H - 40
                lastShotTime = now
                playSound(1500, 50)
                break
            end
        end
    end

    -- Update Bullets
    for _, b in ipairs(bullets) do
        if b.active then
            b.y = b.y - 8 -- Bullet Speed
            if b.y < 0 then b.active = false end
            
            for _, e in ipairs(enemies) do
                if e.alive and b.x > e.x and b.x < e.x + 30 and b.y > e.y and b.y < e.y + 20 then
                    e.alive = false
                    b.active = false
                    playSound(800, 40)
                end
            end
        end
    end

    -- Update Enemies
    local edgeHit = false
    for _, e in ipairs(enemies) do
        if e.alive then
            e.x = e.x + (invaderDir * invaderSpeed)
            if e.x < 10 or e.x > SCREEN_W - 40 then edgeHit = true end
        end
    end

    if edgeHit then
        invaderDir = invaderDir * -1
        for _, e in ipairs(enemies) do e.y = e.y + 15 end
    end
    
    -- Win Check
    local win = true
    for _, e in ipairs(enemies) do if e.alive then win = false break end end
    if win then
        playSound(2000, 200)
        delay(800)
        resetInvaders()
    end
end

function draw()
    cls(0x0000)
    
    -- Player (Cyan Tank)
    fillRect(playerX - 20, SCREEN_H - 30, 40, 15, 0x07FF)
    
    -- Enemies with Rainbow colors
    for _, e in ipairs(enemies) do
        if e.alive then
            fillRect(e.x, e.y, 30, 20, getRainbow(e.x + e.y))
        end
    end
    
    -- Bullets
    for _, b in ipairs(bullets) do
        if b.active then
            fillRect(b.x, b.y, 4, 10, 0xFFFF)
        end
    end
end

-- ===================== EXECUTION =====================
resetInvaders()

while running do
    update()
    draw()
    
    -- Backspace to Quit
    if isKeyDown(0x2A) then running = false end
    
    delay(16) 
end