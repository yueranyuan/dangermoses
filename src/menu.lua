love.mouse.setVisible(true)

class "MenuButton" (Button) {
    font = lg.newFont(24),
    __init__ = function(self, pos, color, text, callback)
        self.color = color
        local shape = v(140, 50)
        self.text = text
        self:super(MenuButton).__init__(self, pos - shape / 2, shape, callback)
    end,

    draw = function(self)
        if self.clickable then
            local oldFont = lg.getFont()
            lg.setFont(self.font)
            self:super(MenuButton).draw(self)
            lg.setColor({255, 255, 255})
            local topleft = self.topleft
            local padding = v(5,(self.shape.y-lg.getFont():getHeight())/4)
            topleft = topleft + padding
            lg.setColor({0, 0, 0})
            lg.printf(self.text, topleft.x + padding.x, topleft.y + padding.y,
                self.shape.x - 2*padding.x, 'center')
            lg.setFont(oldFont)
        end
    end
}

function setup_menu()
    local bg = Image(v(0, 0), lg.newImage("grafix/menubg.png"))
    local buttons = {
        {
            MenuButton(v(0,0), {0, 255, 0}, "Tutorial", function()
                IS_TUTORIAL = true
                MAP_DATA = TUTORIAL_MAP_DATA
                require "src/game"
            end),
            MenuButton(v(0,0), {0, 255, 0}, "Game", function()
                IS_TUTORIAL = false
                MAP_DATA = REGULAR_MAP_DATA
                require "src/game"
            end),
            MenuButton(v(0,0), {255, 0, 0}, "Quit", function()
                love.event.quit()
            end),
        },
    }
    local W,H = lg.getDimensions()
    local pos = v(0,H-100)
    local size = v(W,100)
    make_grid(pos, size, buttons)
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
