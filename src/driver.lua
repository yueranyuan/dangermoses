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
vector = require "extern/vector"
vec = vector
v = vec

class "Player" {
    __init__ = function(self)
        self.big_dudes = 0
        self.popularity = 50
        self.built_cells = 0
        self.building_queue = {}
        self.mousepos = v(0, 0)
        self.color = {255, 255, 255}
    end,

    update = function(self)
        -- get the next building to build
        if #self.building_queue > 0 and self.building == nil then
            self.building = table.remove(self.building_queue, 1)
            self.building.state = "hovering"
        end

        -- get the appropriate number of big dudes
        while self.built_cells >= CELL_PER_BIG_DUDE do
            self.built_cells = self.built_cells - CELL_PER_BIG_DUDE
            self.big_dudes = self.big_dudes + 1
        end
    end,

    hold_building = function(self, building)
        table.insert(self.building_queue, building)
    end,

    update_building_position = function(self, pos)
        if self.building ~= nil then
            local coord_center = pos / Map.scale - self.building:get_grid_shape() / 2
            self.building.coord = v(lume.round(coord_center.x), lume.round(coord_center.y))
        end
    end,

    place_building = function(self, mouse_pos)
        self:update_building_position(mouse_pos)
        local buildable = self.building:is_buildable(self)
        if buildable then
            self.building:build()
            hud:set_message("success in placing building", HUD.SUCCESS)
        else
            hud:set_message("failed to build this building", HUD.FAIL)
        end
        building_button_tray:resolve_active_button(buildable)
        self.building = nil
    end,

    drop_building = function(self)
        if self.building == nil then
            return
        end
        building_button_tray:resolve_active_button(false)
        hud:set_message("building canceled", HUD.FAIL)
        self.building = nil
    end,
}

function love.load()
    -- all non-imported non-const globals should be made here

    -- the order we make things is important because I haven't implemented z-ordering in the
    -- gameobject class so things are drawn in the order they are added

    -- make players
    AIs = {I_AM_AN_AI_PLAYER}
    player = Player()

    -- make map side of screen
    map = Map()

    -- make committee side of screen
    committee_tray = CommitteeTray(600)

    -- draw gui elements
    building_button_tray = BuildingButtonTray()
    hud = HUD()
end

function love.mousemoved(x, y)
    local mousepos = v(x, y)
    player.mousepos = mousepos
    player:update_building_position(mousepos)
end

function love.keypressed(key)
    if key == "escape" then
        player:drop_building()
    end
end

function love.mousepressed(x, y)
    local mousepos = v(x, y)
    for _, obj in pairs(Object.objects) do
        obj:check_click(mousepos)
    end

    if x < 500 then  -- on the map side of the screen
        if player.building ~= nil then
            player:place_building(mousepos)
        end
    else -- on the committee side of the screen
    end
end

function love.update(dt)
    player:update(dt)

    for obj_i, obj in pairs(Object.objects) do
        obj:update(dt)
        if obj.dead then
            table.remove(Object.objects, obj_i)
        end
    end
end

function love.draw()
    love.graphics.setColor(155, 155, 155, 255)
    love.graphics.rectangle('fill', 0, 0, 800, 800)
    for _, obj in pairs(Object.objects) do
        obj:draw()
    end
end
