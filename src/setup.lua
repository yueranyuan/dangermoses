math.randomseed(1337)

consts = require "src/consts"

--- the state contains all the data necessary to describe a moment in the game
--- this information should be the only thing necessary to be held in memory between loops
--- and the only thing necessary to communicate from the game logic to the UI
local state = {
    world = {time=0,
             year=0,
             year_idx=0},
    tiles = {},
    moses = {influence=3,
             money=0,
             true_balance=0,
             positions={'park'},
             popularity=100},
    legal = {},
    mayor = {nomination_cycle_idx=0,
             grant_cycle_idx=0}
    }
local tiles = {}
for _, c in ipairs({"A", "B", "C", "D", "E", "F", "G", "H", "I", "J"}) do
    for i = 1, 10 do
        local level = lume.round(math.random(5))
        local building_type = consts.BUILDING_TYPES[math.random(3)]
        local tile_id = c..i
        tiles[tile_id] = {cost=level * 100,
                       id=tile_id,
                       illegality=math.random() * 0.2,
                       popularity=level * 5,
                       influence=level,
                       elapsed_construction_time=0,
                       construction_time=level * 200,
                       building_type=building_type,
                       is_approved=false,
                       is_started=false,
                       is_completed=false,
                       is_stalled=false
                       }
    end
end

state.tiles = tiles

return state
