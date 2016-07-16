lume = require "extern/lume"
log = require "extern/log"
local class = require "extern/slither"
vector = require "extern/vector"
vec = vector
v = vec

local objects = {}

class "Object" {
    --- all Objects must have a pos and shape
    --- name, color are optional and default to empty and green
    super__init__ = function(self, pos, shape)
        self.pos = pos
        self.shape = shape
        if not self.color then
            self.color = {0, 255, 0, 255 }
        end
        if not self.name then
            self.name = ""
        end
        self.dead = false
        table.insert(objects, self)
    end,

    __properties__ = {
        --- these functions are like functions decorated with @property() in Python
        --- they are used to implement properties
        center = function(self)
            return self.pos - self.shape / 2
        end
    },

    __getattr__ = function(self, key)
        if self.__properties__[key] == nil then
            return nil
        end
        return self.__properties__[key](self)
    end,

    update = function(self, dt)
        --- to be overridden
    end,

    draw = function(self)
        love.graphics.setColor(self.color)
        love.graphics.rectangle("fill", self.pos.x, self.pos.y + 5, self.shape.x, self.shape.y)
        love.graphics.setColor({255, 255, 255, 255})
        love.graphics.print(self.name, self.pos.x, self.pos.y + self.shape.y / 2)
    end,

    collides = function(self, target)
        return (self.pos.x <= target.x and self.pos.x + self.shape.x >= target.x
                and self.pos.y <= target.y and self.pos.y + self.shape.y >= target.y)
    end,

    destroy = function(self)
        self.dead = true
    end
}

class "Place" (Object) {
    __init__ = function(self, name, pos)
        self.name = name
        self.color = {0, 255, 0, 255}
        self.state = "building"
        self.progress = 0
        self.duration = 100
        self:super__init__(pos, vec(50, 50))
    end,

    update = function(self, dt)
        if self.state == "building" then
            self.progress = self.progress + dt
        end
    end,

    build = function(self)
        self.color = {255, 0, 0, 255}
    end,
}

class "Moses" (Object) {
    __init__ = function(self, pos)
        self.name = "moses"
        self.color = {255, 255, 0, 255 }
        self.speed = 400.0
        self.target = nil
        self:super__init__(pos, v(10, 10))
    end,

    update = function(self, dt)
        if self.target ~= nil then
            local delta = self.speed * dt
            if self.pos:dist(self.target) <= delta then
                self.pos = self.target
            else
                local direction = (self.target - self.pos):normalized()
                self.pos = self.pos + direction * delta
            end
        end
    end,

    move_to = function(self, target)
        self.target = target
    end
}

function love.mousepressed(x, y, button, istouch)
    -- click on building
    for _, place in pairs(places) do
        if (place:collides(v(x, y))) then
            place:build()
            break
        end
    end

    -- click on ground
    moses:move_to(v(x, y))
end

function love.load()
    places = {Place("park1", v(321, 200)), Place("park2", v(200, 200)) }
    moses = Moses(v(320, 200))
end

function love.update(dt)
    for _, obj in pairs(objects) do
        obj:update(dt)
        if obj.dead then
            table.remove(objects, obj_i)
        end
    end
end

function love.draw(dt)
    for _, obj in pairs(objects) do
        obj:draw()
    end
end