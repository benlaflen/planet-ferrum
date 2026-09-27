local ROBOTICS = "ferrum-robotics-science-pack"
local CRYO = "cryogenic-science-pack"
local techs = data.raw.technology
local compose = require("prototypes.compose")
local science = require("prototypes.science")

local function icons_of(prototype)
  return prototype.icons or { { icon = prototype.icon, icon_size = prototype.icon_size or 64 } }
end

-- "Red-white": automation, logistic, chemical, space.
local function unit(count, extra)
  local ingredients = {
    { "automation-science-pack", 1 },
    { "logistic-science-pack", 1 },
    { "chemical-science-pack", 1 },
    { "space-science-pack", 1 }
  }
  for _, pack in pairs(extra) do table.insert(ingredients, pack) end
  return { count = count, ingredients = ingredients, time = 60 }
end

local function technology(t)
  t.type = "technology"
  for _, effect in pairs(t.effects or {}) do
    if effect.type == "unlock-recipe" then data.raw.recipe[effect.recipe].enabled = false end
  end
  data:extend({ t })
end

-- Science packs are tools in 2.0 and plain items in 2.1.
local LEGACY = require("prototypes.version")
-- Science packs are tools on 2.0 and plain items on 2.1.
local tools = data.raw.tool or {}
local pack = table.deepcopy(tools["electromagnetic-science-pack"] or data.raw.item["electromagnetic-science-pack"])
if LEGACY then pack.type = "tool" end
pack.name = ROBOTICS
pack.icon = nil
pack.icons = { { icon = "__planet-ferrum__/graphics/icons/robotics-science-pack.png", icon_size = 64, icon_mipmaps = 4 } }
pack.order = "k[ferrum-robotics-science-pack]"

data:extend({
  pack,
  -- Placeholder recipe.
  {
    type = "recipe",
    name = ROBOTICS,
    categories = { "ferrum-fabrication" },
    enabled = false,
    energy_required = 10,
    allow_productivity = true,
    surface_conditions = { { property = "ferrum-habitability", min = 100 } },
    ingredients = {
      { type = "item",  name = "ferrum-rare-earth-magnet",  amount = 1 },
      { type = "item",  name = "uranium-235", amount = 1 },
      { type = "item",  name = "electric-engine-unit",     amount = 4 }
    },
    results = { { type = "item", name = ROBOTICS, amount = 1 } }
  }
})

local F = { "electromagnetic-science-pack", 1 }
local V = { "metallurgic-science-pack", 1 }
local Y = { "utility-science-pack", 1 }
local P = { "production-science-pack", 1 }
local R = { ROBOTICS, 1 }

technology({
  name = "planet-discovery-ferrum",
  icons = icons_of(data.raw.planet["ferrum"]),
  essential = true,
  effects = { { type = "unlock-space-location", space_location = "ferrum", use_icon_overlay_constant = false } },
  prerequisites = { "logistic-system", "construction-robotics", "electromagnetic-science-pack", "metallurgic-science-pack" },
  unit = unit(1500, { F, V })
})

-- Completed by control.lua on arrival in orbit; control.lua spawns the starter base when it finishes.
technology({
  name = "ferrum-contact",
  icons = icons_of(data.raw.planet["ferrum"]),
  prerequisites = { "planet-discovery-ferrum" },
  research_trigger = { type = "scripted", trigger_description = { "", "Arrive in orbit at Ferrum" } }
})

technology({
  name = "ferrum-fabricator",
  icons = compose({
    { item = "ferrum-fabricator" },
    { item = "ferrum-concentrated-clay", scale = 0.45, shift = { 13, 13 } }
  }),
  effects = {
    { type = "unlock-recipe", recipe = "ferrum-fabricator" },
    { type = "unlock-recipe", recipe = "ferrum-concentrated-clay" }
  },
  prerequisites = { "ferrum-contact", "kovarex-enrichment-process"},
  -- 2.0 takes a single entity, 2.1 takes a list.
  research_trigger = LEGACY and { type = "mine-entity", entity = "ferrum-clay-ore" }
    or { type = "mine-entity", entities = { "ferrum-clay-ore" } }
})

technology({
  name = "ferrum-rare-earth-processing",
  icons = icons_of(data.raw.item["ferrum-rare-earth-oxide"]),
  effects = {
    { type = "unlock-recipe", recipe = "ferrum-infuser" },
    { type = "unlock-recipe", recipe = "ferrum-rare-earth-solution" },
    { type = "unlock-recipe", recipe = "ferrum-rare-earth-separation" },
    { type = "unlock-recipe", recipe = "ferrum-rare-earth-magnet" }
  },
  prerequisites = { "ferrum-fabricator", "logistics-3" },
  research_trigger = { type = "craft-item", item = "ferrum-concentrated-clay", count = 50 }
})

technology({
  name = ROBOTICS,
  icons = pack.icons,
  effects = { { type = "unlock-recipe", recipe = ROBOTICS } },
  prerequisites = { "ferrum-rare-earth-processing" },
  research_trigger = { type = "craft-item", item = "ferrum-rare-earth-magnet", count = 50 }
})

-- Must match FRONTLINE in control.lua.
local FRONTLINE = {
  { count = 500,  fire = "5/90",  extra = {} },
  { count = 1000, fire = "10/95", extra = {} },
  { count = 1500, fire = "20/99", extra = { { "agricultural-science-pack", 1 } }, prerequisite = "agricultural-science-pack" },
  { count = 2500, fire = "0/100", extra = { { "agricultural-science-pack", 1 }, { CRYO, 1 } }, prerequisite = CRYO }
}
for level, tier in pairs(FRONTLINE) do
  local extra = { Y, P, F, V, R }
  for _, e in pairs(tier.extra) do table.insert(extra, e) end
  local prerequisites = { level == 1 and ROBOTICS or "ferrum-frontline-robotics-" .. (level - 1) }
  if tier.prerequisite then table.insert(prerequisites, tier.prerequisite) end
  technology({
    name = "ferrum-frontline-robotics-" .. level,
    icons = icons_of(techs["worker-robots-speed-1"]),
    upgrade = level > 1,
    effects = { { type = "nothing", effect_description = { "modifier-description.frontline-robot-resistance", tier.fire .. "%" } } },
    prerequisites = prerequisites,
    unit = unit(tier.count, extra)
  })
end

technology({
  name = "ferrum-overclock-robots",
  icons = icons_of(data.raw.item["ferrum-overclock-robot"]),
  effects = { { type = "unlock-recipe", recipe = "ferrum-overclock-robot" } },
  prerequisites = { ROBOTICS },
  unit = unit(500, { { "utility-science-pack", 2 }, P, F, V, { ROBOTICS, 2 } })
})

-- control.lua sets the belt-clearance surface property when this finishes.
technology({
  name = "ferrum-deionizing-belts",
  icons = icons_of(data.raw.item["transport-belt"]),
  effects = { { type = "nothing", effect_description = { "modifier-description.deionizing-belts" } } },
  prerequisites = { ROBOTICS },
  unit = unit(1000, { R })
})

technology({
  name = "ferrum-advanced-rare-earth-processing",
  icons = icons_of(data.raw.item["ferrum-rare-earth-oxide"]),
  effects = {
    { type = "unlock-recipe", recipe = "ferrum-solvent-extraction" },
    { type = "unlock-recipe", recipe = "ferrum-holmium-separation" },
    { type = "unlock-recipe", recipe = "ferrum-rare-earth-micronutrients" }
  },
  prerequisites = { ROBOTICS },
  unit = unit(1000, { Y, P, F, V, R })
})

-- Copies vanilla's cost formula, time and per-level bonus; only packs, prerequisites and icon change.
local template = techs["processing-unit-productivity"]
for _, spec in pairs({
  { recipe = "electric-engine-unit", item = "electric-engine-unit" },
  { recipe = "ferrum-rare-earth-magnet",    item = "ferrum-rare-earth-magnet" }
}) do
  local t = table.deepcopy(template)
  t.name = "ferrum-" .. spec.recipe:gsub("^ferrum%-", "") .. "-productivity"
  local item = data.raw.item[spec.item]
  local source = item.icons and item.icons[1] or item
  t.icons = {
    { icon = source.icon, icon_size = source.icon_size or 64, scale = 4, tint = source.tint },
    table.deepcopy(template.icons[#template.icons])
  }
  t.icon = nil
  t.effects = { { type = "change-recipe-productivity", recipe = spec.recipe, change = 0.1 } }
  t.prerequisites = { ROBOTICS }
  t.unit.ingredients = unit(0, { Y, P, R }).ingredients
  technology(t)
end

local storage_2, storage_3 = techs["worker-robots-storage-2"], techs["worker-robots-storage-3"]
local ratio = storage_3.unit.count / storage_2.unit.count
local previous = storage_3
for level = 4, 5 do
  local t = table.deepcopy(previous)
  t.name = "worker-robots-storage-" .. level
  t.unit.count = math.floor(previous.unit.count * ratio)
  t.prerequisites = { previous.name }
  science.add_robotics(t)
  data:extend({ t })
  previous = t
end