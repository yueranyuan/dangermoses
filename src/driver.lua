lg = love.graphics
lume = require "extern/lume"
log = require "extern/log"
class = require "extern/slither"
require "src/consts"
require "src/gameobject"
require "src/legal"
require "src/map"
vector = require "extern/vector"
vec = vector
v = vec

class "Player" {
    __init__ = function(self)
        self.big_dudes = 0
        self.popularity = 50
        self.built_cells = 0
        self.building_queue = {}
        self.color = {255, 255, 255}
    end,

    update = function(self, dt)
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
            self.building.coord = v(lume.round(pos.x / Map.scale), lume.round(pos.y / Map.scale))
        end
    end,

    place_building = function(self, mouse_pos)
        self:update_building_position(mouse_pos)
        if self.building:is_buildable(self) then
            self.building:build()
            self.building = nil
        end
    end,

    drop_building = function(self)
        self.building = nil
    end
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
    building_buttons = {}
    for type_i, type in ipairs(lume.keys(Map.TYPES)) do
        local b_but = BuildingButton(v(200 + (type_i - 1) * BuildingButton.BUTTON_SIZE,
                                       GAME_HEIGHT - BuildingButton.BUTTON_SIZE - 10),
                                     type)
        table.insert(building_buttons, b_but)
    end

    -- make committee side of screen
    committees = {}
    for type_i, type in ipairs(lume.keys(Map.TYPES)) do
        local com = Committee(v(600, (type_i - 1) * Committee.HEIGHT), type)
        table.insert(committees, com)
    end
end

function draw_hud()
    love.graphics.setColor(255, 255, 255, 255)
    love.graphics.print("press esc to drop building ", 0, 0)
    love.graphics.print("popularity: " .. player.popularity, 0, 20)
    for i = 1,player.big_dudes do
        love.graphics.rectangle('fill', i * 15, 40, 10, 10)
    end
end

function love.mousemoved(x, y, dx, dy, button, istouch)
    player:update_building_position(v(x, y))
end

function love.keypressed(key, scancode, isrepeat)
    if key == "escape" then
        player:drop_building()
    end
end

function love.mousepressed(x, y, dx, dy, button, istouch)
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
    draw_hud()
end
