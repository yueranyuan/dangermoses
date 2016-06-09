--
-- Created by IntelliJ IDEA.
-- User: yueran
-- Date: 6/4/16
-- Time: 9:41 PM
-- To change this template use File | Settings | File Templates.
--

local logic = {inter={}}

local function sue(tile)
    if tile.lawsuit then
        tile.lawsuit.pros = tile.lawsuit.pros + 1
        return
    end

    print("sued at "..tile.id)

    local bonus = 0
    if lume.find(state.moses.positions, tile.building_type) then
        bonus = bonus + 1
    end

    local lawsuit = {type="lawsuit",
        tile=tile,
        influence=0,
        pros=1,
        cons=bonus,
        position=50,
        total=100,
        settle_price=2 * tile.cost,
        expiration_time=60.0 }
    tile.lawsuit = lawsuit
    table.insert(state.legal, lawsuit)
end

local function reset_tile(name)
    local tile = state.tiles[name]
    tile.is_started = 0
    tile.elapsed_construction_time = 0
end

local function finish_legal_action(action)
    if action.type == "nomination" then
        table.insert(state.moses.positions, action.subtype)
    elseif action.type == "lawsuit" then
        -- get fined
        if (not action.tile.is_approved) then
            print("get fined")
            state.moses.money = state.moses.money - action.tile.cost
        end
        print("lost lawsuit")
        reset_tile(action.tile.id)
        action.tile.lawsuit = nil
    elseif action.type == "approval" then
        action.tile.is_approved = true
    else
        assert(false, "Other legal action types are not implemented")
    end
    action.finished = true
end

local function expire_legal_action(action)
    if action.type == "lawsuit" then
        action.tile.lawsuit = nil
    else
        if not action_is_pro_user then
            state.moses.influence = state.moses.influence + action.influence
        end
    end
    action.finished = true
    print("legal action expired")
end

local function action_is_pro_user(action)
    return (action.type == "nomination" or action.type == "approval")
end

local function add_nomination(position)
    local nomination = {type="nomination",
        tile=nil,  -- this is a tile table reference not the tile id
        subtype=position,
        influence=0,
        pros=0,
        cons=0,
        position=0,
        total=1500,
        expiration_time=120.0 }
    table.insert(state.legal, nomination)
end

local function update_legal(dt)
    -- first remove all the finished actions
    local to_remove_idxs = {}
    for action_i, action in ipairs(state.legal) do
        if action.finished then
            table.insert(to_remove_idxs, action_i)
        end
    end
    for i = #to_remove_idxs, 1, -1 do
        table.remove(state.legal, to_remove_idxs[i])
    end

    -- loop through remaining actions
    for action_i, action in ipairs(state.legal) do
        local rate = (action.pros - action.cons) * dt
        action.position = math.max(action.position + rate, 0)
        action.expiration_time = action.expiration_time - dt
        if action.position > action.total then
            finish_legal_action(action)
            if action_is_pro_user then
                state.moses.influence = state.moses.influence + action.influence
            end
        elseif action.expiration_time < 0.0 then
            expire_legal_action(action)
        end
    end
end

local function update_government(dt)
    if state.world.year / 5 > state.mayor.audit_cycle_idx then
        state.mayor.audit_cycle_idx = state.mayor.audit_cycle_idx + 1
        if state.moses.money < 0 then
            lose()
        end
    end

    if state.world.year / 3 > state.mayor.nomination_cycle_idx then
        state.mayor.nomination_cycle_idx = state.mayor.nomination_cycle_idx + 1
        if not lume.find(state.moses.positions, "park") then
            add_nomination("park")
        end
        if not lume.find(state.moses.positions, "road") then
            add_nomination("road")
        end
        if not lume.find(state.moses.positions, "tenement") then
            add_nomination("tenement")
        end
    end
end

local function update_tiles(dt)
    for k, tile in pairs(state["tiles"]) do
        if tile.is_completed then
            state.moses.money = state.moses.money + tile.revenue * dt
        elseif tile.is_started then
            tile.elapsed_construction_time = tile.elapsed_construction_time + dt
            if tile.elapsed_construction_time > tile.construction_time then
                tile.is_completed = true
                state.moses.influence = state.moses.influence + tile.influence
            end

            -- start a suit
            if tile.illegality * dt > math.random() then
                sue(tile)
            end
        end
    end
end


function logic.update(dt)
    state.world.time = state.world.time + dt
    state.world.year = state.world.time / 60.0
    state.moses.popularity = math.min(state.moses.popularity + dt / 2, 100)
    update_legal(dt)
    update_tiles(dt)
    update_government(dt)
end


---- Call these functions to send user input -----

function logic.inter.request_approval(name)
    local tile = state.tiles[name]
    if tile.approval_action then
        return
    end

    local approval = {type="approval",
        tile=tile,
        influence=0,
        pros=0,
        cons=0,
        position=50,
        total=100,
        expiration_time=30.0 }

    tile.approval_action = approval
    table.insert(state.legal, approval)
end

function logic.inter.build_tile(name)
    local tile = state.tiles[name]
    if tile.is_completed then
        return
    end

    state.moses.money = state.moses.money - tile.cost
    tile.is_started = true
end

function logic.inter.resign()
    for action_i, action in pairs(state.legal) do
        if action.type == "lawsuit" then
            state.moses.popularity = state.moses.popularity - 4 * (action.pros * math.random())
            expire_legal_action(action)
            action.finished = true
        end
    end

    if state.moses.popularity < 0.0 then
        lose()
    end
end

function logic.inter.settle(action)
    state.moses.money = state.moses.money - action.settle_price
    expire_legal_action(action)
end

function logic.inter.add_influence(action)
    if state.moses.influence <= 0 then
        return
    end
    state.moses.influence = state.moses.influence - 1
    action.influence = action.influence + 1
    local bonus = 0
    -- commissioner bonus
    if action.tile then
        if lume.find(state.moses.positions, action.tile.building_type) then
            bonus = bonus + 1
        end
    end

    if action_is_pro_user(action) then
        action.pros = action.pros + 1 + bonus
    else
        action.cons = action.cons + 1 + bonus
    end
end

return logic
