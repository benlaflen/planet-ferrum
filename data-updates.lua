local science = require("prototypes.science")
require("prototypes.compatibility")

-- Vulcanus, Fulgora and Gleba packs.
local PLANETARY = { "metallurgic-science-pack", "electromagnetic-science-pack", "agricultural-science-pack" }

local recipes = data.raw.recipe
if recipes["tesla-turret"] then
  table.insert(recipes["tesla-turret"].ingredients, { type = "item", name = "ferrum-rare-earth-oxide", amount = 10 })
end
if recipes["speed-module-3"] then
  table.insert(recipes["speed-module-3"].ingredients, { type = "item", name = "ferrum-rare-earth-oxide", amount = 2 })
end
if recipes["cryogenic-plant"] then
  table.insert(recipes["cryogenic-plant"].ingredients, { type = "item", name = "ferrum-rare-earth-magnet", amount = 10 })
end
if recipes["fusion-reactor"] then
  table.insert(recipes["fusion-reactor"].ingredients, { type = "item", name = "ferrum-rare-earth-magnet", amount = 200 })
end
local spidertron = recipes["spidertron"]
if spidertron then
  -- Fluid ingredient: no longer hand-craftable, needs assembler 2+.
  spidertron.categories = { "crafting-with-fluid" }
  table.insert(spidertron.ingredients, { type = "fluid", name = "ferrum-rare-earth-solution", amount = 1000 })
end

for _, tech in pairs(data.raw.technology) do
  local all = tech.unit ~= nil
  for _, pack in pairs(PLANETARY) do all = all and science.has_pack(tech, pack) end
  if all then science.add_robotics(tech) end
end