class "Sound" {
    __init__ = function(self, fn, mode)
        if not pcall(function()
            self.sound = love.audio.newSource(fn, mode)
        end) then
            self.sound = 'none'
            log.warn('could not load sound '..fn)
        end
    end,

    __getattr__ = function(self, key)
        if self.sound == 'none' then
            log.warn("trying to get property '"..key.."' of sound which was not loaded successfully")
            return function() end
        end

        return function(arg1, arg2, arg3, arg4, arg5)
            if not pcall(function()
                log.trace(SOUND_ON)
                if not SOUND_ON then return end
                local func = self.sound[key]
                if arg1 == self then
                    arg1 = self.sound
                end
                func(arg1, arg2, arg3, arg4, arg5)
            end) then
                log.warn("wrapped sound function '"..key.."' failed")
            end
        end
    end,
}
