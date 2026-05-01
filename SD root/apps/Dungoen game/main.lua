-- ============================================================
--  DUNGEON CRAWLER RPG - Single File
--  320x240 display, top-down dungeon, visual world map
-- ============================================================

-- ============================================================
--  CONSTANTS
-- ============================================================
local SW, SH = 320, 240
local TILE = 12       -- pixels per tile in dungeon view
local MAP_W, MAP_H = 16, 14

-- Colors
local C_BLACK   = 0x0000
local C_WHITE   = 0xFFFF
local C_RED     = 0xF800
local C_GREEN   = 0x07E0
local C_BLUE    = 0x001F
local C_YELLOW  = 0xFFE0
local C_GRAY    = 0x7BEF
local C_DGRAY   = 0x2104
local C_BROWN   = 0xC260
local C_GOLD    = 0xFEA0
local C_ORANGE  = 0xFD20
local C_CYAN    = 0x07FF
local C_PURPLE  = 0x801F
local C_DBLUE   = 0x0010
local C_WALL    = 0x4208
local C_FLOOR   = 0x18C3
local C_DFLOOR  = 0x1082

-- Tile types
local T_EMPTY  = 0
local T_WALL   = 1
local T_DOOR   = 2
local T_CHEST  = 3
local T_EXIT   = 4
local T_ENEMY  = 5

-- Game states
local STATE_WORLD   = "world"
local STATE_BASE    = "base"
local STATE_DUNGEON = "dungeon"
local STATE_COMBAT  = "combat"
local STATE_DEAD    = "dead"

-- ============================================================
--  PLAYER
-- ============================================================
local player = {
    x = 2, y = 2,
    hp = 30, maxHp = 30,
    atk = 5, def = 2, spd = 3,
    xp = 0, xpNext = 20,
    level = 1,
    gold = 50,
    weapon = {name="Dagger",  atk=3, icon="D"},
    armor  = {name="Cloth",   def=1, icon="C"},
    carry  = {},
    stash  = {},
}

-- ============================================================
--  WORLD MAP STATE
-- ============================================================
local world = {
    playerX = 5, playerY = 4,
    dungeons = {},
    baseX = 5, baseY = 4,
}
local CAM_OX, CAM_OY = 0, 0

-- ============================================================
--  DUNGEON STATE
-- ============================================================
local dungeon = {
    map = {},
    enemies = {},
    seed = 0,
    difficulty = 1,
    id = "",
    floor = 1,
    exitX = 0, exitY = 0,
    hasKey = false,
}

-- ============================================================
--  COMBAT STATE
-- ============================================================
local combat = {
    enemy = nil,
    log = {},
    turn = "player",
    animTimer = 0,
    playerShake = 0,
    enemyShake = 0,
    done = false,
    fled = false,
}
local combatCursor = 1

-- ============================================================
--  UI STATE
-- ============================================================
local gameState = STATE_WORLD
local baseTab   = 1
local shopCursor = 1
local msgTimer  = 0
local msgText   = ""
local msgColor  = 0xFFFF

local function showMsg(txt, col)
    msgText  = txt
    msgColor = col or 0xFFFF
    msgTimer = 90
end

-- ============================================================
--  KEY HANDLING
-- ============================================================
local keys     = {up=false,down=false,left=false,right=false,e=false,space=false,esc=false}
local lastKeys = {up=false,down=false,left=false,right=false,e=false,space=false,esc=false}

local function readKeys()
    for k,_ in pairs(keys) do lastKeys[k] = keys[k] end
    keys.up    = isKeyDown("w")
    keys.down  = isKeyDown("s")
    keys.left  = isKeyDown("a")
    keys.right = isKeyDown("d")
    keys.space = isKeyDown("space")
    keys.esc   = isKeyDown("esc")
    keys.e     = isKeyDown(0x08)
end

local function pressed(k) return keys[k] and not lastKeys[k] end

-- ============================================================
--  SAVE / LOAD
-- ============================================================
local function savePlayer()
    local s = player.hp..","..player.maxHp..","..player.atk..","..player.def..","
             ..player.spd..","..player.xp..","..player.xpNext..","..player.level..","
             ..player.gold..","..player.weapon.name..","..player.weapon.atk..","
             ..player.armor.name..","..player.armor.def
    flashWrite("player", s)
end

local function loadPlayer()
    if not flashExists("player") then return end
    local s = flashRead("player")
    local v = {}
    for x in s:gmatch("[^,]+") do table.insert(v, x) end
    player.hp         = tonumber(v[1])  or player.hp
    player.maxHp      = tonumber(v[2])  or player.maxHp
    player.atk        = tonumber(v[3])  or player.atk
    player.def        = tonumber(v[4])  or player.def
    player.spd        = tonumber(v[5])  or player.spd
    player.xp         = tonumber(v[6])  or player.xp
    player.xpNext     = tonumber(v[7])  or player.xpNext
    player.level      = tonumber(v[8])  or player.level
    player.gold       = tonumber(v[9])  or player.gold
    if v[10] then player.weapon.name = v[10] end
    if v[11] then player.weapon.atk  = tonumber(v[11]) or player.weapon.atk end
    if v[12] then player.armor.name  = v[12] end
    if v[13] then player.armor.def   = tonumber(v[13]) or player.armor.def end
end

local function serializeMap()
    local s = ""
    for x = 1, MAP_W do
        for y = 1, MAP_H do
            s = s .. dungeon.map[x][y]
        end
    end
    return s
end

local function deserializeMap(s)
    dungeon.map = {}
    local i = 1
    for x = 1, MAP_W do
        dungeon.map[x] = {}
        for y = 1, MAP_H do
            dungeon.map[x][y] = tonumber(s:sub(i,i)) or 0
            i = i + 1
        end
    end
end

local function saveDungeon(id)
    flashWrite("dmap_"..id, serializeMap())
    local es = ""
    for _, e in ipairs(dungeon.enemies) do
        es = es..math.floor(e.x)..","..math.floor(e.y)..","..e.hp..","
              ..(e.alive and "1" or "0")..";"
    end
    flashWrite("dene_"..id, es)
    flashWrite("dkey_"..id, dungeon.hasKey and "1" or "0")
end

local function loadDungeon(id)
    if not flashExists("dmap_"..id) then return false end
    deserializeMap(flashRead("dmap_"..id))
    dungeon.enemies = {}
    local es = flashRead("dene_"..id)
    for entry in es:gmatch("[^;]+") do
        local v = {}
        for x in entry:gmatch("[^,]+") do table.insert(v,x) end
        if #v == 4 then
            local hp = tonumber(v[3]) or 10
            table.insert(dungeon.enemies, {
                x=tonumber(v[1])+0.5, y=tonumber(v[2])+0.5,
                hp=hp, maxHp=hp, alive=v[4]=="1",
                name="Goblin", atk=3+dungeon.difficulty,
                def=1, xp=8, gold=5,
                icon="G", color=C_GREEN
            })
        end
    end
    dungeon.hasKey = flashRead("dkey_"..id) == "1"
    return true
end

local function saveWorld()
    local s = world.playerX..","..world.playerY..","..world.baseX..","..world.baseY
    for _, d in ipairs(world.dungeons) do
        s = s..";"..d.wx..","..d.wy..","..d.seed..","..d.difficulty..","
             ..d.name..",".. (d.visited and "1" or "0")
    end
    flashWrite("world", s)
end

local function loadWorld()
    if not flashExists("world") then return false end
    local s = flashRead("world")
    local parts = {}
    for p in s:gmatch("[^;]+") do table.insert(parts, p) end
    local b = {}
    for v in parts[1]:gmatch("[^,]+") do table.insert(b,v) end
    world.playerX = tonumber(b[1]) or world.playerX
    world.playerY = tonumber(b[2]) or world.playerY
    world.baseX   = tonumber(b[3]) or world.baseX
    world.baseY   = tonumber(b[4]) or world.baseY
    world.dungeons = {}
    for i = 2, #parts do
        local v = {}
        for x in parts[i]:gmatch("[^,]+") do table.insert(v,x) end
        if #v >= 6 then
            table.insert(world.dungeons, {
                wx=tonumber(v[1]), wy=tonumber(v[2]),
                seed=tonumber(v[3]), difficulty=tonumber(v[4]),
                name=v[5], visited=v[6]=="1"
            })
        end
    end
    return true
end

-- ============================================================
--  DATA TABLES
-- ============================================================
local ENEMY_TYPES = {
    {name="Goblin",   hp=10, atk=3, def=0, xp=8,  gold=4,  icon="G", color=C_GREEN},
    {name="Orc",      hp=20, atk=6, def=2, xp=15, gold=8,  icon="O", color=C_RED},
    {name="Skeleton", hp=14, atk=4, def=3, xp=12, gold=6,  icon="S", color=C_GRAY},
    {name="Troll",    hp=35, atk=9, def=4, xp=25, gold=15, icon="T", color=C_ORANGE},
}

local LOOT_TABLE = {
    {name="Herb",       gold=5,  heal=8},
    {name="Iron Ore",   gold=12, heal=0},
    {name="Magic Dust", gold=20, heal=0},
    {name="Old Coin",   gold=3,  heal=0},
    {name="Gem",        gold=30, heal=0},
    {name="Potion",     gold=15, heal=20},
}

local SHOP_WEAPONS = {
    {name="Dagger",    atk=3,  price=0,   icon="D"},
    {name="Sword",     atk=7,  price=80,  icon="S"},
    {name="Axe",       atk=11, price=150, icon="A"},
    {name="Spear",     atk=14, price=220, icon="P"},
    {name="Greatsword",atk=18, price=350, icon="G"},
}
local SHOP_ARMORS = {
    {name="Cloth",     def=1,  price=0,   icon="C"},
    {name="Leather",   def=3,  price=60,  icon="L"},
    {name="Chainmail", def=6,  price=140, icon="M"},
    {name="Plate",     def=10, price=280, icon="P"},
}

-- ============================================================
--  MAP GENERATION
-- ============================================================
local function generateDungeonMap(seed, diff)
    math.randomseed(seed)
    dungeon.map = {}
    for x = 1, MAP_W do
        dungeon.map[x] = {}
        for y = 1, MAP_H do
            if x==1 or x==MAP_W or y==1 or y==MAP_H then
                dungeon.map[x][y] = T_WALL
            elseif math.random() > 0.78 then
                dungeon.map[x][y] = T_WALL
            else
                dungeon.map[x][y] = T_EMPTY
            end
        end
    end
    for i=2,4 do for j=2,4 do dungeon.map[i][j]=T_EMPTY end end

    -- Exit
    local ex, ey, attempts = MAP_W-2, 2, 0
    while dungeon.map[ex][ey] ~= T_EMPTY and attempts < 100 do
        ex = math.random(MAP_W-3, MAP_W-2)
        ey = math.random(2, MAP_H-2)
        attempts = attempts + 1
    end
    dungeon.map[ex][ey] = T_EXIT
    dungeon.exitX, dungeon.exitY = ex, ey

    -- Chests
    local chests = 1 + math.floor(diff/2)
    for c = 1, chests do
        attempts = 0
        repeat
            local cx=math.random(2,MAP_W-1); local cy=math.random(2,MAP_H-1)
            if dungeon.map[cx][cy]==T_EMPTY and (cx>4 or cy>4) then
                dungeon.map[cx][cy]=T_CHEST; break
            end
            attempts = attempts + 1
        until attempts > 80
    end

    -- Enemies
    dungeon.enemies = {}
    local eCount = 2 + diff + math.random(0,2)
    local spawned = 0
    attempts = 0
    while spawned < eCount and attempts < 300 do
        local ex2=math.random(2,MAP_W-1); local ey2=math.random(2,MAP_H-1)
        if dungeon.map[ex2][ey2]==T_EMPTY and (ex2>4 or ey2>4) then
            local ei = math.min(diff, #ENEMY_TYPES)
            if math.random() < 0.4 then ei = math.max(1, math.floor(diff/2)) end
            local et = ENEMY_TYPES[ei]
            table.insert(dungeon.enemies, {
                x=ex2, y=ey2, alive=true,
                hp=et.hp+diff*2, maxHp=et.hp+diff*2,
                atk=et.atk+diff, def=et.def,
                xp=et.xp+diff*2, gold=et.gold+diff,
                name=et.name, icon=et.icon, color=et.color
            })
            spawned = spawned + 1
        end
        attempts = attempts + 1
    end

    dungeon.hasKey = false
end

local function generateWorldDungeons()
    math.randomseed(12345)
    world.dungeons = {}
    local names = {"Crypt","Cave","Tomb","Ruins","Lair","Vault","Keep","Pit"}
    for i = 1, 8 do
        local wx, wy, tries = 0, 0, 0
        repeat
            wx = math.random(1,19); wy = math.random(1,14)
            tries = tries + 1
        until (wx~=world.baseX or wy~=world.baseY) and tries < 100
        local dist = math.sqrt((wx-world.baseX)^2+(wy-world.baseY)^2)
        table.insert(world.dungeons, {
            wx=wx, wy=wy,
            seed=math.random(1000,9999),
            difficulty=math.max(1,math.floor(dist/3)),
            name=names[i],
            visited=false
        })
    end
end

-- ============================================================
--  DRAWING - WORLD MAP
-- ============================================================
local WTS = 15

local function drawWorldMap()
    fillRect(0, 0, SW, SH, 0x0210)

    local cols = math.floor(SW/WTS)+1
    local rows = math.floor((SH-20)/WTS)+1
    for gx = 0, cols do
        for gy = 0, rows do
            local wx2 = gx + CAM_OX
            local wy2 = gy + CAM_OY
            local px2 = gx*WTS
            local py2 = gy*WTS + 20
            math.randomseed(wx2*137+wy2*31)
            local r = math.random()
            local col
            if     r < 0.12 then col = 0x0318
            elseif r < 0.30 then col = 0x02A0
            else                  col = 0x0A80
            end
            fillRect(px2, py2, WTS, WTS, col)
            rect(px2, py2, WTS, WTS, 0x0140)
        end
    end

    -- Dungeons
    for _, d in ipairs(world.dungeons) do
        local sx = (d.wx-CAM_OX)*WTS
        local sy = (d.wy-CAM_OY)*WTS+20
        if sx>=0 and sx<SW and sy>=20 and sy<SH then
            fillRect(sx+2, sy+2, WTS-4, WTS-4, d.visited and C_DGRAY or C_PURPLE)
            printAt(sx+4, sy+3, "D", C_WHITE)
        end
    end

    -- Base
    local bsx = (world.baseX-CAM_OX)*WTS
    local bsy = (world.baseY-CAM_OY)*WTS+20
    fillRect(bsx+1, bsy+1, WTS-2, WTS-2, C_GOLD)
    printAt(bsx+4, bsy+3, "B", C_BLACK)

    -- Player
    local psx = (world.playerX-CAM_OX)*WTS
    local psy = (world.playerY-CAM_OY)*WTS+20
    fillRect(psx+3, psy+3, WTS-6, WTS-6, C_WHITE)
    printAt(psx+5, psy+3, "@", C_BLACK)

    -- Top bar
    fillRect(0, 0, SW, 18, C_DGRAY)
    printAt(4,   4, "WORLD MAP", C_GOLD)
    printAt(140, 4, "HP:"..player.hp.."/"..player.maxHp, C_RED)
    printAt(220, 4, "G:"..player.gold, C_GOLD)
    printAt(270, 4, "Lv."..player.level, C_CYAN)

    -- Bottom hint
    fillRect(0, SH-14, SW, 14, C_DGRAY)
    local hint = "WASD:Move  E:Enter"
    if world.playerX==world.baseX and world.playerY==world.baseY then
        hint = "E: Enter Base"
    else
        for _, d in ipairs(world.dungeons) do
            if d.wx==world.playerX and d.wy==world.playerY then
                hint = "E: Enter "..d.name.." (Diff "..d.difficulty..")"
                break
            end
        end
    end
    printAt(4, SH-11, hint, C_GRAY)

    if msgTimer > 0 then
        fillRect(60, 105, 200, 18, C_BLACK)
        printAt(66, 109, msgText, msgColor)
        msgTimer = msgTimer - 1
    end
end

-- ============================================================
--  DRAWING - DUNGEON
-- ============================================================
local DMAP_OX = 4
local DMAP_OY = 20

local function dungeonToScreen(tx, ty)
    return DMAP_OX+(tx-1)*TILE, DMAP_OY+(ty-1)*TILE
end

local TILE_COL = {
    [T_EMPTY]=C_FLOOR, [T_WALL]=C_WALL,
    [T_DOOR]=C_BROWN,  [T_CHEST]=C_GOLD,
    [T_EXIT]=C_CYAN,
}

local function drawDungeon()
    fillRect(0, 0, SW, SH, C_BLACK)

    for x = 1, MAP_W do
        for y = 1, MAP_H do
            local t = dungeon.map[x][y]
            local sx, sy = dungeonToScreen(x, y)
            local col = TILE_COL[t] or C_DFLOOR
            fillRect(sx, sy, TILE, TILE, col)
            if t==T_WALL then
                fillRect(sx, sy, TILE, 2, 0x630C)
            elseif t==T_CHEST then
                printAt(sx+3, sy+2, "C", C_BLACK)
            elseif t==T_EXIT then
                local ec = dungeon.hasKey and C_GREEN or C_CYAN
                fillRect(sx, sy, TILE, TILE, ec)
                printAt(sx+3, sy+2, "X", C_BLACK)
            end
        end
    end

    -- Enemies
    for _, e in ipairs(dungeon.enemies) do
        if e.alive then
            local sx, sy = dungeonToScreen(e.x, e.y)
            fillRect(sx+1, sy+1, TILE-2, TILE-2, e.color)
            printAt(sx+3, sy+2, e.icon, C_BLACK)
            local hpw = math.floor((e.hp/e.maxHp)*(TILE-2))
            fillRect(sx+1, sy+TILE-3, TILE-2, 2, C_RED)
            fillRect(sx+1, sy+TILE-3, hpw,    2, C_GREEN)
        end
    end

    -- Player
    local ppx, ppy = dungeonToScreen(player.x, player.y)
    fillRect(ppx+1, ppy+1, TILE-2, TILE-2, C_WHITE)
    printAt(ppx+3, ppy+2, "@", C_BLACK)

    -- Side panel
    local PX = DMAP_OX + MAP_W*TILE + 6
    fillRect(PX-4, 0, SW-PX+4, SH, C_DGRAY)

    printAt(PX, 4,  "HP", C_RED)
    local hpw2 = math.floor((player.hp/player.maxHp)*52)
    fillRect(PX, 14, 52, 6, C_RED)
    fillRect(PX, 14, hpw2, 6, C_GREEN)
    printAt(PX, 23, player.hp.."/"..player.maxHp, C_WHITE)

    printAt(PX, 36, "LV:"..player.level, C_GOLD)
    printAt(PX, 47, "XP:"..player.xp,    C_CYAN)
    printAt(PX, 58, "AT:"..(player.atk+player.weapon.atk), C_ORANGE)
    printAt(PX, 69, "DF:"..(player.def+player.armor.def),  C_BLUE)
    printAt(PX, 80, "G:"..player.gold,   C_GOLD)

    printAt(PX, 96,  player.weapon.icon..":"..player.weapon.name, C_GRAY)
    printAt(PX, 107, player.armor.icon..":"..player.armor.name,   C_GRAY)

    if dungeon.hasKey then
        printAt(PX, 122, "KEY!", C_GOLD)
    end
    printAt(PX, 136, "Bag:"..#player.carry, C_WHITE)
    printAt(PX, 150, "Fl."..dungeon.floor,  C_GRAY)

    -- Top bar
    fillRect(0, 0, DMAP_OX+MAP_W*TILE, 18, C_DGRAY)
    printAt(4, 4, dungeon.id.." Fl."..dungeon.floor.." D"..dungeon.difficulty, C_WHITE)

    -- Bottom bar
    fillRect(0, SH-12, DMAP_OX+MAP_W*TILE, 12, C_DGRAY)
    printAt(4, SH-10, "WASD:Move  ESC:Leave", C_GRAY)

    if msgTimer > 0 then
        fillRect(4, SH-26, 190, 12, C_BLACK)
        printAt(6, SH-24, msgText, msgColor)
        msgTimer = msgTimer - 1
    end
end

-- ============================================================
--  DRAWING - COMBAT
-- ============================================================
local function addLog(txt, col)
    table.insert(combat.log, {t=txt, c=col or C_WHITE})
    if #combat.log > 5 then table.remove(combat.log, 1) end
end

local function drawCombat()
    fillRect(0, 0, SW, SH, C_BLACK)
    local e = combat.enemy

    -- Enemy box
    local esx = (combat.enemyShake>0) and math.random(-2,2) or 0
    fillRect(20+esx, 18, 130, 108, C_DGRAY)
    rect(20+esx, 18, 130, 108, e.color)
    printAt(26+esx, 22, e.name, C_WHITE)
    setTextSize(4)
    printAt(55+esx, 44, e.icon, e.color)
    setTextSize(1)
    local ehw = math.floor((e.hp/e.maxHp)*110)
    fillRect(26+esx, 118, 110, 5, C_RED)
    fillRect(26+esx, 118, ehw,  5, C_GREEN)
    printAt(26+esx, 126, "HP:"..e.hp.."/"..e.maxHp, C_WHITE)

    -- Player box
    local psx = (combat.playerShake>0) and math.random(-2,2) or 0
    fillRect(170+psx, 18, 130, 108, C_DGRAY)
    rect(170+psx, 18, 130, 108, C_BLUE)
    printAt(176+psx, 22, "You Lv."..player.level, C_WHITE)
    setTextSize(4)
    printAt(205+psx, 44, "@", C_WHITE)
    setTextSize(1)
    local phw = math.floor((player.hp/player.maxHp)*110)
    fillRect(176+psx, 118, 110, 5, C_RED)
    fillRect(176+psx, 118, phw,  5, C_GREEN)
    printAt(176+psx, 126, "HP:"..player.hp.."/"..player.maxHp, C_WHITE)

    -- Turn arrow
    if combat.turn=="player" then
        printAt(152, 62, ">", C_YELLOW)
    else
        printAt(155, 62, "<", C_ORANGE)
        if combat.animTimer>0 then
            fillRect(20, 232, math.floor(combat.animTimer*3.2), 5, C_ORANGE)
        end
    end

    -- Action menu
    fillRect(20, 140, 130, 44, C_DGRAY)
    rect(20, 140, 130, 44, C_GRAY)
    printAt(30, 150, (combatCursor==1 and ">" or " ").."ATTACK", combatCursor==1 and C_YELLOW or C_WHITE)
    printAt(30, 164, (combatCursor==2 and ">" or " ").."FLEE",   combatCursor==2 and C_YELLOW or C_WHITE)
    printAt(20, 188, "ATK:"..(player.atk+player.weapon.atk), C_ORANGE)
    printAt(80, 188, "DEF:"..(player.def+player.armor.def),  C_BLUE)

    -- Log panel
    fillRect(160, 140, 155, 96, C_DGRAY)
    rect(160, 140, 155, 96, C_GRAY)
    printAt(164, 142, "-- BATTLE LOG --", C_GRAY)
    for i, entry in ipairs(combat.log) do
        printAt(164, 142+i*13, entry.t, entry.c)
    end

    if combat.done then
        fillRect(80, 105, 160, 22, C_BLACK)
        rect(80, 105, 160, 22, C_GOLD)
        local txt = player.hp<=0 and "DEFEATED! SPACE:ok" or "Victory! SPACE:ok"
        printAt(86, 112, txt, C_GOLD)
    end

    if combat.playerShake>0 then combat.playerShake=combat.playerShake-1 end
    if combat.enemyShake>0  then combat.enemyShake=combat.enemyShake-1   end
end

-- ============================================================
--  DRAWING - BASE
-- ============================================================
local BASE_TABS = {"SHOP","SMITH","INN","STASH"}

local function drawBase()
    fillRect(0, 0, SW, SH, 0x0820)
    fillRect(0, 0, SW, 18, C_DGRAY)
    printAt(4, 4, "=== BASE CAMP ===", C_GOLD)
    printAt(210, 4, "Gold:"..player.gold, C_GOLD)

    for i, t in ipairs(BASE_TABS) do
        local tx2 = (i-1)*80
        fillRect(tx2, 18, 80, 16, baseTab==i and C_GOLD or C_DGRAY)
        rect(tx2, 18, 80, 16, C_GRAY)
        printAt(tx2+10, 22, t, baseTab==i and C_BLACK or C_WHITE)
    end

    local Y = 40

    if baseTab == 1 then
        printAt(4, Y, "WEAPONS:", C_ORANGE)
        for i, w in ipairs(SHOP_WEAPONS) do
            local col = shopCursor==i and C_YELLOW or C_WHITE
            local eq  = player.weapon.name==w.name and " [EQ]" or ""
            printAt(8, Y+12+i*13,
                (shopCursor==i and ">" or " ")..w.name.." ATK+"..w.atk.." "..w.price.."g"..eq, col)
        end
        printAt(4, Y+84, "ARMORS:", C_BLUE)
        for i, a in ipairs(SHOP_ARMORS) do
            local idx = i+#SHOP_WEAPONS
            local col = shopCursor==idx and C_YELLOW or C_WHITE
            local eq  = player.armor.name==a.name and " [EQ]" or ""
            printAt(8, Y+96+i*13,
                (shopCursor==idx and ">" or " ")..a.name.." DEF+"..a.def.." "..a.price.."g"..eq, col)
        end
        printAt(4, SH-22, "E:Buy/Equip  W/S:Navigate", C_GRAY)

    elseif baseTab == 2 then
        printAt(4, Y,    "BLACKSMITH", C_ORANGE)
        printAt(4, Y+16, "Weapon: "..player.weapon.name.." (ATK+"..player.weapon.atk..")", C_WHITE)
        local wc = 50+player.weapon.atk*20
        printAt(4, Y+30, "Upgrade +2 ATK = "..wc.."g", shopCursor==1 and C_YELLOW or C_CYAN)
        fillRect(0, Y+26, 3, 16, shopCursor==1 and C_GOLD or C_BLACK)
        printAt(4, Y+60, "Armor: "..player.armor.name.." (DEF+"..player.armor.def..")", C_WHITE)
        local ac = 40+player.armor.def*15
        printAt(4, Y+74, "Upgrade +1 DEF = "..ac.."g", shopCursor==2 and C_YELLOW or C_CYAN)
        fillRect(0, Y+70, 3, 16, shopCursor==2 and C_GOLD or C_BLACK)
        printAt(4, SH-22, "W/S:Select  E:Upgrade", C_GRAY)

    elseif baseTab == 3 then
        printAt(4, Y,    "INN", C_CYAN)
        printAt(4, Y+16, "HP: "..player.hp.."/"..player.maxHp, C_WHITE)
        local hc = math.max(5,(player.maxHp-player.hp)*2)
        printAt(4, Y+32, "Full heal cost: "..hc.."g", C_GOLD)
        printAt(4, Y+50, "E: Rest (full heal)", C_WHITE)
        printAt(4, Y+76, "XP: "..player.xp.."/"..player.xpNext, C_CYAN)
        if player.xp >= player.xpNext then
            printAt(4, Y+92, "SPACE: LEVEL UP!", C_YELLOW)
        end
        printAt(4, SH-22, "E:Rest  SPACE:LvlUp", C_GRAY)

    elseif baseTab == 4 then
        printAt(4, Y, "STASH ("..#player.stash.." items)", C_CYAN)
        if #player.stash==0 then
            printAt(4, Y+20, "Stash is empty.", C_GRAY)
        else
            for i, item in ipairs(player.stash) do
                local col = shopCursor==i and C_YELLOW or C_WHITE
                printAt(8, Y+12+i*13,
                    (shopCursor==i and ">" or " ")..item.name.." ("..item.gold.."g)", col)
            end
        end
        printAt(4, SH-22, "E:Sell  W/S:Navigate", C_GRAY)
    end

    -- Stats strip
    fillRect(0, SH-36, SW, 14, C_DGRAY)
    printAt(4,   SH-34, "HP:"..player.hp.."/"..player.maxHp, C_RED)
    printAt(90,  SH-34, "ATK:"..(player.atk+player.weapon.atk), C_ORANGE)
    printAt(160, SH-34, "DEF:"..(player.def+player.armor.def),  C_BLUE)
    printAt(230, SH-34, "LV:"..player.level, C_GOLD)
    printAt(4, SH-20, "A/D:Tab  ESC:Back to map", C_GRAY)

    if msgTimer>0 then
        fillRect(60, 108, 200, 18, C_BLACK)
        printAt(66, 113, msgText, msgColor)
        msgTimer = msgTimer-1
    end
end

-- ============================================================
--  DRAWING - DEAD
-- ============================================================
local function drawDead()
    fillRect(0, 0, SW, SH, C_BLACK)
    setTextSize(2)
    printAt(95, 80, "YOU DIED", C_RED)
    setTextSize(1)
    printAt(68, 114, "Carried loot was lost.", C_GRAY)
    printAt(68, 128, "Gold and stash are safe.", C_WHITE)
    printAt(82, 158, "SPACE: Respawn at base", C_YELLOW)
end

-- ============================================================
--  LEVEL UP
-- ============================================================
local function doLevelUp()
    player.level   = player.level+1
    player.xp      = player.xp - player.xpNext
    player.xpNext  = math.floor(player.xpNext*1.4)
    player.maxHp   = player.maxHp+8
    player.hp      = player.maxHp
    player.atk     = player.atk+2
    player.def     = player.def+1
    player.spd     = player.spd+1
    showMsg("LEVEL UP! Now Lv."..player.level, C_GOLD)
    playSound(600,100)
end

-- ============================================================
--  COMBAT LOGIC
-- ============================================================
local function startCombat(enemy)
    combat.enemy       = enemy
    combat.log         = {}
    combat.turn        = "player"
    combat.animTimer   = 0
    combat.playerShake = 0
    combat.enemyShake  = 0
    combat.done        = false
    combat.fled        = false
    combatCursor       = 1
    addLog("A "..enemy.name.." appears!", C_ORANGE)
    gameState = STATE_COMBAT
end

local function playerAttack()
    local dmg = math.max(1,(player.atk+player.weapon.atk)-combat.enemy.def+math.random(-1,2))
    combat.enemy.hp   = combat.enemy.hp - dmg
    combat.enemyShake = 6
    addLog("You hit for "..dmg, C_YELLOW)
    playSound(300,30)
    if combat.enemy.hp <= 0 then
        combat.enemy.alive = false
        combat.enemy.hp    = 0
        addLog(combat.enemy.name.." fell!", C_GREEN)
        local g = combat.enemy.gold + math.random(0,3)
        player.xp   = player.xp + combat.enemy.xp
        player.gold = player.gold + g
        addLog("+"..combat.enemy.xp.."xp +"..g.."g", C_GOLD)
        if math.random() < 0.55 then
            local loot = LOOT_TABLE[math.random(#LOOT_TABLE)]
            table.insert(player.carry, loot)
            addLog("Loot: "..loot.name, C_CYAN)
        end
        if player.xp >= player.xpNext then doLevelUp() end
        playSound(500,80)
        combat.done = true
    else
        combat.turn      = "enemy"
        combat.animTimer = 40
    end
end

local function enemyAttack()
    local e   = combat.enemy
    local dmg = math.max(1, e.atk-(player.def+player.armor.def)+math.random(-1,2))
    player.hp          = player.hp - dmg
    combat.playerShake = 6
    addLog(e.name.." hits for "..dmg, C_RED)
    playSound(150,40)
    if player.hp <= 0 then
        player.hp   = 0
        player.carry = {}
        addLog("You were slain!", C_RED)
        combat.done = true
    else
        combat.turn = "player"
    end
end

local function updateCombat()
    if combat.done then
        if pressed("space") or pressed("e") then
            if player.hp <= 0 then
                gameState = STATE_DEAD
            else
                gameState = STATE_DUNGEON
            end
        end
        return
    end

    if combat.turn == "player" then
        if pressed("up") or pressed("down") then
            combatCursor = combatCursor==1 and 2 or 1
            playSound(200,10)
        end
        if pressed("e") or pressed("space") then
            if combatCursor == 1 then
                playerAttack()
            else
                local chance = 0.35 + player.spd*0.05
                if math.random() < chance then
                    addLog("You fled!", C_CYAN)
                    combat.fled = true
                    combat.done = true
                else
                    addLog("Can't flee!", C_RED)
                    combat.turn      = "enemy"
                    combat.animTimer = 40
                end
            end
        end
    else
        combat.animTimer = combat.animTimer - 1
        if combat.animTimer <= 0 then
            enemyAttack()
        end
    end
end

-- ============================================================
--  DUNGEON LOGIC
-- ============================================================
local moveTimer = 0

local function updateDungeon()
    moveTimer = moveTimer - 1
    local dx, dy = 0, 0
    if pressed("up")    then dy=-1 end
    if pressed("down")  then dy= 1 end
    if pressed("left")  then dx=-1 end
    if pressed("right") then dx= 1 end

    if (dx~=0 or dy~=0) and moveTimer<=0 then
        moveTimer = 8
        local nx, ny = player.x+dx, player.y+dy
        if nx>=1 and nx<=MAP_W and ny>=1 and ny<=MAP_H then
            local t = dungeon.map[nx][ny]

            if t==T_EMPTY then
                -- Check enemy at target
                local hit = false
                for _, e in ipairs(dungeon.enemies) do
                    if e.alive and e.x==nx and e.y==ny then
                        startCombat(e); hit=true; break
                    end
                end
                if not hit then player.x, player.y = nx, ny end

            elseif t==T_EXIT then
                if dungeon.hasKey then
                    showMsg("Next floor!", C_CYAN)
                    saveDungeon(dungeon.id)
                    dungeon.floor      = dungeon.floor+1
                    dungeon.difficulty = dungeon.difficulty+1
                    generateDungeonMap(dungeon.seed+dungeon.floor*7, dungeon.difficulty)
                    player.x, player.y = 2, 2
                    playSound(600,80)
                else
                    showMsg("Need a KEY to exit!", C_RED)
                    playSound(100,20)
                end

            elseif t==T_CHEST then
                if not dungeon.hasKey and math.random()<0.35 then
                    dungeon.hasKey = true
                    showMsg("Found the KEY!", C_GOLD)
                    playSound(500,60)
                else
                    local loot = LOOT_TABLE[math.random(#LOOT_TABLE)]
                    table.insert(player.carry, loot)
                    showMsg("Got: "..loot.name, C_CYAN)
                    playSound(400,40)
                end
                dungeon.map[nx][ny] = T_EMPTY
                player.x, player.y = nx, ny
            end
        end
    end

    if pressed("esc") then
        saveDungeon(dungeon.id)
        for _, item in ipairs(player.carry) do
            table.insert(player.stash, item)
        end
        player.carry = {}
        savePlayer()
        saveWorld()
        gameState = STATE_WORLD
        showMsg("Progress saved.", C_GRAY)
    end

    collectgarbage("step", 10)
end

-- ============================================================
--  WORLD MAP LOGIC
-- ============================================================
local worldMoveTimer = 0

local function updateWorld()
    worldMoveTimer = worldMoveTimer - 1
    local dx, dy = 0, 0
    if pressed("up")    then dy=-1 end
    if pressed("down")  then dy= 1 end
    if pressed("left")  then dx=-1 end
    if pressed("right") then dx= 1 end

    if (dx~=0 or dy~=0) and worldMoveTimer<=0 then
        worldMoveTimer = 10
        world.playerX = math.max(1,math.min(19,world.playerX+dx))
        world.playerY = math.max(1,math.min(14,world.playerY+dy))
        -- Scroll camera
        local cols = math.floor(SW/WTS)-2
        local rows = math.floor((SH-20)/WTS)-2
        if world.playerX-CAM_OX > cols then CAM_OX=CAM_OX+1
        elseif world.playerX-CAM_OX < 2 then CAM_OX=math.max(0,CAM_OX-1) end
        if world.playerY-CAM_OY > rows then CAM_OY=CAM_OY+1
        elseif world.playerY-CAM_OY < 2 then CAM_OY=math.max(0,CAM_OY-1) end
        playSound(100,5)
    end

    if pressed("e") then
        if world.playerX==world.baseX and world.playerY==world.baseY then
            gameState  = STATE_BASE
            shopCursor = 1
            baseTab    = 1
        else
            for _, d in ipairs(world.dungeons) do
                if d.wx==world.playerX and d.wy==world.playerY then
                    dungeon.seed       = d.seed
                    dungeon.difficulty = d.difficulty
                    dungeon.id         = d.wx.."_"..d.wy
                    dungeon.floor      = 1
                    player.x, player.y = 2, 2
                    if not loadDungeon(dungeon.id) then
                        generateDungeonMap(dungeon.seed, dungeon.difficulty)
                    end
                    d.visited = true
                    saveWorld()
                    gameState = STATE_DUNGEON
                    showMsg("Entering "..d.name.."!", C_PURPLE)
                    break
                end
            end
        end
    end
end

-- ============================================================
--  BASE LOGIC
-- ============================================================
local function updateBase()
    if pressed("left")  then baseTab=math.max(1,baseTab-1); shopCursor=1; playSound(200,10) end
    if pressed("right") then baseTab=math.min(4,baseTab+1); shopCursor=1; playSound(200,10) end

    if baseTab==1 then
        local maxC = #SHOP_WEAPONS+#SHOP_ARMORS
        if pressed("up")   then shopCursor=math.max(1,shopCursor-1) end
        if pressed("down") then shopCursor=math.min(maxC,shopCursor+1) end
        if pressed("e") then
            if shopCursor<=#SHOP_WEAPONS then
                local w=SHOP_WEAPONS[shopCursor]
                if player.gold>=w.price then
                    player.gold=player.gold-w.price
                    player.weapon={name=w.name,atk=w.atk,icon=w.icon}
                    showMsg("Equipped "..w.name,C_GREEN); playSound(400,40); savePlayer()
                else showMsg("Not enough gold!",C_RED); playSound(100,20) end
            else
                local a=SHOP_ARMORS[shopCursor-#SHOP_WEAPONS]
                if player.gold>=a.price then
                    player.gold=player.gold-a.price
                    player.armor={name=a.name,def=a.def,icon=a.icon}
                    showMsg("Equipped "..a.name,C_GREEN); playSound(400,40); savePlayer()
                else showMsg("Not enough gold!",C_RED); playSound(100,20) end
            end
        end

    elseif baseTab==2 then
        if pressed("up")   then shopCursor=math.max(1,shopCursor-1) end
        if pressed("down") then shopCursor=math.min(2,shopCursor+1) end
        if pressed("e") then
            if shopCursor==1 then
                local c=50+player.weapon.atk*20
                if player.gold>=c then player.gold=player.gold-c; player.weapon.atk=player.weapon.atk+2
                    showMsg("Weapon upgraded!",C_GOLD); playSound(500,60); savePlayer()
                else showMsg("Not enough gold!",C_RED) end
            else
                local c=40+player.armor.def*15
                if player.gold>=c then player.gold=player.gold-c; player.armor.def=player.armor.def+1
                    showMsg("Armor upgraded!",C_GOLD); playSound(500,60); savePlayer()
                else showMsg("Not enough gold!",C_RED) end
            end
        end

    elseif baseTab==3 then
        if pressed("e") then
            local c=math.max(5,(player.maxHp-player.hp)*2)
            if player.hp==player.maxHp then showMsg("Already full HP!",C_GRAY)
            elseif player.gold>=c then
                player.gold=player.gold-c; player.hp=player.maxHp
                showMsg("Fully healed!",C_GREEN); playSound(400,80); savePlayer()
            else showMsg("Not enough gold!",C_RED) end
        end
        if pressed("space") and player.xp>=player.xpNext then
            doLevelUp(); savePlayer()
        end

    elseif baseTab==4 then
        if pressed("up")   then shopCursor=math.max(1,shopCursor-1) end
        if pressed("down") then shopCursor=math.min(math.max(1,#player.stash),shopCursor+1) end
        if pressed("e") and #player.stash>0 then
            local item=player.stash[shopCursor]
            player.gold=player.gold+item.gold
            table.remove(player.stash,shopCursor)
            shopCursor=math.max(1,shopCursor-1)
            showMsg("Sold for "..item.gold.."g!",C_GOLD); playSound(300,30); savePlayer()
        end
    end

    if pressed("esc") then
        saveWorld(); gameState=STATE_WORLD
    end
end

-- ============================================================
--  DEAD LOGIC
-- ============================================================
local function updateDead()
    if pressed("space") then
        player.hp        = player.maxHp
        player.x, player.y = 2, 2
        world.playerX    = world.baseX
        world.playerY    = world.baseY
        gameState        = STATE_WORLD
        showMsg("Respawned at base.",C_WHITE)
    end
end

-- ============================================================
--  INIT
-- ============================================================
math.randomseed(42)
if not loadWorld() then
    generateWorldDungeons()
    saveWorld()
end
loadPlayer()
collectgarbage("collect")

-- ============================================================
--  MAIN LOOP
-- ============================================================
while true do
    readKeys()

    if     gameState==STATE_WORLD   then updateWorld();   drawWorldMap()
    elseif gameState==STATE_DUNGEON then updateDungeon(); drawDungeon()
    elseif gameState==STATE_COMBAT  then updateCombat();  drawCombat()
    elseif gameState==STATE_BASE    then updateBase();    drawBase()
    elseif gameState==STATE_DEAD    then updateDead();    drawDead()
    end

    collectgarbage("step", 10)
    delay(16)
end