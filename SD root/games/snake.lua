-- SNAKE.lua (CYD VERSION)
setTextSize(2)
local CELL = 16
-- Screen is 320x240, so 20x15 cells
local snake = {{x=10, y=7}, {x=9, y=7}, {x=8, y=7}}
local dx, dy = 1, 0
local fx, fy = math.random(0, 19), math.random(0, 14)
local score, canTurn, gameOver = 0, true, false

cls(0)

while not gameOver do
    if canTurn then
        if isKeyDown(0x1A) and dy == 0 then dx, dy = 0, -1 canTurn = false
        elseif isKeyDown(0x16) and dy == 0 then dx, dy = 0, 1 canTurn = false
        elseif isKeyDown(0x04) and dx == 0 then dx, dy = -1, 0 canTurn = false
        elseif isKeyDown(0x07) and dx == 0 then dx, dy = 1, 0 canTurn = false
        end
    end

    local head = {x = snake[1].x + dx, y = snake[1].y + dy}

    if head.x < 0 or head.x >= 20 or head.y < 0 or head.y >= 15 then 
        gameOver = true 
    else
        for i, v in ipairs(snake) do
            if head.x == v.x and head.y == v.y then gameOver = true break end
        end
    end

    if not gameOver then
        local tail = snake[#snake]
        fillRect(tail.x * CELL, tail.y * CELL, CELL - 1, CELL - 1, 0)
        table.insert(snake, 1, head)

        if head.x == fx and head.y == fy then
            score = score + 10
            playSound(1500, 20)
            fx, fy = math.random(0, 19), math.random(0, 14)
        else
            table.remove(snake)
        end

        fillRect(head.x * CELL, head.y * CELL, CELL - 1, CELL - 1, 0xFFFF)
        if #snake > 1 then
            fillRect(snake[2].x * CELL, snake[2].y * CELL, CELL - 1, CELL - 1, 0x07E0)
        end
        fillRect(fx * CELL, fy * CELL, CELL - 1, CELL - 1, 0xF800)

        fillRect(5, 225, 100, 12, 0) 
        setTextSize(1)
        printAt(5, 230, "SCORE: " .. score, 0xFFFF)
        canTurn = true
    end
    if isKeyDown(0x29) then break end
    delay(120)
end