-- Stats & Persistence
local health = 100
local ammo = 20
local level = 1
local worldMap = {}
local enemies = {}
local zBuffer = {}

-- Animation & UI State
local bob, recoil, flash = 0, 0, 0
local showPopup = false
local popupText = ""
local popupTimer = 0
local lastSpaceState = false
local lastEState = false
local showInteractPrompt = false

function generateMap()
       for x = 1, 14 do
        worldMap[x] = nil
    end
    worldMap = {}

    math.randomseed(os.time())
    for x = 1, 14 do
        worldMap[x] = {}
        for y = 1, 14 do
            if x==1 or x==14 or y==1 or y==14 then
                worldMap[x][y] = 1
            elseif math.random() > 0.85 then
                worldMap[x][y] = 1
            else
                worldMap[x][y] = 0
            end
        end
    end
    -- Clear starting area
    for i=2,4 do for j=2,4 do worldMap[i][j]=0 end end

    -- Spawn exactly 1 accessible crate
    local crateSpawned = false
    while not crateSpawned do
        local cx = math.random(5, 13)
        local cy = math.random(5, 13)
        if worldMap[cx][cy] == 0 then
            worldMap[cx][cy] = 2
            crateSpawned = true
        end
    end
end

function spawnEnemies(count)
    for i = 1, #enemies do
        enemies[i] = nil
    end
    enemies = {}
    local spawned = 0
    while spawned < count do
        local ex = math.random(2, 13)
        local ey = math.random(2, 13)
        if worldMap[ex][ey] == 0 and (ex > 5 or ey > 5) then
            table.insert(enemies, {x = ex + 0.5, y = ey + 0.5, alive = true})
            spawned = spawned + 1
        end
    end
end

function drawHUD(fireTriggered)
    local bx, by = 0, 0
    if isKeyDown("w") or isKeyDown("s") or isKeyDown("a") or isKeyDown("d") then
        bob = bob + 0.3
        bx, by = math.sin(bob) * 5, math.abs(math.cos(bob)) * 3
    end	

    recoil = recoil * 0.8
    if flash > 0 then flash = flash - 1 end
    local cx, cy = 160 + bx, 130 + by - (recoil * 2)

    -- Weapon Model
    drawTrapezoid(cx, cy + 100, 110, cx, cy + 79, 95, 0x3186)
    drawTrapezoid(cx, cy + 79, 95, cx, cy + 44, 75, 0x2104)
    drawTrapezoid(cx, cy + 44, 75, cx, cy + 30, 65, 0x18C3)

    -- Sights
    fillRect(cx - 50, cy + 70, 12, 25, 0x0000)
    fillRect(cx + 38, cy + 70, 12, 25, 0x0000)
    fillRect(cx - 2, cy + 25, 4, 8, 0x0000)

    -- Muzzle Flash
    if flash > 0 then
        fillRect(cx - 25, cy - 10, 50, 40, 0xFB20)
        fillRect(cx - 12, cy, 24, 20, 0xFFE0)
    end

    -- Stats Window
    local nx, ny = cx - 80, cy + 105
    fillRect(nx, ny, 160, 60, 0x3186)
    fillRect(nx + 10, ny + 5, 140, 55, 0x0000)
    printAt(nx + 20, ny + 20, "AMMO: " .. ammo, 0xFFE0)
    printAt(nx + 20, ny + 35, "HP: " .. health, 0xF800)

    -- Proximity Prompt
    if showInteractPrompt and not showPopup then
        printAt(110, 150, "[E] COLLECT AMMO", 0xFFFF)
    end

    -- Loot Popup
    if showPopup then
        fillRect(60, 80, 200, 50, 0x0000)
        printAt(80, 100, popupText, 0xFFFF)
        popupTimer = popupTimer - 1
        if popupTimer <= 0 then showPopup = false end
    end
end

generateMap()
spawnEnemies(3)
local px, py, pdx, pdy, plx, ply = 2.5, 2.5, 1, 0, 0, 0.66

while true do
for i = 0, 159 do
    zBuffer[i] = nil
end
    -- 1. SHOOTING
    local currentSpace = isKeyDown("space")
    local fireTriggered = false
    if currentSpace and not lastSpaceState then
        if ammo > 0 then
            recoil, flash, ammo = 22, 3, ammo - 1
            playSound(150, 20)
            fireTriggered = true
        else
            playSound(50, 10)
        end
    end
    lastSpaceState = currentSpace

    -- 2. RAYCASTING
    for x = 0, 159 do
        local camX = 2 * x / 160 - 1
        local rdx, rdy = pdx + plx * camX, pdy + ply * camX
        local mx, my = math.floor(px), math.floor(py)
        local ddx, ddy = math.abs(1/rdx), math.abs(1/rdy)
        local sx, sy, sdx, sdy
        if rdx < 0 then sx, sdx = -1, (px-mx)*ddx else sx, sdx = 1, (mx+1-px)*ddx end
        if rdy < 0 then sy, sdy = -1, (py-my)*ddy else sy, sdy = 1, (my+1-py)*ddy end
        local hit, side, t = 0, 0, 0
        while hit == 0 do
            if sdx < sdy then sdx, mx, side = sdx+ddx, mx+sx, 0 else sdy, my, side = sdy+ddy, my+sy, 1 end
            if worldMap[mx][my] > 0 then hit = 1 t = worldMap[mx][my] end
        end
        local dist = (side == 0) and (sdx-ddx) or (sdy-ddy)
        zBuffer[x] = dist
        local h = math.floor(240/dist)
        local dS, dE = math.max(0, 120-h/2), math.min(239, 120+h/2)
        local color = (t == 2) and 0xC260 or ((side == 1) and 0x2104 or 0x3186)
        fillRect(x*2, 0, 2, dS, 0x0000)
        fillRect(x*2, dS, 2, dE-dS, color)
        fillRect(x*2, dE, 2, 240-dE, 0x1082)
    end

    -- 3. ENEMIES
    local anyAlive = false
    for i, e in ipairs(enemies) do
        if e.alive then
            anyAlive = true
            local angle = math.atan2(py - e.y, px - e.x)
            local speed = 0.045
            local nx, ny = e.x + math.cos(angle) * speed, e.y + math.sin(angle) * speed
            if worldMap[math.floor(nx)][math.floor(e.y)] == 0 then e.x = nx end
            if worldMap[math.floor(e.x)][math.floor(ny)] == 0 then e.y = ny end

            local distToPlayer = math.sqrt((px-e.x)^2 + (py-e.y)^2)
            if distToPlayer < 0.45 then
                health = health - 1
                if health <= 0 then
                    cls(0xF800)
                    printAt(100, 110, "GAME OVER", 0xFFFF)
                    delay(2000)
                    health, ammo, level = 100, 20, 1
                    generateMap()
                    spawnEnemies(3)
                    px, py = 2.5, 2.5
                end
            end

            local ex, ey = e.x - px, e.y - py
            local invDet = 1.0 / (plx * pdy - pdx * ply)
            local tx, ty = invDet * (pdy * ex - pdx * ey), invDet * (-ply * ex + plx * ey)
            if ty > 0.3 then
                local sx = math.floor(160 * (1 + tx / ty))
                local rIdx = math.floor(sx/2)
                if rIdx >= 0 and rIdx < 160 and ty < zBuffer[rIdx] then
                    local sh = math.abs(math.floor(240 / ty))
                    fillRect(sx - sh/4, 120 - sh/2, sh/2, sh, 0xF800)
                    if fireTriggered and math.abs(sx - 160) < 30 then
                        e.alive = false
                        playSound(100, 30)
                    end
                end
            end
        end
    end

    -- 4. CRATE LOOTING & PROMPT
    showInteractPrompt = false
    local lx, ly = -1, -1

    for ix = -1, 1 do
        for iy = -1, 1 do
            local tx, ty = math.floor(px + ix), math.floor(py + iy)
            if tx >= 1 and tx <= 14 and ty >= 1 and ty <= 14 then
                if worldMap[tx][ty] == 2 then
                    local dx, dy = px - (tx + 0.5), py - (ty + 0.5)
                    if math.sqrt(dx*dx + dy*dy) < 1.4 then
                        showInteractPrompt = true
                        lx, ly = tx, ty
                    end
                end
            end
        end
    end

    local currentE = isKeyDown(0x08)
    if currentE and not lastEState and showInteractPrompt and not showPopup then
        local refill = math.random(10, 15)
        ammo = ammo + refill
        worldMap[lx][ly] = 0
        popupText, showPopup, popupTimer = "REFILLED +" .. refill .. " AMMO", true, 60
        playSound(400, 50)
    end
    lastEState = currentE

    -- 5. NEXT LEVEL
    if not anyAlive then
        level = level + 1
	collectgarbage("collect") -- full GC pass
        generateMap()
        spawnEnemies(2 + level)
        px, py = 2.5, 2.5
        cls(0xFFFF)
        delay(50)
    end

    drawHUD(fireTriggered)

    -- 6. MOVEMENT
    local ms, rs = 0.08, 0.12
    if isKeyDown("w") then
        if worldMap[math.floor(px+pdx*ms)][math.floor(py)] == 0 then px=px+pdx*ms end
        if worldMap[math.floor(px)][math.floor(py+pdy*ms)] == 0 then py=py+pdy*ms end
    elseif isKeyDown("s") then
        if worldMap[math.floor(px-pdx*ms)][math.floor(py)] == 0 then px=px-pdx*ms end
        if worldMap[math.floor(px)][math.floor(py-pdy*ms)] == 0 then py=py-pdy*ms end
    end
    if isKeyDown("d") then
        local odx=pdx; pdx=pdx*math.cos(rs)-pdy*math.sin(rs); pdy=odx*math.sin(rs)+pdy*math.cos(rs)
        local olx=plx; plx=plx*math.cos(rs)-ply*math.sin(rs); ply=olx*math.sin(rs)+ply*math.cos(rs)
    elseif isKeyDown("a") then
        local odx=pdx; pdx=pdx*math.cos(-rs)-pdy*math.sin(-rs); pdy=odx*math.sin(-rs)+pdy*math.cos(-rs)
        local olx=plx; plx=plx*math.cos(-rs)-ply*math.sin(-rs); ply=olx*math.sin(-rs)+ply*math.cos(-rs)
    end
    delay(1)
if isKeyDown(0x29) then return end
end
