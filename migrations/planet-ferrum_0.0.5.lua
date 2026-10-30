-- Daytime used to be frozen and driven by script; release it and apply the darker night.
local planet = game.planets["ferrum"]
local surface = planet and planet.surface
if not surface then return end

if storage.flash_on and storage.daytime then surface.daytime = storage.daytime end
surface.freeze_daytime = false
surface.min_brightness = 0.12
storage.flash_on, storage.flash_pulses = false, 0