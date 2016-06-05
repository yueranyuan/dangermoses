function draw_city_map()
  local screen_width = love.graphics.getWidth()
  local screen_height = love.graphics.getHeight()

  local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'

  for k, v in pairs(state.tiles) do
    local letter = string.sub(k, 1, 1)
    local y_value = string.sub(k, 2, 2)
    local x_value = string.find(alphabet, letter)
    love.graphics.print(letter..y_value, x_value * 50, y_value * 50)
    --love.graphics.rectangle()
  end
end
