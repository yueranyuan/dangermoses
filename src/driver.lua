love.mouse.setVisible(false)
love.graphics.setDefaultFilter("nearest", "nearest", 1)
--love.window.setFullscreen(true)
lg = love.graphics
vector = require "extern/vector"
vec = vector
v = vec
lume = require "extern/lume"
log = require "extern/log"
class = require "extern/slither"
utils = require "src/utils"
require "src/consts"
require "src/gameobject"
require "src/powerup"
require "src/legal"
require "src/map"
require "src/gui"
require "src/player"
require "src/plan"

function love.load()
    -- all non-imported non-const globals should be made here

    -- the order we make things is important because I haven't implemented z-ordering in the
    -- gameobject class so things are drawn in the order they are added

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
    government = Government(GAME_WIDTH - 200)

    -- draw gui elements
    building_button_tray = BuildingButtonTray()
    powerup_tray = PowerupTray()
    hud = HUD()
end

function love.mousemoved(x, y)
    controller:move_mouse(v(x, y))
end

function love.keypressed(key)
    if key == "escape" then
        controller:back()
    end
end

function love.mousepressed(x, y)
    local mousepos = v(x, y)
    controller:move_mouse(mousepos)

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
    end
end

function love.update(dt)
    player:update(dt)

    for obj_i, obj in ipairs(Object.objects) do
        obj:update(dt)
        if obj.dead then
            table.remove(Object.objects, obj_i)
        end
    end
end

function love.draw()
    love.graphics.setColor(155, 155, 155, 255)
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
            obj:draw()
        end
    end
end
