--
-- Created by IntelliJ IDEA.
-- User: yueran
-- Date: 6/10/16
-- Time: 4:35 AM
-- To change this template use File | Settings | File Templates.
--

local logic = {inter={} }

--- factories for legal actions ---
local function add_grant(amount)
    local nomination = {type="grant",
        id=lume.UUID,
        tile=nil,
        amount=amount,
        influence=0,
        pros=0,
        cons=0,
        position=0,
        total=amount / 2,
        expiration_time=60.0}
    table.insert(state.legal, nomination)
end

local function add_suit(tile)
    if tile.lawsuit then
        tile.lawsuit.pros = tile.lawsuit.pros + 1
        return
    end

    log.trace("sued at "..tile.id)

    local bonus = 0
    if lume.find(state.moses.positions, tile.building_type) then
        bonus = bonus + 1
    end

    local lawsuit = {type="lawsuit",
        id=lume.UUID,
        tile=tile,
        influence=0,
        pros=1,
        cons=bonus,
        position=50,
        total=100,
        settle_price=2 * tile.cost,
        expiration_time=60.0}
    tile.lawsuit = lawsuit
    table.insert(state.legal, lawsuit)
end

local function add_nomination(position)
    local nomination = {type="nomination",
        id=lume.UUID,
        tile=nil,
        subtype=position,
        influence=0,
        pros=0,
        cons=0,
        position=0,
        total=1500,
        expiration_time=120.0 }
    table.insert(state.legal, nomination)
end

--- legal action management functions and related utilities ---
local function action_is_pro_user(action)
    return (lume.find({"nomination", "approval", "grant"}, action.type))
end

local function reset_tile(name)
    local tile = state.tiles[name]
    tile.is_started = 0
    tile.elapsed_construction_time = 0
end

local function finish_legal_action(action)
    -- do type specific things
    if action.type == "nomination" then
        table.insert(state.moses.positions, action.subtype)
    elseif action.type == "lawsuit" then
        -- get fined
        if (not action.tile.is_approved) then
            log.trace("get fined")
            state.moses.money = state.moses.money - action.tile.cost
        end
        log.trace("lost lawsuit")
        reset_tile(action.tile.id)
        action.tile.lawsuit = nil
    elseif action.type == "approval" then
        action.tile.is_approved = true
    elseif action.type == "grant" then
        state.moses.money = state.moses.money + action.amount
    else
        assert(false, "Other legal action types are not implemented")
    end

    -- clean up
    if action_is_pro_user then
        state.moses.influence = state.moses.influence + action.influence
    end
    action.finished = true
end

local function expire_legal_action(action)
    if action.type == "lawsuit" then
        action.tile.lawsuit = nil
    else
        if not action_is_pro_user(action) then
            state.moses.influence = state.moses.influence + action.influence
        end
    end
    action.finished = true
    log.trace("legal action expired")
end

--- Update ---
local function update_world(dt)
    state.world.time = state.world.time + dt
    state.world.year = state.world.time / 60.0
end

local function update_legal(dt)
    -- first remove all the finished actions
    for action_i, action in lume.ripairs(state.legal) do
        if action.finished then
            table.remove(state.legal, action_i)
        end
    end

    -- loop through remaining actions
    for action_i, action in ipairs(state.legal) do
        local rate = (action.pros - action.cons) * dt
        action.position = math.max(action.position + rate, 0)
        action.expiration_time = action.expiration_time - dt
        if action.position > action.total then
            finish_legal_action(action)
            if action_is_pro_user(action) then
                state.moses.influence = state.moses.influence + action.influence
            end
        elseif action.expiration_time < 0.0 then
            expire_legal_action(action)
        end
    end
end

local function update_tile(dt, tile)
    if tile.is_completed then return end
    if not tile.is_started then return end

    tile.is_stalled = state.moses.money <= 0

    if tile.is_stalled then
        state.moses.popularity = state.moses.popularity - dt
    else
        -- randomly start suits
        if tile.illegality * dt > math.random() then
            add_suit(tile)
        end
        -- move construction forward
        tile.elapsed_construction_time = tile.elapsed_construction_time + dt
        -- charge money
        local dcost = tile.cost * dt / tile.construction_time
        state.moses.money = state.moses.money - dcost
        -- construction finished
        if tile.elapsed_construction_time > tile.construction_time then
            state.moses.popularity = state.moses.popularity + tile.popularity
            tile.is_completed = true
        end
    end
end

local function update_tiles(dt)
    lume.each(state.tiles, lume.fn(update_tile, dt))
end

local function update_moses(dt)
    state.moses.popularity = state.moses.popularity - 0.1 * dt

    -- compute the real amount of money available i.e. true_balance
    local future_spending = utils.sum(lume.map(state.tiles, function(t)
        if not t.is_started then
            return 0
        else
            return t.cost * (1.0 - (t.elapsed_construction_time / t.construction_time))
        end
    end))
    state.moses.true_balance = state.moses.money - future_spending
end

local function new_year()
    local int_year = math.floor(state.world.year)

    -- add my yearly budget for my positions
    lume.each(state.moses.positions, function()
        state.moses.money = state.moses.money + consts.YEARLY_BUDGET
    end)

    -- add one small grant and one big grant
    if int_year % consts.GRANT_CYCLE_YEARS == 0 then
        add_grant(lume.randomchoice(consts.SMALL_GRANTS))
        add_grant(lume.randomchoice(consts.BIG_GRANTS))
    end

    -- nominations for all the positions I don't have yet
    if int_year % consts.NOMINATION_CYCLE_YEARS == 0 then
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

function logic.update(dt)
    update_world(dt)
    update_tiles(dt)
    update_legal(dt)
    update_moses(dt)
    if state.world.year > state.world.year_idx then
        state.world.year_idx = state.world.year_idx + 1
        new_year()
    end
end


---- Call these functions to send user input -----

function logic.inter.build_tile(name)
    if state.moses.money <= 0 then return end

    local tile = state.tiles[name]
    if tile.is_started or tile.is_completed then
        return
    end

    tile.is_started = true
    state.moses.influence = state.moses.influence + tile.influence
end

function logic.inter.settle(action)
    if state.moses.money - action.settle_price >= 0 then
        state.moses.money = state.moses.money - action.settle_price
        expire_legal_action(action)
    end
end

function logic.inter.add_influence(action)
    if state.moses.influence <= 0 then return end

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
