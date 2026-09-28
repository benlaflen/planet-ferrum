local LEGACY = require("prototypes.version")

-- Recipes are written with 2.1's categories; 2.0 only reads category and additional_categories.
if LEGACY then
  for _, recipe in pairs(data.raw.recipe) do
    if recipe.categories then
      recipe.category = recipe.categories[1]
      recipe.additional_categories = { table.unpack(recipe.categories, 2) }
      recipe.categories = nil
    end
  end
end

-- 2.1 renamed a product's probability to independent_probability.
if not LEGACY then
  for name, recipe in pairs(data.raw.recipe) do
    if name:find("^ferrum%-") then
      for _, result in pairs(recipe.results or {}) do
        if result.probability then
          result.independent_probability, result.probability = result.probability, nil
        end
      end
    end
  end
end

local function categories_of(recipe)
  if not LEGACY then return recipe.categories or { "crafting" } end
  local list = { recipe.category or "crafting" }
  for _, category in pairs(recipe.additional_categories or {}) do table.insert(list, category) end
  return list
end

local function add_category(recipe, category)
  for _, existing in pairs(categories_of(recipe)) do
    if existing == category then return end
  end
  if LEGACY then
    recipe.additional_categories = recipe.additional_categories or {}
    table.insert(recipe.additional_categories, category)
  else
    recipe.categories = recipe.categories or { "crafting" }
    table.insert(recipe.categories, category)
  end
end

local BELT_TYPES = { "transport-belt", "underground-belt", "splitter", "lane-splitter", "loader", "loader-1x1", "linked-belt" }

for _, type in pairs(BELT_TYPES) do
  for _, prototype in pairs(data.raw[type] or {}) do
    prototype.surface_conditions = prototype.surface_conditions or {}
    table.insert(prototype.surface_conditions, { property = "ferrum-belt-clearance", max = 0 })
  end
end

for _, recipe in pairs(data.raw.recipe) do
  local counts = { item_in = 0, fluid_in = 0, item_out = 0, fluid_out = 0 }
  for _, ingredient in pairs(recipe.ingredients or {}) do
    local key = ingredient.type == "fluid" and "fluid_in" or "item_in"
    counts[key] = counts[key] + 1
  end
  for _, result in pairs(recipe.results or {}) do
    local key = result.type == "fluid" and "fluid_out" or "item_out"
    counts[key] = counts[key] + 1
  end

  if not recipe.parameter and counts.item_in == 1 and counts.fluid_in == 1 and counts.item_out == 1 and counts.fluid_out == 1 then
    add_category(recipe, "ferrum-infusion")
  end
end

-- Fabricator: anything the electromagnetic plant can make, plus assembler recipes whose products are made from gears but not copper plates,
-- plus Ferrum's own assembler recipes.
local FABRICATION = "ferrum-fabrication"
-- Read from the assembler rather than listed: 2.0 spreads assembler recipes over extra "-or-assembling" style categories that 2.1 folded away.
local ASSEMBLER = {}
for _, category in pairs(data.raw["assembling-machine"]["assembling-machine-3"].crafting_categories) do ASSEMBLER[category] = true end
local EXCLUDED = { recycling = true, ["recycling-or-hand-crafting"] = true, parameters = true }

local ELECTROMAGNETIC = {}
for _, category in pairs(data.raw["assembling-machine"]["electromagnetic-plant"].crafting_categories) do ELECTROMAGNETIC[category] = true end
local fabricator = data.raw["assembling-machine"]["ferrum-fabricator"]
fabricator.crafting_categories = { FABRICATION }
-- Since 2.0.52 beacons only transmit module categories the receiving machine accepts, so the dock modules need to be allowed here.
fabricator.allowed_module_categories = {}
for name in pairs(data.raw["module-category"]) do table.insert(fabricator.allowed_module_categories, name) end

local candidates = {}
for _, recipe in pairs(data.raw.recipe) do
  local usable = not (recipe.parameter or recipe.hidden)
  for _, category in pairs(categories_of(recipe)) do usable = usable and not EXCLUDED[category] end
  if usable then table.insert(candidates, recipe) end
end

-- Forward edges only: an item is expanded through the recipes that make it as their main product and allow decomposition,
-- the same recipes the in-game "raw ingredients" tooltip uses. Casting and other alternate recipes opt out of this.
local producers = {}
for _, recipe in pairs(candidates) do
  if recipe.allow_decomposition ~= false then
    local results = recipe.results or {}
    for _, result in pairs(results) do
      if #results == 1 or recipe.main_product == result.name then
        local key = (result.type or "item") .. "/" .. result.name
        producers[key] = producers[key] or {}
        table.insert(producers[key], recipe)
      end
    end
  end
end

-- Registered before recursing so cycles terminate; an item inside a cycle may see a partial set.
local expanded = {}
local function raw_ingredients(key)
  if expanded[key] then return expanded[key] end
  local set = {}
  expanded[key] = set
  for _, recipe in pairs(producers[key] or {}) do
    for _, ingredient in pairs(recipe.ingredients or {}) do
      local sub = (ingredient.type or "item") .. "/" .. ingredient.name
      set[sub] = true
      for nested in pairs(raw_ingredients(sub)) do set[nested] = true end
    end
  end
  return set
end

local function mechanical(key)
  local set = raw_ingredients(key)
  return set["item/iron-plate"] and not set["item/copper-plate"]
end

for _, recipe in pairs(candidates) do
  local assembler, electromagnetic = false, false
  for _, category in pairs(categories_of(recipe)) do
    assembler = assembler or ASSEMBLER[category]
    electromagnetic = electromagnetic or ELECTROMAGNETIC[category]
  end
  local results = recipe.results or {}
  local legal = #results > 0
  for _, result in pairs(results) do legal = legal and mechanical((result.type or "item") .. "/" .. result.name) end
  local own = recipe.name:find("^ferrum%-") ~= nil
  if electromagnetic or (assembler and (own or legal)) then add_category(recipe, FABRICATION) end
end

local ROBOTICS = "ferrum-robotics-science-pack"
for _, lab in pairs(data.raw.lab) do
  local accepts, has = false, false
  for _, input in pairs(lab.inputs) do
    accepts = accepts or input == "space-science-pack"
    has = has or input == ROBOTICS
  end
  if accepts and not has then table.insert(lab.inputs, ROBOTICS) end
end

local science = require("prototypes.science")
-- Other mods may have redefined these after techs.lua added robotics science.
for level = 4, 5 do science.add_robotics(data.raw.technology["worker-robots-storage-" .. level]) end

require("prototypes.overclock")