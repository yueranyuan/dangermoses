class "Object" {
    objects = {},

    --- all Objects must have a pos and shape
    --- name, color are optional and default to empty and white
    __init__ = function(self, pos, shape)
        if pos == nil then
            pos = v(0, 0)
        end
        if shape == nil then
            shape = v(1, 1)
        end

        self.pos = pos
        if self.color == nil then
            self.color = { 255, 255, 255, 255 }
        end
        if self.scale == nil then
            self.scale = 1
        end
        if self.name == nil then
            self.name = ""
        end
        self.dead = false
        if self.img ~= nil then
            self.grid = self.get_collision_map(self.img)
            self.shape = v(self.img:getWidth() * self.scale, self.img:getHeight() * self.scale)
        else
            self.shape = shape
        end
        if self.children == nil then
            self.children = {}
        end
        table.insert(Object.objects, self)
        if self.shown == nil then
            self.shown = true
        end
    end,

    super__init__ = function(self, pos, shape)  -- LOL I don't have super
        if pos == nil then
            pos = v(0, 0)
        end
        if shape == nil then
            shape = v(1, 1)
        end

        self.pos = pos
        if self.color == nil then
            self.color = { 255, 255, 255, 255 }
        end
        if self.scale == nil then
            self.scale = 1
        end
        if self.name == nil then
            self.name = ""
        end
        self.dead = false
        if self.img ~= nil then
            self.grid = self.get_collision_map(self.img)
            self.shape = v(self.img:getWidth() * self.scale, self.img:getHeight() * self.scale)
        else
            self.shape = shape
        end
        if self.children == nil then
            self.children = {}
        end
        table.insert(Object.objects, self)
        if self.shown == nil then
            self.shown = true
        end
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

    draw = function(self, offset)
        self:superdraw(offset)
    end,

    superdraw = function(self, offset)
        if not self.shown then
            return
        end
        love.graphics.setColor(self.color)
        local pos
        if offset ~= nil then
            pos = self.pos + offset
        else
            pos = self.pos
        end
        if self.img ~= nil then
            love.graphics.draw(self.img, pos.x, pos.y, 0, self.scale)
        else
            love.graphics.rectangle("fill", pos.x, pos.y, self.shape.x, self.shape.y)
            love.graphics.setColor({ 255, 255, 255, 255 })
            love.graphics.print(self.name, pos.x, pos.y + self.shape.y / 2)
        end
    end,

    set_parent = function(self, parent)
        self.parent = parent
        if parent.children == nil then parent.children = {} end
        table.insert(parent.children, self)
    end,

    collide_point = function(self, target)
        return (self.pos.x <= target.x and self.pos.x + self.shape.x >= target.x
                and self.pos.y <= target.y and self.pos.y + self.shape.y >= target.y)
    end,

    collide_boxes = function(self, b)
        return (self.pos.x <= b.pos.x + b.pos.shape.x and self.pos.x + self.pos.shape.x >= b.pos.x and
                self.pos.y <= b.pos.y + b.pos.shape.y and self.pos.y + self.pos.shape.y >= b.pos.y)
    end,

    collide = function(self, b)
        if self.grid ~= nil and b.grid ~= nil then  -- pixel perfect collision
            --- TODO: support scale
            return Object.collide_imgs(self, b)
        elseif b.shape ~= nil then
            self:collide_boxes(b)
        elseif b.pos ~= nil then
            self:collide_point(b.pos)
        elseif b.x ~= nil and b.y ~= nil then
            self:collide_point(b)
        else
            if b.grid ~= nil and self.grid == nil then
                assert(false, 'b has grid but not shape, pos, x, or y and self does not have grid')
            elseif self.grid == nil then
                assert(false, 'b does not have grid, shape, pos, x, or y')
            else
                assert(false, 'this should never happen')
            end
        end
    end,

    destroy = function(self)
        self.dead = true
    end,

    check_click = function(self, mousepos)
        if self.on_click == nil then return end
        if self:collide_point(mousepos) then
            self:on_click(mousepos)
        end
    end,

    --- method functions
    collide_imgs = function(a, b)
        return Object.collide_maps(a.grid, b.grid, b.pos - a.pos)
    end,

    get_collision_map = function(img)
        local pixels = img:getData()
        local grid = {}
        for y = 0, pixels:getHeight() - 1 do
            local row = {}
            for x = 0, pixels:getWidth() - 1 do
                local _, _, _, a = pixels:getPixel(x, y)
                row[x+1] = (a == 255)
            end
            grid[y+1] = row
        end
        return grid
    end,

    collide_maps = function(map1, map2, offset)
        for y = 1, #map1 do
            local y1 = y - lume.round(offset.y)
            if y1 >= 1 and y1 <= #map2 then
                for x = 1, #(map1[1]) do
                    local x1 = x - lume.round(offset.x)
                    if x1 >= 1 and x1 <= #(map2[1]) then
                        if map2[y1][x1] and map1[y][x] then
                            return true
                        end
                    end
                end
            end
        end
        return false
    end,
}
