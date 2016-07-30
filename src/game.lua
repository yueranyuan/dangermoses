love.mouse.setVisible(false)

function setup_level()
    Object.objects = {}

    -- make players
    TAMMANY = Agent('TAMMANY', {30, 30, 30})
    AIs = {}
    for _, ai in ipairs(AIs) do
        ai:make_ai()
    end
    player = Agent('player', {255, 255, 255})
    --player:make_ai()
    controller = Controller()

    -- make map side of screen
    map = Map(MAP_WIDTH, MAP_HEIGHT, MAP_SCALE)

    -- make committee side of screen
    building_button_tray = BuildingButtonTray()
    powerup_tray = PowerupTray({[StrongArm]=0, [Shutdown]=0, [GoodPublicity]=0, [Resilience]=1, [Lackey]=3, [Mislabel]=5, [Appeal]=1})
    government = Government(GAME_WIDTH - 250)

    -- draw gui elements
    hud = HUD()
    overlay = Overlay(v(500, 300))

      overlay:set_once("Welcome! Take a quick look at the map. There's a lot to take in!\n"..
        "Colors on the ground show which committee controls that area.\n"..
        "To get your project built, each committee whose land you're building on\n has to approve it.",
        "grafix/tutorial/overall_map.png", 1)
      Timer.after(6, function()
      overlay:set_once("The people on the map can be either detractors or supporters.\n"..
        "If they're the same color as your project they will support it.\n"..
        "If they're a different color they will become attached to the project as\n"..
        "detractors and jump off onto any committees it passes through!",
        "grafix/tutorial/overall_map.png", 1)
      end)

      Timer.after(10, function()
      overlay:set_once("To get started, click on the buildings on the right.\n"..
        "You have a choice between different types of buildings.\n"..
        "Try to pick one that you can fit onto ground that's the same color.",
        "grafix/tutorial/first_building.png", 1)
      end)
end
setup_level()

function love.mousemoved(x, y)
    controller:move_mouse(v(x, y))
end

function love.keypressed(key)
    if key == "escape" then
        controller:back()
    elseif key == 'r' then
        -- TODO: remove
        setup_level()
    end
end

function love.mousepressed(x, y)
    if not mouseenabled then return end
    local mousepos = v(x, y)
    controller:move_mouse(mousepos)
    sfx_click:play()

    -- clicking overlays
    if overlay.on then
        overlay.okay_button:check_click(mousepos)
        return
    end

    local clicked = false
    for _, obj in ipairs(Object.objects) do
        if obj:check_click(mousepos) then
            clicked = true
            break
        end
    end

    if player.power then
        for _, obj in ipairs(player.power.possible_targets) do
            if obj:collide_point(mousepos) then
                if player.power:provide_target(obj) then
                    player:use_power(player.power, player.power.target)
                end
                clicked = true
                break
            end
        end
    end

    if not clicked then
        controller:click(mousepos)
        if powerup_tray.buy_mode then
            powerup_tray.buy_mode = false
        end
    end
end

function love.update(dt)
    Timer.update(dt)
    player:update(dt)

    for obj_i, obj in ipairs(Object.objects) do
        obj:update(dt)
        if obj.dead then
            table.remove(Object.objects, obj_i)
        end
    end

    for _, obj in ipairs(Object.objects) do
        if obj:check_hover(controller.mousepos) then
            break
        end
    end
end

function love.draw()
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('fill', 0, 0, 800, 800)

    local draw_orders = {}
    for _, obj in ipairs(Object.objects) do
        if obj.parent then
            obj.darken = obj.parent.darken
        else
            obj.darken = player.power and lume.find(player.power.possible_targets, obj) == nil
        end
        if draw_orders[obj.z_order] == nil then
            draw_orders[obj.z_order] = {obj }
        else
            table.insert(draw_orders[obj.z_order], obj)
        end
    end

    local z_ordering = lume.keys(draw_orders)
    table.sort(z_ordering)
    for _, z in ipairs(z_ordering) do
        for _, obj in ipairs(draw_orders[z]) do
            if obj.shown then
                obj:draw()
            end
        end
    end

    hud:draw_mouse(overlay.on)
end
