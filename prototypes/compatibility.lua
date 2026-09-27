local compose = require("prototypes.compose")

local techs = data.raw.technology

local function unlock(tech, recipe)
  table.insert(techs[tech].effects, { type = "unlock-recipe", recipe = recipe })
end

-- Placeholder amounts.
if mods["linox"] then
  data:extend({
    {
      type = "recipe",
      name = "ferrum-rare-earth-oxide-crushing",
      icons = compose({
        { item = "rare-earth-powder" },
        { item = "ferrum-rare-earth-oxide", scale = 0.75, shift = { -13, -13 } }
      }),
      categories = { "crafting" },
      enabled = false,
      energy_required = 2,
      allow_productivity = false,
      ingredients = { { type = "item", name = "ferrum-rare-earth-oxide", amount = 1 } },
      results = { { type = "item", name = "rare-earth-powder", amount = 2 } }
    },
    {
      type = "recipe",
      name = "ferrum-rare-earth-powder-leaching",
      icons = compose({
        { fluid = "ferrum-rare-earth-solution" },
        { item = "rare-earth-powder", scale = 0.75, shift = { -13, -13 } }
      }),
      categories = { "chemistry" },
      enabled = false,
      energy_required = 2,
      allow_productivity = true,
      ingredients = {
        { type = "item",  name = "rare-earth-powder", amount = 1 },
        { type = "fluid", name = "sulfuric-acid",     amount = 10 }
      },
      results = { { type = "fluid", name = "ferrum-rare-earth-solution", amount = 20 } }
    }
  })
  unlock("ferrum-advanced-rare-earth-processing", "ferrum-rare-earth-oxide-crushing")
  unlock("ferrum-rare-earth-processing", "ferrum-rare-earth-powder-leaching")
end

if mods["Moshine"] then
  data:extend({
    {
      type = "recipe",
      name = "ferrum-neodymium-precipitation",
      icons = compose({
        { item = "ferrum-rare-earth-oxide" },
        { item = "neodymium", scale = 0.75, shift = { -13, -13 } }
      }),
      categories = { "chemistry" },
      enabled = false,
      energy_required = 2,
      allow_productivity = true,
      ingredients = {
        { type = "item",  name = "neodymium",           amount = 1 },
        { type = "fluid", name = "ferrum-rare-earth-solution", amount = 20 }
      },
      results = {
        { type = "item",  name = "ferrum-rare-earth-oxide", amount = 2 },
        { type = "fluid", name = "sulfuric-acid",           amount = 10 }
      },
      main_product = "ferrum-rare-earth-oxide"
    },
    {
      type = "recipe",
      name = "ferrum-neodymium-separation",
      icons = compose({
        { item = "neodymium" },
        { fluid = "ferrum-rare-earth-solution", scale = 0.75, shift = { -13, -13 } }
      }),
      categories = { "chemistry" },
      enabled = false,
      energy_required = 4,
      ingredients = { { type = "fluid", name = "ferrum-rare-earth-solution", amount = 100 } },
      results = { { type = "item", name = "neodymium", amount = 1 } }
    }
  })
  unlock("ferrum-rare-earth-processing", "ferrum-neodymium-precipitation")
  unlock("ferrum-advanced-rare-earth-processing", "ferrum-neodymium-separation")
  table.insert(data.raw.recipe["ferrum-rare-earth-separation"].results, { type = "item", name = "neodymium", amount = 1, probability = 0.02 })
end