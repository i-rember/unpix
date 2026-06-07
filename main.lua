local COLORS = {
    {0.921568, 1.000000, 0.976471, 1}, -- white
    {0.000000, 0.074510, 0.203922, 1}, -- black
    {0.976471, 0.011765, 0.023529, 1}, -- red
    {0.192157, 0.407843, 0.717647, 1}, -- blue
    {0.419608, 0.839216, 0.188235, 1}, -- green
    {0.988235, 0.972549, 0.372549, 1}, -- yellow
    {0.796078, 0.435294, 0.858824, 1}, -- purple
    {0.992157, 0.674510, 0.156863, 1}, -- orange
}

-- helpers
function getSprite(image, w, h, x, y)
    return love.graphics.newQuad(
        x * w,
        y * h,
        w,
        h,
        image:getDimensions()
    )
end

function insideRect(x, y, rx, ry, rw, rh)
    return x >= rx
    and y >= ry
    and x <= rx + rw
    and y <= ry + rh
end

function divmod(a, b)
    return math.floor(a / b), a % b
end

function sign(n)
    if n > 0 then return 1 end
    if n < 0 then return -1 end
    return 0
end

function canvas_clone(canvas)
    w, h = canvas:getDimensions()
    local copy = love.graphics.newCanvas(w, h) 
    love.graphics.setCanvas(copy)
    love.graphics.draw(canvas)
    love.graphics.setCanvas()
    return copy
end

function lerp(a, b, t)
    return a - t * a + t * b
end

function contains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end



local last_mx, last_my = nil, nil

local mouse_click = -2 -- =-1 if just released, <-1 if not pressed, =1 if just pressed, >1 if held
local draw = -2 -- above, for image

local color_selected = 0 -- the selected color on the wheel
local color_tween = 0 -- the actual rotation of the color wheel
local tool_selected = -1 -- which tool is currently selected
local tool_hover = -1 -- which tool is being hovered over
local tool_clicked = -1 -- which tool is being clicked on
local bigtool_offset = 0 -- how far downward the big tool is moved

local assets -- the loaded assets
local image -- the current image
local scribble_def -- blank image
local scribble -- the marks made by the current tool

function love.wheelmoved(x, y)
    if y > 0 then
        color_selected = color_selected - 1
    elseif y < 0 then
        color_selected = color_selected + 1
    end

    -- loop over
    if color_selected < 0 then
        color_selected = color_selected + 8
        color_tween = color_tween + 8
    elseif color_selected >= 8 then
        color_selected = color_selected - 8
        color_tween = color_tween - 8
    end
end

function undo() end

function love.load()
    assets = {
        cursor = love.graphics.newImage("assets/cursor.png"),
        splotch = love.graphics.newImage("assets/splotch.png"),
        toolButtons = love.graphics.newImage("assets/toolButtons.png"),
        tools = love.graphics.newImage("assets/tools.png"),
        uiBack = love.graphics.newImage("assets/uiBack.png"),
        uiFront = love.graphics.newImage("assets/uiFront.png"),
        uiWheel = love.graphics.newImage("assets/uiWheel.png"),
    }

    love.mouse.setVisible(false)

    image = love.graphics.newCanvas(600, 360)
    love.graphics.setCanvas(image)
    love.graphics.clear(COLORS[1])
    love.graphics.setCanvas()

    scribble = love.graphics.newCanvas(600, 360)
    scribble_def = canvas_clone(scribble)

    love.graphics.setLineStyle("smooth")
end

function love.update(dt)
    -- mouse
    if love.mouse.isDown(1) then
        mouse_click = mouse_click < 0 and 1 or mouse_click + 1
    else
        mouse_click = mouse_click > 0 and -1 or mouse_click - 1
    end

    -- tweens
    color_tween = color_tween + (color_selected - color_tween) / 5
    bigtool_offset = bigtool_offset - bigtool_offset / 10

    -- tool buttons
    tool_hover = -1
    if mouse_click < 0 then
        tool_clicked = -1
    end
    for i = 0, 7 do
        if insideRect(love.mouse.getX(), love.mouse.getY(), 4, 2+i*29, 28, 28) then
            tool_hover = i
            if mouse_click == 1 and i ~= 7 then
                tool_selected = i
                bigtool_offset = 10
            elseif mouse_click > 0 then
                tool_clicked = i
            end
            break
        end
    end
    if love.mouse.isDown(2) then
        tool_selected = -1
    end

    -- draw input
    draw = draw + sign(draw)
    if mouse_click == 1 and love.mouse.getX() >= 37 then -- TODO: replace the 37 here when the UI can move
        draw = 1
    elseif mouse_click == -1 then
        draw = -1
    end

    -- drawing
    local function finalize_draw()
        love.graphics.setColor(1,1,1,1)
        love.graphics.setCanvas(image)
        love.graphics.draw(scribble)
        love.graphics.setCanvas()
        scribble = canvas_clone(scribble_def)
    end

    if draw >= 1 then
        if tool_selected == 0 then
            -- brush: draw lines for each frame
            local mx, my = love.mouse.getPosition()

            love.graphics.setCanvas(scribble)
            love.graphics.setColor(COLORS[color_selected+1])
            love.graphics.setLineWidth(4)

            if draw > 1 then
                steps = math.abs(mx - last_mx) + math.abs(my - last_my)
                for t = 0, steps do
                    local x = lerp(last_mx, mx, t/steps)
                    local y = lerp(last_my, my, t/steps)
                    love.graphics.circle("fill", x, y, 2)
                end
            else
                love.graphics.circle("fill", mx, my, 2)
            end
            
            love.graphics.setCanvas()
        end

        if tool_selected == 1 then
            -- eraser: same as above, but forced white + thicker
            local mx, my = love.mouse.getPosition()

            love.graphics.setCanvas(scribble)
            love.graphics.setColor(COLORS[1])
            love.graphics.setLineWidth(10)

            if draw > 1 then
                steps = math.abs(mx - last_mx) + math.abs(my - last_my)
                for t = 0, steps do
                    local x = lerp(last_mx, mx, t/steps)
                    local y = lerp(last_my, my, t/steps)
                    love.graphics.circle("fill", x, y, 5)
                end
            else
                love.graphics.circle("fill", mx, my, 5)
            end
            
            love.graphics.setCanvas()
        end

        if tool_selected == 2 and draw == 1 then
            -- fill: bsp floodfill
            local root = {0, 0, 600, 360}
            
            local data = image:newImageData()

            local mx, my = love.mouse.getPosition()
            mx = math.floor(mx)
            my = math.floor(my)

            local tr, tg, tb, ta = data:getPixel(mx, my)
            local cr, cg, cb, ca = unpack(COLORS[color_selected+1])

            local function children(node)
                local x, y, w, h = unpack(node)

                if w <= 1 and h <= 1 then
                    return nil
                end

                if w >= h then
                    local w1 = math.floor(w / 2)
                    local w2 = w - w1

                    return
                        {x,     y, w1, h},
                        {x+w1,  y, w2, h}
                else
                    local h1 = math.floor(h / 2)
                    local h2 = h - h1

                    return
                        {x, y,     w, h1},
                        {x, y+h1,  w, h2}
                end
            end

            local function within(a, b)
                local ax, ay, aw, ah = unpack(a)
                local bx, by, bw, bh = unpack(b)
                return bx >= ax
                   and by >= ay
                   and bx + bw <= ax + aw
                   and by + bh <= ay + ah
            end

            local function parent(target)
                current = root
                while true do
                    local c1, c2 = children(current)

                    if not c1 then
                        return nil
                    end

                    if c1[1] == target[1] and c1[2] == target[2]
                    and c1[3] == target[3] and c1[4] == target[4] then
                        return current
                    end

                    if c2[1] == target[1] and c2[2] == target[2]
                    and c2[3] == target[3] and c2[4] == target[4] then
                        return current
                    end

                    if within(c1, target) then
                        current = c1
                    else
                        current = c2
                    end
                end
            end

            local wall = {}

            for y = 0, 359 do
                wall[y] = {}
                for x = 0, 599 do
                    r, g, b, a = data:getPixel(x, y)
                    wall[y][x] = (
                        r == tr and g == tg and b == tb and a == ta
                    ) and 0 or 1
                end
            end

            local sum = {}

            for y = 0, 360 do
                sum[y] = {}
                for x = 0, 600 do
                    if x == 0 or y == 0 then
                        sum[y][x] = 0
                    else
                        sum[y][x] =
                            wall[y-1][x-1]
                            + sum[y-1][x]
                            + sum[y][x-1]
                            - sum[y-1][x-1]
                    end
                end
            end

            local function wall_count(node)
                local x, y, w, h = unpack(node)

                local x1, y1 = x, y
                local x2, y2 = x + w, y + h

                return
                    sum[y2][x2]
                    - sum[y1][x2]
                    - sum[y2][x1]
                    + sum[y1][x1]
            end

            local function key(x,y,w,h)
                return x .. "," .. y
            end

            local queue = {{mx,my,1,1}}
            local visited = {}
            love.graphics.setCanvas(scribble)
            love.graphics.setColor(cr,cg,cb,ca)
            while #queue > 0 do
                local current = table.remove(queue, 1)
                if visited[key(unpack(current))] then goto continue end
                
                visited[key(unpack(current))] = true
                love.graphics.rectangle("fill", unpack(current))

                while true do
                    local p = parent(current)
                    if not p then break end

                    if wall_count(p) == 0 then
                        current = p

                        for x = current[1], current[1] + current[3] do
                            for y = current[2], current[2] + current[4] do
                                visited[key(x,y)] = true
                            end
                        end
                        love.graphics.rectangle("fill", unpack(current))
                    else break end
                end

                local x1 = current[1]
                local y1 = current[2]
                local w  = current[3]
                local h  = current[4]

                local x2 = x1 + w - 1
                local y2 = y1 + h - 1

                -- left
                if x1 > 0 then
                    for y = y1, y2 do
                        if wall[y][x1-1] == 0 and not visited[key(x1-1,y)] then
                            table.insert(queue, {x1-1,y,1,1})
                        end
                    end
                end

                -- right
                if x2 < 599 then
                    for y = y1, y2 do
                        if wall[y][x2+1] == 0 and not visited[key(x2+1,y)] then
                            table.insert(queue, {x2+1,y,1,1})
                        end
                    end
                end

                -- up
                if y1 > 0 then
                    for x = x1, x2 do
                        if wall[y1-1][x] == 0 and not visited[key(x,y1-1)] then
                            table.insert(queue, {x,y1-1,1,1})
                        end
                    end
                end

                -- down
                if y2 < 359 then
                    for x = x1, x2 do
                        if wall[y2+1][x] == 0 and not visited[key(x,y2+1)] then
                            table.insert(queue, {x,y2+1,1,1})
                        end
                    end
                end

                ::continue::
            end

            love.graphics.setCanvas()
            finalize_draw()
        end

        if tool_selected == 3 and draw == 1 then
            -- stamp: get random icon from splotch
            local sprite_x = love.math.random(0, 7)
            local sprite_y = love.math.random(0, 6)

            love.graphics.setCanvas(scribble)
            love.graphics.setColor(1,1,1,1)
            love.graphics.draw(
                assets.splotch, getSprite(assets.splotch, 24, 24, sprite_x, sprite_y),
                love.mouse.getX(), love.mouse.getY(),
                0,  1, 1,  12, 12
            )
            love.graphics.setCanvas()
            finalize_draw()
        end

        if tool_selected == 4 then
            -- shape
        end

        if tool_selected == 5 then
            -- text
        end

        if tool_selected == 6 then
            -- select
        end

    elseif draw == -1 then
        if contains({0,1}, tool_selected) then
            finalize_draw()
        end
    end

    -- final
    last_mx, last_my = love.mouse.getPosition()
end

function love.draw()
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(image, 0, 0)
    love.graphics.draw(scribble, 0, 0)

    -- ui
    love.graphics.draw(assets.uiBack, 0, 0)
    love.graphics.draw(
        assets.uiWheel,
        43.5, 316,
        math.rad(23.8-45*color_tween),
        1, 1,
        83.5, 83.5
    )
    love.graphics.draw(assets.uiFront, 0, 0)

    -- tool buttons
    for i = 0, 7 do
        local mode = 0
        if tool_hover == i then mode = 1 end
        if tool_selected == i then mode = 2 end
        if tool_clicked == i then mode = 2 end
        love.graphics.draw(assets.toolButtons, getSprite(assets.toolButtons, 28, 28, i, mode), 4, 2+i*29)
    end

    -- big tool icon
    local y, x = divmod(tool_selected, 4)
    love.graphics.draw(
        assets.tools, getSprite(assets.tools, 96, 96, x, y),
        46, 316 + bigtool_offset,
        0,  1, 1,  48, 48
    )

    -- cursor
    if love.window.hasMouseFocus() then
        local sprite_x = 0
        local sprite_y = 0
        if tool_selected == 0 then sprite_y = 1 end
        if tool_selected == 1 then sprite_x = 2 end
        if tool_selected == 2 then sprite_y = 2 end
        if tool_selected == 3 then sprite_x = 3 end
        if tool_selected == 4 then sprite_y = 3 end
        if tool_selected == 5 then sprite_y = 4 end
        if tool_selected == 6 then sprite_x = 4 end
        if tool_hover > -1 then
            sprite_x = 1
            sprite_y = 0
        end
        if sprite_y > 0 then sprite_x = color_selected end
        love.graphics.draw(
            assets.cursor, getSprite(assets.cursor, 18, 18, sprite_x, sprite_y),
            love.mouse.getX(), love.mouse.getY(),
            0,  1, 1,  1, 1
        )
    end
end