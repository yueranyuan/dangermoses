--
-- Created by IntelliJ IDEA.
-- User: yueran
-- Date: 6/4/16
-- Time: 9:41 PM
-- To change this template use File | Settings | File Templates.
--

function update_tiles(dt)
    for k, tile in pairs(state["tiles"]) do
        if tile.is_completed then
            state.moses.money = state.moses.money + tile.revenue * dt
            state.moses.influence = state.moses.influence + tile.influence
        elseif tile.is_started then
            tile.elapsed_construction_time = tile.elapsed_construction_time + dt
            tile.is_completed = tile.elapsed_construction_time > tile.construction_time

            -- start a suit
            if tile.illegality * dt > math.random() then
                sue(tile)
            end
        end
    end
end

function request_approval(tile)
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

function sue(tile)
    if tile.lawsuit then
        tile.lawsuit.pros = tile.lawsuit.pros + 1
        return
    end

    local lawsuit = {type="lawsuit",
        tile=tile,
        influence=0,
        pros=0,
        cons=0,
        position=50,
        total=100,
        expiration_time=30.0 }
    tile.lawsuit = lawsuit
    table.insert(state.legal, lawsuit)
end

function build_tile(name)
    local tile = state.tiles[name]
    if tile.is_completed then
        return
    end

    if state.moses.money >= tile.cost then
        state.moses.money = state.moses.money - tile.cost
        tile.is_started = true
    end
end

function reset_tile(name)
    local tile = state.tiles[name]
    tile.is_started = 0
    tile.elapsed_construction_time = 0
end

function finish_legal_action(action)
    if action.type == "nomination" then
        table.insert(state.moses.positions, action.subtype)
    elseif action.type == "lawsuit" then
        -- get fined
        if (not action.tile.is_approved) then
            state.moses.money = state.moses.money - action.tile.cost * 0.20
        end
        reset_tile(action.tile.id)
    elseif action.type == "approval" then
        action.tile.is_approved = true
    else
        assert(false, "Other legal action types are not implemented")
    end
end

function add_influence(action)
    if state.moses.influence == 0 then
        return
    end
    state.moses.influence = state.moses.influence - 1
    action.influence = action.influence + 1
    if (action.type == "nomination" or action.type == "approval") then
        action.pros = action.pros + 1
    else
        action.cons = action.cons + 1
    end
end

function update_legal(dt)
    local to_remove_idxs = {}
    for action_i, action in ipairs(state.legal) do
        local rate = (action.pros - action.cons) * dt
        action.position = math.max(action.position + rate, 0)
        action.expiration_time = action.expiration_time - dt
        if action.position > action.total then
            finish_legal_action(action)
            table.insert(to_remove_idxs, action_i)
        elseif action.expiration_time < 0.0 then
            state.moses.influence = state.moses.influence + action.influence
            table.insert(to_remove_idxs, action_i)
        end
    end

    for _, idx in ipairs(to_remove_idxs) do
        table.remove(state.legal, idx)
    end
end

function update(dt)
    update_legal(dt)
    update_tiles(dt)
end

function on_click(x, y)
    tile = get_cell(x, y)
    if tile then
        build_tile(tile)
    end

    action = get_influence_button(x, y)
    if action then
        add_influence(action)
    end
end
