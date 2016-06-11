--
-- Created by IntelliJ IDEA.
-- User: yueran
-- Date: 6/11/16
-- Time: 1:23 AM
-- To change this template use File | Settings | File Templates.
--

local utils = {}

function utils.box_contains(box, x, y)
    return (x > box.x and x < box.x + box.w and y > box.y and y < box.y + box.h)
end

function utils.sum(arr)
    return lume.reduce(arr, function(a, b) return a + b end, 0)
end

return utils
