local ROBOTICS = "ferrum-robotics-science-pack"

local function has_pack(tech, pack)
  if not tech.unit then return false end
  for _, ingredient in pairs(tech.unit.ingredients) do
    if (ingredient[1] or ingredient.name) == pack then return true end
  end
  return false
end

local function add_robotics(tech)
  if not tech or not tech.unit or has_pack(tech, ROBOTICS) then return end
  table.insert(tech.unit.ingredients, { ROBOTICS, 1 })
  tech.prerequisites = tech.prerequisites or {}
  table.insert(tech.prerequisites, ROBOTICS)
end

return { has_pack = has_pack, add_robotics = add_robotics }