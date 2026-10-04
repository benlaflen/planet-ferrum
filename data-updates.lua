local science = require("prototypes.science")
require("prototypes.compatibility")

-- Vulcanus, Fulgora and Gleba packs.
local PLANETARY = { "metallurgic-science-pack", "electromagnetic-science-pack", "agricultural-science-pack" }

local recipes = data.raw.recipe
if recipes["cryogenic-plant"] then
  table.insert(recipes["cryogenic-plant"].ingredients, { type = "item", name = "ferrum-rare-earth-magnet", amount = 10 })
end
if recipes["fusion-reactor"] then
  table.insert(recipes["fusion-reactor"].ingredients, { type = "item", name = "ferrum-rare-earth-magnet", amount = 200 })
end

for _, tech in pairs(data.raw.technology) do
  local all = tech.unit ~= nil
  for _, pack in pairs(PLANETARY) do all = all and science.has_pack(tech, pack) end
  if all then science.add_robotics(tech) end
end