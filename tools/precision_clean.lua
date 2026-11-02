-- Precision Pixel Art Cleanup for Aseprite
-- Eliminates random color noise and speckles while 100% preserving fine detail, lines, architecture, and accents.

local img = sprite.cels[1].image
local w = img.width
local h = img.height
local pal = sprite.palettes[1]

-- Build RGB lookup table
local p = {}
for i = 0, #pal - 1 do
    local c = pal:getColor(i)
    p[i] = { r = c.red, g = c.green, b = c.blue }
end

local function colorDist(c1, c2)
    local p1, p2 = p[c1], p[c2]
    if not p1 or not p2 then return 0 end
    local dr = p1.r - p2.r
    local dg = p1.g - p2.g
    local db = p1.b - p2.b
    return math.sqrt(dr * dr + dg * dg + db * db)
end

-- Protected accent colors (flowers, window lights, specular gleams, stars)
local protectedColors = {
    [10] = true, -- #ffffff pure white
    [11] = true, -- #6e2727 dark red flower
    [12] = true, -- #b33831 red flower
    [13] = true, -- #ea4f36 bright red flower
    [15] = true, -- #ae2334 crimson flower
    [16] = true, -- #e83b3b bright crimson flower
    [17] = true, -- #fb6b1d orange-red flower / spark
    [29] = true, -- #fbff86 pale yellow light / glint
    [56] = true, -- #a24b6f pink flower
    [57] = true, -- #cf657f light pink flower
    [58] = true, -- #ed8099 soft pink flower
    [60] = true, -- #c32454 magenta flower
    [61] = true, -- #f04f78 bright pink flower
    [62] = true, -- #f68181 rose flower
    [63] = true  -- #fca790 peach flower
}

-- Checks if a pixel is part of a line or corner (collinear or L-junction)
local function isPartOflnOrEdge(copy, x, y, c)
    local up    = copy:getPixel(x, y - 1) == c
    local down  = copy:getPixel(x, y + 1) == c
    local left  = copy:getPixel(x - 1, y) == c
    local right = copy:getPixel(x + 1, y) == c

    -- Collinear lines (horizontal, vertical)
    if (left and right) or (up and down) then
        return true
    end

    -- Diagonal lines
    local ul = copy:getPixel(x - 1, y - 1) == c
    local br = copy:getPixel(x + 1, y + 1) == c
    if ul and br then return true end

    local ur = copy:getPixel(x + 1, y - 1) == c
    local bl = copy:getPixel(x - 1, y + 1) == c
    if ur and bl then return true end

    -- Corners / L-junctions
    if (up and right) or (up and left) or (down and right) or (down and left) then
        return true
    end

    return false
end

local totalFixed = 0
local copy = Image(img)

for y = 1, h - 2 do
    for x = 1, w - 2 do
        local c = copy:getPixel(x, y)

        -- Skip protected accents (flowers, specular glints)
        if not protectedColors[c] then
            -- Skip if it is part of a line, outline, or corner
            if not isPartOflnOrEdge(copy, x, y, c) then
                -- Count neighbors of the same color
                local sameCount = 0
                local counts = {}
                local dominantColor = c
                local dominantCount = 0
                local minNeighborDist = 999999
                local closestNeighbor = c

                for dy = -1, 1 do
                    for dx = -1, 1 do
                        if dx ~= 0 or dy ~= 0 then
                            local nc = copy:getPixel(x + dx, y + dy)
                            if nc == c then
                                sameCount = sameCount + 1
                            else
                                counts[nc] = (counts[nc] or 0) + 1
                                if counts[nc] > dominantCount then
                                    dominantCount = counts[nc]
                                    dominantColor = nc
                                end
                                local d = colorDist(c, nc)
                                if d < minNeighborDist then
                                    minNeighborDist = d
                                    closestNeighbor = nc
                                end
                            end
                        end
                    end
                end

                -- Condition 1: Pure speckle hole
                -- A single pixel with ZERO same neighbors, surrounded heavily (>= 6) by a single dominant color
                if sameCount == 0 and dominantCount >= 6 then
                    img:putPixel(x, y, dominantColor)
                    totalFixed = totalFixed + 1

                -- Condition 2: Rogue color outlier
                -- A single pixel with ZERO same neighbors, and its color is completely alien to all surrounding neighbors (minNeighborDist > 75)
                elseif sameCount == 0 and minNeighborDist > 75 and dominantCount >= 4 then
                    img:putPixel(x, y, dominantColor)
                    totalFixed = totalFixed + 1

                -- Condition 3: Lone color speckle in mountain/rock shadow
                -- In mountain region (y < 350), lone pixels that conflict with the dominant surface tone
                elseif y < 350 and sameCount == 0 and dominantCount >= 5 then
                    img:putPixel(x, y, dominantColor)
                    totalFixed = totalFixed + 1
                end
            end
        end
    end
end

return {
    totalFixed = totalFixed
}
