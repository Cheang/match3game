-- Refined Ambient Animation for Aseprite: Water & Trees
-- Seamless 4-frame loop, 150ms per frame. Zero visual artifacts.

local spr = sprite
local w = spr.width
local h = spr.height

-- Reset to 1 frame first
while #spr.frames > 1 do
    spr:deleteFrame(spr.frames[#spr.frames])
end

-- Ensure frame 1 duration is 150ms
spr.frames[1].duration = 0.15

-- Base cel and image
local baseCel = spr.layers[1]:cel(1)
local baseImg = Image(baseCel.image)

-- Helper: check if a pixel is foliage (dark tones)
local function isFoliage(c)
    return c == 0 or c == 1 or c == 2 or c == 3 or c == 4 or c == 6 or c == 7 or
           c == 30 or c == 31 or c == 32 or c == 35 or c == 36 or c == 37 or
           c == 45 or c == 46 or c == 50 or c == 51
end

-- Helper: check if foliage highlight (warm orange/red leaf rim)
local function isLeafHighlight(c)
    return c == 13 or c == 14 or c == 17 or c == 21 or c == 22 or c == 23 or c == 24
end

-- Create frames 2, 3, 4
for f = 2, 4 do
    local newFrame = spr:newFrame()
    newFrame.duration = 0.15
    local cel = spr.layers[1]:cel(f)
    local img = Image(baseImg)

    -------------------------------------------------------------
    -- 1. WATERFALL ANIMATION (X: 520..680, Y: 466..518)
    -------------------------------------------------------------
    -- In each frame, cycle the vertical falling water streams down by 1-2 pixels
    local vShift = (f - 1) * 2 -- 2, 4, 6
    for y = 466, 514 do
        for x = 525, 675 do
            local c = baseImg:getPixel(x, y)
            -- Water stream pixels: foam white (10, 9), cyan (44, 43), golden streak (24, 19, 18)
            if c == 10 or c == 9 or c == 44 or c == 43 or c == 24 or c == 19 or c == 18 then
                local srcY = y - vShift
                if srcY < 466 then srcY = srcY + (514 - 466 + 1) end
                local srcC = baseImg:getPixel(x, srcY)
                if srcC == 10 or srcC == 9 or srcC == 44 or srcC == 43 or srcC == 24 or srcC == 19 or srcC == 18 then
                    img:putPixel(x, y, srcC)
                end
            end
        end
    end

    -- Waterfall plunge splash / foam puffs (Y: 512..522, X: 525..675)
    -- Alternating bubbly foam along the base
    for x = 530, 670 do
        local phase = (x + f * 3) % 4
        if phase == 0 then
            local c = baseImg:getPixel(x, 515)
            if c == 10 or c == 9 or c == 44 then
                img:putPixel(x, 514, 10) -- splash glint up
                img:putPixel(x, 516, 44) -- foam shadow
            end
        elseif phase == 2 then
            local c = baseImg:getPixel(x, 516)
            if c == 10 or c == 9 or c == 44 then
                img:putPixel(x, 515, 9)
            end
        end
    end

    -------------------------------------------------------------
    -- 2. RIVER SURFACE & REFLECTION RIPPLES (X: 430..820, Y: 522..674)
    -------------------------------------------------------------
    -- Subtle forward flow & shimmer of golden horizontal reflection lines
    for y = 522, 674 do
        -- Alternate rows flow gently downwards/forward
        local flowCycle = (f - 1) % 4
        local rowOffset = 0
        if flowCycle == 1 then
            rowOffset = (y % 3 == 0) and 1 or 0
        elseif flowCycle == 2 then
            rowOffset = (y % 2 == 0) and 1 or -1
        elseif flowCycle == 3 then
            rowOffset = (y % 3 == 1) and -1 or 0
        end

        for x = 440, 810 do
            local c = baseImg:getPixel(x, y)
            -- River reflection colors (golds, oranges, water glints)
            if c == 19 or c == 23 or c == 24 or c == 18 or c == 14 or c == 10 or c == 9 or c == 44 then
                if rowOffset ~= 0 then
                    local targetX = x + rowOffset
                    local targetC = baseImg:getPixel(targetX, y)
                    -- Only shift if adjacent pixel is also water/reflection (don't bleed onto rocks)
                    if targetC == 19 or targetC == 23 or targetC == 24 or targetC == 18 or targetC == 14 or targetC == 10 or targetC == 9 or targetC == 44 or targetC == 45 or targetC == 46 then
                        img:putPixel(x, y, targetC)
                    end
                end

                -- Specular glint twinkle in water
                if (c == 10 or c == 29) and ((x + y + f) % 5 == 0) then
                    img:putPixel(x, y, 24) -- soft gold shimmer
                end
            end
        end
    end

    -------------------------------------------------------------
    -- 3. TREES ANIMATION (Leaves rustle & subtle sway)
    -------------------------------------------------------------
    -- Top-left tree: sway phase
    -- f=2: sway right 1px, f=3: sway peak, f=4: sway return
    local sway = (f == 2 and 1) or (f == 3 and 1) or (f == 4 and 0) or 0
    local shimmerPhase = f % 2

    -- Top-left foliage (X: 50..270, Y: 0..180)
    for y = 0, 180 do
        for x = 60, 270 do
            local c = baseImg:getPixel(x, y)
            if isFoliage(c) then
                -- Check if it's on the edge of the leaf cluster (touching sky to the right)
                local rightC = baseImg:getPixel(x + 1, y)
                local leftC  = baseImg:getPixel(x - 1, y)

                -- If swaying right and at the outer perimeter (facing sky on the right)
                if sway == 1 and not isFoliage(rightC) and not isLeafHighlight(rightC) then
                    -- Flutter tip out into sky by 1px on hanging branches
                    if y > 40 and ((x + y) % 3 == 0) then
                        img:putPixel(x + 1, y, c)
                    end
                end

                -- Shimmer rim light on leaves catching sunset
                if isLeafHighlight(c) then
                    if shimmerPhase == 1 and ((x + y) % 4 == 0) then
                        img:putPixel(x, y, 23) -- pulse warm gold
                    end
                end
            end
        end
    end

    -- Top-right foliage (X: 740..1150, Y: 0..120)
    for y = 0, 120 do
        for x = 740, 1150 do
            local c = baseImg:getPixel(x, y)
            if isFoliage(c) then
                local rightC = baseImg:getPixel(x + 1, y)
                local leftC  = baseImg:getPixel(x - 1, y)

                if sway == 1 and not isFoliage(leftC) and not isLeafHighlight(leftC) then
                    if ((x + y) % 3 == 0) then
                        img:putPixel(x - 1, y, c) -- flutter windward fringe
                    end
                end

                if isLeafHighlight(c) and shimmerPhase == 1 and ((x + y) % 4 == 0) then
                    img:putPixel(x, y, 23)
                end
            end
        end
    end

    cel.image = img
end

return {
    totalFrames = #spr.frames,
    durationPerFrame = 0.15
}
