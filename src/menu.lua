love.mouse.setVisible(true)

function setup_menu()

end

setup_menu()

function love.mousepressed(x, y)
    if not mouseenabled then return end
    local mousepos = v(x, y)
    controller:move_mouse(mousepos)
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

    for _, obj in ipairs(Object.objects) do
        if obj:check_hover(controller.mousepos) then
            break
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
