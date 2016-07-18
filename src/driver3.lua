lume = require "extern/lume"
log = require "extern/log"
class = require "extern/slither"
require "src/gameobject"
require "src/map"
require "src/legal"
vector = require "extern/vector"
vec = vector
v = vec


class "Player" {
    __init__ = function(self)
        self.influence = 0
        self.haters = 0
        self.money = 0
        self.mouse_pos = v(0, 0)
        self.building_queue = {}
    end,

    update = function(self, dt)
        if #self.building_queue > 0 and building == nil then
            building = table.remove(self.building_queue, 1)
            building.state = "hovering"
        end

        if building ~= nil then
            building.pos = self.mouse_pos
            for _, pu in pairs(powerups) do
                if pu:collide(building) then
                    pu:hover(building)
                end
            end
        end
    end
}

function love.load()
    powerups = {}
    for i = 1, 100 do
        local pu = Powerup(v(lume.random(0, 500), lume.random(0, 600)),
            lume.randomchoice(lume.keys(Building.TYPES)))
        table.insert(powerups, pu)
    end
    player = Player()
    local building = Building("eagle", "park")
    table.insert(player.building_queue, building)
end

function draw_hud()
    love.graphics.setColor(0, 0, 0, 255)
    love.graphics.print("influence: " .. player.influence .. " money: " .. player.money .. " haters: " .. player.haters)
end

function love.mousemoved(x, y, dx, dy, button, istouch)
    player.mouse_pos = v(x, y)
end

function love.mousepressed(x, y, dx, dy, button, istouch)
    if x < 500 then
        if building ~= nil then
            building.pos = v(x, y)
            for _, pu in pairs(powerups) do
                if pu:collide(building) then
                    pu:hit(building)
                end
            end
            building:build()
            building = nil
        end
    else
        for _, obj in pairs(Object.objects) do
            if obj.__class__ == Slot then
                if obj:collide_point(v(x, y)) then
                    obj:influence()
                end
            end
        end
    end
end

function love.update(dt)
    player:update(dt)

    legislationTable:update(dt)
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
