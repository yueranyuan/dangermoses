love.mouse.setVisible(false)
love.graphics.setDefaultFilter("nearest", "nearest", 1)
--love.window.setFullscreen(true)
lg = love.graphics
vector = require "extern/vector"
Timer = require "extern/timer"
vec = vector
v = vec
lume = require "extern/lume"
log = require "extern/log"
class = require "extern/slither"
csv = require "extern/csv"
utils = require "src/utils"
require "src/consts"
require "src/sound"
require "src/gameobject"
require "src/powerup"
require "src/gui"
require "src/legal"
require "src/map"
require "src/player"
require "src/plan"

mouseenabled = true

class "progress" {
    dict = {},

    __getattr__ = function(self, key)
        if not IS_TUTORIAL then
            return true
        end
        if not self.dict[key] then
            self.dict[key] = true
            return false
        else
            return true
        end
    end
}

function load_sounds()
    -- "Dirty" version of the music has the 1930s effects on it.
    music = Sound("sfx/bg_music_2_dirty.ogg")
    music:setLooping(true)
    music:setVolume(0.8) -- Dirty music is what plays normally.

    -- "Clean" version is the original unprocessed recording.
    music_clean = Sound("sfx/bg_music_2_clean.ogg")
    music_clean:setLooping(true)
    music_clean:setVolume(0) -- Set volume to zero. We'll crossfade them on win.
    music_clean:play()
    music:play()

    ambience = Sound("sfx/ambience_road.ogg")
    ambience:setLooping(true)
    ambience:setVolume(0.3)
    ambience:play()
    ambience:setLooping(true)

    sfx_click = Sound("sfx/typewriter_hit.wav", "static")
    sfx_jackhammer = Sound("sfx/build_jackhammer.wav", "static")
    sfx_mayor_pass = Sound("sfx/mayor_approve_stamp.wav", "static")
    sfx_mayor_reject = Sound("sfx/mayor_fail_paper_rip.wav", "static")
    sfx_next = Sound("sfx/next_button_typewriter.wav", "static")
    sfx_commissioner = Sound("sfx/commissioner_cheer.wav", "static")
end

function love.load()
    load_sounds()
end

require "src/game"

