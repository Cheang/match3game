-- Animation script for Aseprite: Water & Trees ambient loop
-- Creates a seamless 4-frame looping animation at 150ms per frame.

local spr = sprite
local w = spr.width
local h = spr.height
local pal = spr.palettes[1]

-- 1. Ensure we have 4 frames
while #spr.frames < 4 do
    spr:newFrame()
end

for i = 1, 4 do
    spr.frames[i].duration = 0.15 -- 150ms per frame
end

-- Base image from frame 1
local baseImg = Image(spr.cels[1].image)

-- Palette color helpers
-- Sunset sky colors for inpainting exposed sky behind swaying leaves
-- Sample vertical sky gradient at X=500
local skyByY = {}
for y = 0, 200 do
    skyByY[y] = baseImg:getPixel(500, y)
end

-- Identify tree leaves in top-left and top-right
-- In top-left: X: 40..270, Y: 0..170
-- In top-right: X: 730..1180, Y: 0..115
-- Foliage colors: dark greens/purples/browns (e.g. 1, 2, 3, 4, 30, 31, 32, 35, 36, 37, 50)
local function isLeafColor(c)
    -- Sky colors are orange/yellow/reds (13, 14, 17, 18, 19, 21, 22, 23, 24, 25, 29)
    -- Foliage colors are dark greens, charcoal, dark purples
    return c == 1 or c == 2 or c == 3 or c == 4 or c == 6 or c == 7 or
           c == 30 or c == 31 or c == 32 or c == 35 or c == 36 or c == 37 or
           c == 50 or c == 51
end

-- Identify water pixels in river & waterfall: X: 420..840, Y: 460..674
-- Water colors include blues, cyans, river reflections (oranges, yellows, whites)
local function isWaterRegion(x, y)
    if y >= 460 and y <= 674 and x >= 420 and x <= 850 then
        -- Exclude bridge stones and static rock islands
        -- Rock colors are typically dark brown/slate
        return true
    end
    return false
end

-- Generate frames 2, 3, 4
for f = 2, 4 do
    local cel = spr.layers[1]:cel(f)
    if not cel then
        cel = spr:newCel(spr.layers[1], f)
    end
    local img = Image(baseImg)

    -- Sways:
    -- Frame 2: slight sway (+1 px)
    -- Frame 3: peak sway (+2 px on tips, +1 px on base)
    -- Frame 4: return sway (+1 px)
    local swayX = (f == 3) and 2 or 1
    local swayY = (f == 3) and 1 or 0

    -- A. ANIMATE TOP-LEFT TREE BRANCHES & LEAVES
    -- Sway hanging leaves towards right
    local tlMask = {}
    for y = 0, 170 do
        for x = 50, 270 do
            local c = baseImg:getPixel(x, y)
            if isLeafColor(c) then
                -- Weight sway: tips at x > 150 sway more
                local weight = (x - 50) / 220
                local dx = math.floor(swayX * weight + 0.5)
                local dy = math.floor(swayY * weight + 0.5)
                if dx > 0 or dy > 0 then
                    tlMask[#tlMask + 1] = { x = x, y = y, c = c, dx = dx, dy = dy }
                end
            end
        end
    end

    -- Clear original positions of swaying leaves with sky
    for _, pt in ipairs(tlMask) do
        local sky = skyByY[pt.y] or baseImg:getPixel(300, pt.y)
        img:putPixel(pt.x, pt.y, sky)
    end
    -- Draw leaves at shifted positions
    for _, pt in ipairs(tlMask) do
        img:putPixel(pt.x + pt.dx, pt.y + pt.dy, pt.c)
    end

    -- B. ANIMATE TOP-RIGHT TREE LEAVES
    local trMask = {}
    for y = 0, 115 do
        for x = 730, 1180 do
            local c = baseImg:getPixel(x, y)
            if isLeafColor(c) then
                local weight = (1180 - x) / 450
                if weight > 1 then weight = 1 end
                if weight < 0 then weight = 0 end
                local dx = math.floor(swayX * weight + 0.5)
                local dy = math.floor(swayY * weight + 0.5)
                if dx > 0 or dy > 0 then
                    trMask[#trMask + 1] = { x = x, y = y, c = c, dx = dx, dy = dy }
                end
            end
        end
    end

    for _, pt in ipairs(trMask) do
        local sky = skyByY[pt.y] or baseImg:getPixel(700, pt.y)
        img:putPixel(pt.x, pt.y, sky)
    end
    for _, pt in ipairs(trMask) do
        img:putPixel(pt.x + pt.dx, pt.y + pt.dy, pt.c)
    end

    -- C. ANIMATE WATER (Waterfall + River Ripples)
    -- Waterfall (X: 520..680, Y: 460..520): Vertical stream shift
    local waterShift = (f - 1) % 4 -- 0, 1, 2, 3
    for y = 465, 515 do
        for x = 525, 675 do
            local c = baseImg:getPixel(x, y)
            -- Check if water stream color (whites, cyans, light oranges)
            if c == 10 or c == 9 or c == 44 or c == 43 or c == 24 or c == 19 then
                -- Shift source vertically in 4-pixel cycle
                local srcY = y - waterShift
                if srcY < 465 then srcY = srcY + 50 end
                local srcC = baseImg:getPixel(x, srcY)
                if srcC == 10 or srcC == 9 or srcC == 44 or srcC == 43 or srcC == 24 or srcC == 19 then
                    img:putPixel(x, y, srcC)
                end
            end
        end
    end

    -- River Reflection Ripples (X: 430..820, Y: 520..674)
    -- Shimmer & drift horizontal reflection lines
    for y = 520, 674 do
        -- Alternate rows flow slightly
        local rowOffset = ((y + f) % 4) == 0 and 1 or (((y + f) % 4) == 2 and -1 or 0)
        for x = 440, 810 do
            local c = baseImg:getPixel(x, y)
            -- If reflection color (golds, oranges, whites, specular cyan)
            if c == 19 or c == 23 or c == 24 or c == 18 or c == 14 or c == 10 or c == 9 then
                -- Check if neighbor is also reflection
                local cAdj = baseImg:getPixel(x + rowOffset, y)
                if cAdj == 19 or cAdj == 23 or cAdj == 24 or cAdj == 18 or cAdj == 14 or cAdj == 10 or cAdj == 9 then
                    img:putPixel(x, y, cAdj)
                end
            end
        end
    end

    cel.image = img
end

return {
    framesCreated = #spr.frames,
    duration = 0.15
}
