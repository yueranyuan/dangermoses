math.randomseed(1337)

--- all game constants go here
local consts = {
    MAYOR_ELECTION_CYCLE_YEARS = 4,
    YEAR_LENGTH = 60,
    BUILDING_TYPES = {'park', 'road', 'tenement'} }

--- the state contains all the data necessary to describe a moment in the game
--- this information should be the only thing necessary to be held in memory between loops
--- and the only thing necessary to communicate from the game logic to the UI
local state = {
    world = {time=0,
             year=0},
    tiles = {},
    moses = {influence=10,
             money=100,
             positions={'park'},
             popularity=0},
    legal = {},
    mayor = {name="Al Smith",
             time_before_election=consts.MAYOR_ELECTION_CYCLE_YEARS * consts.YEAR_LENGTH,
             nomination_cycle_idx=0,
             audit_cycle_idx=0}
    }
local tiles = {}
for _, c in ipairs({"A", "B", "C", "D", "E", "F", "G", "H", "I", "J"}) do
    for i = 1, 10 do
        local cost = 10 + math.random(200)
        local building_type = consts.BUILDING_TYPES[math.random(3)]
        local tile_id = c..i
        tiles[tile_id] = {cost=cost,
                       id=tile_id,
                       illegality=math.random() * 0.2,
                       influence=cost / 3,
                       revenue=cost / 100.0,
                       elapsed_construction_time=0,
                       construction_time=cost * 2,
                       building_type=building_type,
                       is_approved=false,
                       is_started=false,
                       is_completed=false
                       }
    end
end

state["tiles"] = tiles

return state, consts