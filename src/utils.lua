-- these functions aren't used in the current version of the game.
-- but I figure these might be useful and at any rate a utils file will probably be needed sometime
local utils = {}

function utils.box_contains(box, x, y)
    return (x > box.x and x < box.x + box.w and y > box.y and y < box.y + box.h)
end

function utils.sum(arr)
    return lume.reduce(arr, function(a, b) return a + b end, 0)
end

return utils
