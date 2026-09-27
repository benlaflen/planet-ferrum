-- Orbital Vehicle Deployment covers the cases the starter recycler and the standing construction-robot
-- request existed to prevent, so the request is cleared from saves that already have it. Factorio
-- removes the recycler entities itself once its prototype is gone.
local PLANET = "ferrum"
local PORT = PLANET .. "-roboport"

local planet = game.planets[PLANET]
local surface = planet and planet.surface
if not surface then return end

for _, port in pairs(surface.find_entities_filtered { name = PORT }) do
  local sections = port.get_logistic_sections()
  for index = #sections.sections, 1, -1 do sections.remove_section(index) end
end
