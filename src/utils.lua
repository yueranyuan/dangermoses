-- these functions aren't used in the current version of the game.
-- but I figure these might be useful and at any rate a utils file will probably be needed sometime
local utils = {}

function utils.box_contains(box, x, y)
    return (x > box.x and x < box.x + box.w and y > box.y and y < box.y + box.h)
end

function utils.sum(arr)
    return lume.reduce(arr, function(a, b) return a + b end, 0)
end

function utils.range(a, b, c)
    if c == nil then c = 1 end
    if b == nil then
        b = a
        a = 0
    end
    local arr = {}
    for i=a, b, c do table.insert(arr, i) end
    return arr
end

function utils.repeat_v(v, n)
    local arr = {}
    for _=1, n do table.insert(arr, v) end
    return arr
end

function utils.concat_arr(arr)
    return lume.reduce(arr, lume.concat, {})
end

function utils.set(arr)
    local out = {}
    for _, val in ipairs(arr) do
        if lume.find(out, val) == nil then
            table.insert(out, val)
        end
    end
    return out
end

function utils.shallow_copy(arr)
    return lume.map(arr)
end

function utils.trace_arr(arr)
    log.trace('['..lume.reduce(lume.map(arr, tostring), function(a, b) return a..', '..b end, "")..']')
end

return utils
