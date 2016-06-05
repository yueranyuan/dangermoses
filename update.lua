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

    print("sued at "..tile.id)

    local bonus = 0
    for i, position in ipairs(state.moses.positions) do
        if tile.building_type == position then
            bonus = bonus + 1
        end
    end

    local lawsuit = {type="lawsuit",
        tile=tile,
        influence=0,
        pros=1,
        cons=bonus,
        position=50,
        total=100,
        expiration_time=60.0 }
    tile.lawsuit = lawsuit
    table.insert(state.legal, lawsuit)
end

function build_tile(name)
    local tile = state.tiles[name]
    if tile.is_completed then
        return
    end

    state.moses.money = state.moses.money - tile.cost
    tile.is_started = true
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
end

function add_influence(action)
    if state.moses.influence <= 0 then
        return
    end
    state.moses.influence = state.moses.influence - 1
    action.influence = action.influence + 1
    if action_is_pro_user(action) then
        action.pros = action.pros + 1
    else
        action.cons = action.cons + 1
    end
end

function action_is_pro_user(action)
    return (action.type == "nomination" or action.type == "approval")
end

function update_legal(dt)
    local to_remove_idxs = {}
    for action_i, action in ipairs(state.legal) do
        local rate = (action.pros - action.cons) * dt
        action.position = math.max(action.position + rate, 0)
        action.expiration_time = action.expiration_time - dt
        if action.position > action.total then
            finish_legal_action(action)
            if action_is_pro_user then
                state.moses.influence = state.moses.influence + action.influence
            end
            table.insert(to_remove_idxs, action_i)
        elseif action.expiration_time < 0.0 then
            if action.type == "lawsuit" then
                action.tile.lawsuit = nil
            end
            print("legal action expired")
            if not action_is_pro_user then
                state.moses.influence = state.moses.influence + action.influence
            end
            table.insert(to_remove_idxs, action_i)
        end
    end

    for i = #to_remove_idxs, 1, -1 do
        table.remove(state.legal, to_remove_idxs[i])
    end
end

function update_government(dt)
    if state.world.year / 5 > state.mayor.audit_cycle_idx then
        state.mayor.audit_cycle_idx = state.mayor.audit_cycle_idx + 1
        if state.moses.money < 0 then
            lose()
        end
    end

    if state.world.year / 3 > state.mayor.nomination_cycle_idx then
        state.mayor.nomination_cycle_idx = state.mayor.nomination_cycle_idx + 1
        add_nomination("park")
        add_nomination("road")
        add_nomination("tenement")
    end
end

function add_nomination(position)
    local nomination = {type="nomination",
                         tile=nil,  -- this is a tile table reference not the tile id
                         subtype=position,
                         influence=0,
                         pros=1,
                         cons=0,
                         position=50,
                         total=100,
                         expiration_time=30.0 }
    table.insert(state.legal, nomination)
end

function update(dt)
    state.world.time = state.world.time + dt
    state.world.year = state.world.time / 60.0
    update_legal(dt)
    update_tiles(dt)
    update_government(dt)
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
