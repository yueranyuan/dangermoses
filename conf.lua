require 'src/consts'

function love.conf(t)
    t.version = "0.10.1"
    t.window.icon = "grafix/game_icon.png"
    t.window.title = "The Moses Dangerous Game"
    t.window.width = GAME_WIDTH
    t.window.height = GAME_HEIGHT
end

