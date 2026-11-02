-- Clean Orphans Only: Zero blurriness, 100% crisp detail preserved.
-- Only targets strictly isolated 1x1 noise speckles while protecting all lines, ripples, textures, and accents.

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

-- Intentional 1-pixel accents: flowers, white foam glints, specular sparkle, warm window lights
local protectedColors = {
    [10] = true, -- #ffffff white glint / foam
    [9]  = true, -- #c7dcd0 pale glint
    [11] = true, -- red flower
    [12] = true, -- red flower
    [13] = true, -- bright red flower
    [15] = true, -- crimson flower
    [16] = true, -- bright crimson flower
    [17] = true, -- orange-red accent
    [29] = true, -- #fbff86 pale yellow light / star
    [33] = true, -- #91db69 bright lime leaf highlight
    [34] = true, -- #cddf6c bright yellow-green leaf highlight
    [43] = true, -- #30e1b9 turquoise glint
    [44] = true, -- #8ff8e2 cyan foam glint
    [49] = true, -- #8fd3ff sky water glint
    [56] = true, -- pink flower
    [57] = true, -- light pink flower
    [58] = true, -- soft pink flower
    [60] = true, -- magenta flower
    [61] = true, -- bright pink flower
    [62] = true, -- rose flower
    [63] = true  -- peach flower
}

local copy = Image(img)
local removedCount = 0

for y = 1, h - 2 do
    for x = 1, w - 2 do
        local c = copy:getPixel(x, y)

        -- Never touch protected accents
        if not protectedColors[c] then
            -- Count all 8 neighbors
            local sameCount = 0
            local counts = {}
            local dominantColor = c
            local dominantCount = 0

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
                        end
                    end
                end
            end

            -- STRICT RULE: Only touch if sameCount == 0 (strictly zero neighbors of same color in 3x3)
            -- AND the dominant neighbor has >= 4 pixels (so it's sitting inside an established cluster)
            if sameCount == 0 and dominantCount >= 4 then
                img:putPixel(x, y, dominantColor)
                removedCount = removedCount + 1
            -- If sameCount == 0 and dominantCount is 3, but the pixel is an extreme color outlier (minDist > 70)
            elseif sameCount == 0 and dominantCount >= 3 then
                local minDist = 999999
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        if dx ~= 0 or dy ~= 0 then
                            local d = colorDist(c, copy:getPixel(x + dx, y + dy))
                            if d < minDist then minDist = d end
                        end
                    end
                end
                if minDist > 70 then
                    img:putPixel(x, y, dominantColor)
                    removedCount = removedCount + 1
                end
            end
        end
    end
end

return {
    removedCount = removedCount
}
