love.mouse.setVisible(false)
love.graphics.setDefaultFilter("nearest", "nearest", 1)
--love.window.setFullscreen(true)
lg = love.graphics
lume = require "extern/lume"
log = require "extern/log"
class = require "extern/slither"
utils = require "src/utils"
require "src/consts"
require "src/gameobject"
require "src/legal"
require "src/map"
require "src/gui"
require "src/player"
require "src/plan"
vector = require "extern/vector"
vec = vector
v = vec

function love.load()
    -- all non-imported non-const globals should be made here

    -- the order we make things is important because I haven't implemented z-ordering in the
    -- gameobject class so things are drawn in the order they are added

    -- make players
    TAMMANY = Agent('TAMMANY', {30, 30, 30})
    AIs = {Agent('AI1', {255, 0, 255})}
    for _, ai in ipairs(AIs) do
        ai:make_ai()
    end
    player = Agent('player', {255, 255, 255})
    --player:make_ai()
    controller = Controller()

    -- make map side of screen
    map = Map(MAP_WIDTH, MAP_HEIGHT, MAP_SCALE)

    -- make committee side of screen
    local committee_class = Committee
    if NEUTRAL_FIRST then
        committee_class = Committee2
    end
    committee_tray = CommitteeTray(600, committee_class)

    -- draw gui elements
    building_button_tray = BuildingButtonTray()
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
    controller:click(mousepos)

    for _, obj in ipairs(Object.objects) do
        obj:check_click(mousepos)
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
    for _, obj in ipairs(Object.objects) do
        obj:draw()
    end
end
