-- Clean pixel art script for Aseprite
-- Eliminates orphan pixels, dither chatter, and random color noise to create structured, readable shapes.

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

local totalReplaced = 0

-- PASS 1: Outlier and Orphan suppression (3x3 neighborhood)
-- Replace any pixel that has no same-color neighbor or is an extreme color outlier
for pass = 1, 2 do
    local copy = Image(img)
    for y = 1, h - 2 do
        for x = 1, w - 2 do
            local c = copy:getPixel(x, y)
            local counts = {}
            local neighborColors = {}
            local sameCount = 0
            local bestCount = 0
            local bestColor = c
            local minTotalDist = 999999
            local closestColor = c

            for dy = -1, 1 do
                for dx = -1, 1 do
                    if dx ~= 0 or dy ~= 0 then
                        local nc = copy:getPixel(x + dx, y + dy)
                        counts[nc] = (counts[nc] or 0) + 1
                        if counts[nc] > bestCount then
                            bestCount = counts[nc]
                            bestColor = nc
                        end
                        if nc == c then
                            sameCount = sameCount + 1
                        end
                        local d = colorDist(c, nc)
                        if d < minTotalDist then
                            minTotalDist = d
                            closestColor = nc
                        end
                    end
                end
            end

            -- If totally isolated (0 same neighbors) or weak isolated (1 same neighbor and best neighbor has >= 4)
            if sameCount == 0 then
                -- Pure orphan pixel: assign best majority neighbor
                img:putPixel(x, y, bestColor)
                totalReplaced = totalReplaced + 1
            elseif sameCount == 1 and bestCount >= 4 then
                -- Paired orphan or noisy dither tip: merge into dominant cluster
                img:putPixel(x, y, bestColor)
                totalReplaced = totalReplaced + 1
            elseif sameCount <= 2 and minTotalDist > 75 and bestCount >= 3 then
                -- Random contrasting color speckle
                img:putPixel(x, y, bestColor)
                totalReplaced = totalReplaced + 1
            end
        end
    end
end

-- PASS 2: Cluster consolidation (remove 2x2 and small checkerboards that cause dither chatter)
for pass = 1, 2 do
    local copy = Image(img)
    for y = 1, h - 2 do
        for x = 1, w - 2 do
            local c = copy:getPixel(x, y)
            -- Count orthogonal neighbors vs diagonal
            local orthoCounts = {}
            local orthoMax = 0
            local orthoBest = c
            local orthoSame = 0

            local orthos = {
                copy:getPixel(x + 1, y),
                copy:getPixel(x - 1, y),
                copy:getPixel(x, y + 1),
                copy:getPixel(x, y - 1)
            }

            for _, nc in ipairs(orthos) do
                orthoCounts[nc] = (orthoCounts[nc] or 0) + 1
                if orthoCounts[nc] > orthoMax then
                    orthoMax = orthoCounts[nc]
                    orthoBest = nc
                end
                if nc == c then
                    orthoSame = orthoSame + 1
                end
            end

            -- If 0 orthogonal neighbors of same color (e.g. checkerboard diagonal or pinch), adopt orthogonal majority
            if orthoSame == 0 and orthoMax >= 2 then
                img:putPixel(x, y, orthoBest)
                totalReplaced = totalReplaced + 1
            end
        end
    end
end

return {
    success = true,
    totalReplaced = totalReplaced
}
