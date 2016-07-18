class "Object" {
    objects = {},


    --- all Objects must have a pos and shape
    --- name, color are optional and default to empty and white
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
        if self.name == nil then
            self.name = ""
        end
        self.dead = false
        if self.img ~= nil then
            self.grid = self.get_collision_map(self.img)
            self.shape = v(self.img:getWidth(), self.img:getHeight())
        else
            self.shape = shape
        end
        if self.children == nil then
            self.children = {}
        end
        table.insert(Object.objects, self)
        if self.parent ~= nil then
            table.insert(self.parent.children, self)
        end
        if self.shown == nil then
            self.shown = true
        end
        if self.scale == nil then
            self.scale = 1
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
            love.graphics.rectangle("fill", pos.x, pos.y + 5, self.shape.x, self.shape.y)
            love.graphics.setColor({ 255, 255, 255, 255 })
            love.graphics.print(self.name, pos.x, pos.y + self.shape.y / 2)
        end
    end,

    collide_point = function(self, target)
        return (self.pos.x <= target.x and self.pos.x + self.shape.x >= target.x
                and self.pos.y <= target.y and self.pos.y + self.shape.y >= target.y)
    end,

    collide = function(self, b)
        --- TODO: support scale
        return Object.collide_imgs(self, b)
    end,

    destroy = function(self)
        self.dead = true
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
                row[x] = (a == 255)
            end
            grid[y] = row
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
