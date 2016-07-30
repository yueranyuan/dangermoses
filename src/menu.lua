love.mouse.setVisible(true)

class "MenuButton" (Button) {
    __init__ = function(self, pos, color, text, callback)
        self.color = color
        local shape = v(140, 50)
        self.text = text
        self:super(MenuButton).__init__(self, pos - shape / 2, shape, callback)
    end,

    draw = function(self)
        if self.clickable then
            self:super(MenuButton).draw(self)
            lg.setColor({255, 255, 255})
            lg.printf(self.text, self.pos.x, self.pos.y + self.shape.y / 2 - 10, self.shape.x, 'center')
        end
    end
}

function setup_menu()
    Image(v(0, 0), lg.newImage("grafix/menubg.png"))

    MenuButton(v(GAME_WIDTH / 2 - 400, GAME_HEIGHT - 100), {0, 255, 0}, "Tutorial", function()
        IS_TUTORIAL = true
        MAP_DATA = TUTORIAL_MAP_DATA
        require "src/game"
    end)

    MenuButton(v(GAME_WIDTH / 2, GAME_HEIGHT - 100), {0, 255, 0}, "Game", function()
        IS_TUTORIAL = false
        MAP_DATA = REGULAR_MAP_DATA
        require "src/game"
    end)

    MenuButton(v(GAME_WIDTH / 2 + 400, GAME_HEIGHT - 100), {255, 0, 0}, "Quit", function()
        love.event.quit()
    end)
end
setup_menu()

function love.mousepressed(x, y)
    if not mouseenabled then return end
    local mousepos = v(x, y)
    sfx_click:play()

    for _, obj in ipairs(Object.objects) do
        if obj:check_click(mousepos) then
            break
        end
    end
end


function love.update(dt)
    Timer.update(dt)

    for obj_i, obj in ipairs(Object.objects) do
        obj:update(dt)
        if obj.dead then
            table.remove(Object.objects, obj_i)
        end
    end
end


function love.draw()
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('fill', 0, 0, 800, 800)

    local draw_orders = {}
    for _, obj in ipairs(Object.objects) do
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
end
