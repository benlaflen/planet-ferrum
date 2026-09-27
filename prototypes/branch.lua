local compose = require("prototypes.compose")

local PACK = "ferrum-robotics-science-pack"
-- Trigger thresholds. Tune freely; none of them are load-bearing.
local N = {
  holmium = 150,
  plastic = 500,
  rocket_fuel = 50,
  infuser_late = 10,
  magnet_late = 25,
  carbon = 100,
  solid_fuel = 100,
  coal = 500,
  magnet_full = 50
}
-- Pedestals are containers because opening one raises on_gui_opened with the entity attached.
local PEDESTALS = {
  "ferrum-pedestal-first",
  "ferrum-pedestal-second-cementation",
  "ferrum-pedestal-second-pyrolysis",
  "ferrum-pedestal-second-reclamation",
  "ferrum-pedestal-third"
}
local RECIPE = {
  cementation = "ferrum-copper-cementation",
  pyrolysis = "ferrum-lubricant-pyrolysis",
  reclamation = "ferrum-lubricant-reclamation"
}
-- Second pedestal trigger per first pick, and the two options it offers.
local SECOND = {
  cementation = { item = "holmium-plate", count = N.holmium },
  pyrolysis   = { item = "plastic-bar", count = N.plastic },
  reclamation = { item = "rocket-fuel", count = N.rocket_fuel }
}
-- The third recipe's trigger: pyrolysis is the odd one out, the other two wait on the infuser.
local LATE = {
  cementation = { item = "ferrum-infuser", count = 1 },
  reclamation = { item = "ferrum-infuser", count = N.infuser_late },
  pyrolysis   = { item = "ferrum-rare-earth-magnet", count = N.magnet_late }
}

-- Research triggers cannot be restricted to one surface, so every threshold below is a scripted
-- trigger that scripts/pedestal.lua completes from Ferrum's own production statistics. The WATCH
-- table there must match these items and counts.
local function launched(item)
  return {
    type = "scripted",
    trigger_description = { "ferrum.trigger-launch", "[item=" .. item .. "]" }
  }
end

local function produced(item, count)
  return {
    type = "scripted",
    trigger_description = { "ferrum.trigger-produce", tostring(count), "[item=" .. item .. "]" }
  }
end

local function technology(t)
  t.type = "technology"
  for _, effect in pairs(t.effects or {}) do
    if effect.type == "unlock-recipe" then data.raw.recipe[effect.recipe].enabled = false end
  end
  data:extend({ t })
end

local function unlock(recipe)
  return { { type = "unlock-recipe", recipe = recipe } }
end

-- Recipes already carry composed icons; reuse every layer rather than recomposing the first one.
local function recipe_icons(name)
  return table.deepcopy(data.raw.recipe[name].icons)
end

local FULL = {
  ["agglomeration"] = {
    recipe = "ferrum-coal-agglomeration",
    cheap = { item = "coal", count = N.coal }
  },
  ["molten-iron"] = {
    recipe = "ferrum-molten-iron",
    cheap = { item = "ferrum-rare-earth-magnet", count = N.magnet_full }
  }
}

data:extend({
  {
    type = "recipe",
    name = "ferrum-crude-agglomeration",
    icons = compose({
      { item = "coal" },
      { fluid = "sulfuric-acid", scale = 0.75, shift = { 13, -12 } }
    }),
    categories = { "chemistry" },
    subgroup = "raw-material",
    order = "z[ferrum]-e[ferrum-crude-agglomeration]",
    enabled = false,
    energy_required = 4,
    ingredients = {
      { type = "item",  name = "carbon",        amount = 10 },
      { type = "fluid", name = "sulfuric-acid", amount = 50 }
    },
    results = { { type = "item", name = "coal", amount = 1 } }
  },
  {
    type = "recipe",
    name = "ferrum-crude-molten-iron",
    icons = compose({
      { fluid = "molten-iron" },
      { item = "solid-fuel", scale = 0.75, shift = { 13, -12 } }
    }),
    categories = { "metallurgy" },
    subgroup = "raw-material",
    order = "z[ferrum]-f[ferrum-crude-molten-iron]",
    enabled = false,
    energy_required = 4,
    allow_productivity = false,
    ingredients = {
      { type = "item", name = "solid-fuel", amount = 2 },
      { type = "item", name = "iron-plate", amount = 10 }
    },
    results = { { type = "fluid", name = "molten-iron", amount = 50 } }
  },
  {
    type = "recipe",
    name = "ferrum-molten-iron",
    icons = compose({
      { fluid = "molten-iron" },
      { fluid = "heavy-oil", scale = 0.75, shift = { 13, -12 } }
    }),
    categories = { "ferrum-infusion" },
    subgroup = "raw-material",
    order = "z[ferrum]-g[ferrum-molten-iron]",
    enabled = false,
    energy_required = 4,
    allow_productivity = false,
    ingredients = {
      { type = "item",  name = "iron-plate", amount = 10 },
      { type = "fluid", name = "heavy-oil",  amount = 40 }
    },
    results = {
      { type = "fluid", name = "molten-iron", amount = 50 },
      { type = "item",  name = "carbon",      amount = 1 }
    },
    main_product = "molten-iron"
  }
})

local chest = data.raw.container["steel-chest"]
for _, name in pairs(PEDESTALS) do
  local pedestal = table.deepcopy(chest)
  pedestal.name = name
  pedestal.inventory_size = 0
  pedestal.minable = nil
  pedestal.flags = { "placeable-off-grid", "not-blueprintable", "not-deconstructable", "not-upgradable", "no-copy-paste" }
  pedestal.picture = table.deepcopy(chest.picture)
  for _, layer in pairs(pedestal.picture.layers or { pedestal.picture }) do
    if not layer.draw_as_shadow then layer.tint = { 0.12, 0.12, 0.16 } end
  end
  pedestal.circuit_connector = nil
  pedestal.circuit_wire_max_distance = 0
  data:extend({ pedestal })
end

-- Crafting a fabricator opens the chemistry line and spawns the first pedestal.
technology({
  name = "ferrum-adaptive-chemistry",
  icons = compose({
    { fluid = "water" },
    { fluid = "electrolyte", scale = 0.75, shift = { 13, -12 } }
  }),
  effects = unlock("ferrum-atmospheric-condensation"),
  prerequisites = { "ferrum-fabricator" },
  research_trigger = produced("ferrum-fabricator", 1)
})

-- Crafting an infuser spawns the third pedestal.
technology({
  name = "ferrum-infusion-chemistry",
  icons = compose({ { item = "ferrum-infuser" } }),
  prerequisites = { "ferrum-rare-earth-processing" },
  research_trigger = produced("ferrum-infuser", 1)
})

-- Three slots per recipe: the two pedestal picks, and the trigger that grants whatever is left over.
for key, recipe in pairs(RECIPE) do
  for _, slot in pairs({ "first", "second" }) do
    technology({
      name = "ferrum-" .. slot .. "-" .. key,
      icons = recipe_icons(recipe),
      -- The second pick can follow any of the three first picks, and prerequisites are all-of, so both
      -- slots hang off the tech that starts the whole sequence.
      prerequisites = { slot == "first" and "ferrum-adaptive-chemistry" or "ferrum-second-pedestal-" .. key },
      enabled = false,
      visible_when_disabled = false,
      effects = unlock(recipe),
      research_trigger = { type = "scripted", trigger_description = { "ferrum.pedestal-choice" } }
    })
  end
  technology({
    name = "ferrum-late-" .. key,
    icons = recipe_icons(recipe),
    prerequisites = { "ferrum-rare-earth-processing" },
    enabled = false,
    visible_when_disabled = false,
    effects = unlock(recipe),
    research_trigger = produced(LATE[key].item, LATE[key].count)
  })
  -- Watches for the second pedestal's trigger; enabled only on the path that starts with this recipe.
  technology({
    name = "ferrum-second-pedestal-" .. key,
    icons = compose({ { item = SECOND[key].item } }),
    prerequisites = { "ferrum-first-" .. key },
    enabled = false,
    visible_when_disabled = false,
    research_trigger = produced(SECOND[key].item, SECOND[key].count)
  })
end

-- Third pedestal: the pick grants nothing, it only decides which full recipe gets the cheap trigger.
for _, key in pairs({ "agglomeration", "molten-iron" }) do
  technology({
    name = "ferrum-choose-" .. key,
    icons = recipe_icons(FULL[key].recipe),
    prerequisites = { "ferrum-infusion-chemistry" },
    enabled = false,
    visible_when_disabled = false,
    research_trigger = { type = "scripted", trigger_description = { "ferrum.pedestal-choice" } }
  })
end

technology({
  name = "ferrum-crude-agglomeration",
  icons = recipe_icons("ferrum-crude-agglomeration"),
  effects = unlock("ferrum-crude-agglomeration"),
  prerequisites = { "ferrum-infusion-chemistry" },
  -- scripts/pedestal.lua enables this once the infuser exists, so the trigger cannot fire early.
  enabled = false,
  visible_when_disabled = false,
  research_trigger = produced("carbon", N.carbon)
})

technology({
  name = "ferrum-crude-molten-iron",
  icons = recipe_icons("ferrum-crude-molten-iron"),
  effects = unlock("ferrum-crude-molten-iron"),
  prerequisites = { "ferrum-infusion-chemistry" },
  -- scripts/pedestal.lua enables this once the infuser exists, so the trigger cannot fire early.
  enabled = false,
  visible_when_disabled = false,
  research_trigger = produced("solid-fuel", N.solid_fuel)
})

-- Each full recipe has a cheap trigger and a slow one; the third pedestal enables one of each.
for key, full in pairs(FULL) do
  for slot, trigger in pairs({
    cheap = full.cheap,
    slow = { item = PACK, launch = true }
  }) do
    technology({
      name = "ferrum-full-" .. key .. "-" .. slot,
      icons = recipe_icons(full.recipe),
      -- The cheap variant follows picking this recipe; the slow one follows picking the other.
      prerequisites = { "ferrum-choose-" .. (slot == "cheap" and key or (key == "agglomeration" and "molten-iron" or "agglomeration")) },
      enabled = false,
      visible_when_disabled = false,
      effects = unlock(full.recipe),
      research_trigger = trigger.launch and launched(trigger.item) or produced(trigger.item, trigger.count)
    })
  end
end