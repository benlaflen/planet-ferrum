local ICONS = "__planet-ferrum__/graphics/icons/"

local items = data.raw.item
local fluids = data.raw.fluid

local function icon(prototype, tint)
  return { { icon = prototype.icon, icon_size = prototype.icon_size or 64, tint = tint } }
end

local function own(name)
  return { { icon = ICONS .. name .. ".png", icon_size = 64, icon_mipmaps = 4 } }
end

local compose = require("prototypes.compose")

data:extend({
  { type = "recipe-category", name = "ferrum-fabrication" },

  {
    type = "item",
    name = "ferrum-clay",
    icons = own("clay"),
    subgroup = "raw-resource",
    order = "z[ferrum]-a[ferrum-clay]",
    stack_size = 50
  },
  {
    type = "item",
    name = "ferrum-concentrated-clay",
    icons = own("concentrated-clay"),
    subgroup = "raw-material",
    order = "z[ferrum]-b[ferrum-concentrated-clay]",
    stack_size = 50
  },
  {
    type = "item",
    name = "ferrum-rare-earth-oxide",
    icons = own("rare-earth-oxide"),
    subgroup = "raw-material",
    order = "z[ferrum]-c[ferrum-rare-earth-oxide]",
    stack_size = 50
  },
  {
    type = "item",
    name = "ferrum-rare-earth-magnet",
    icons = own("rare-earth-magnets"),
    subgroup = "intermediate-product",
    order = "z[ferrum]-d[ferrum-rare-earth-magnet]",
    stack_size = 100
  },
  {
    type = "fluid",
    name = "ferrum-rare-earth-solution",
    icons = own("rare-earth-solution"),
    subgroup = "fluid",
    order = "z[ferrum]-a[ferrum-rare-earth-solution]",
    default_temperature = 25,
    base_color = { 0.45, 0.25, 0.60 },
    flow_color = { 0.75, 0.55, 0.95 }
  },

  {
    type = "recipe",
    name = "ferrum-concentrated-clay",
    categories = { "electromagnetics" },
    enabled = true,
    energy_required = 4,
    surface_conditions = { { property = "ferrum-habitability", min = 100 } },
    ingredients = { { type = "item", name = "ferrum-clay", amount = 5 } },
    results = { { type = "item", name = "ferrum-concentrated-clay", amount = 1 } }
  },
  {
    type = "recipe",
    name = "ferrum-lubricant-pyrolysis",
    icons = compose({
      { fluid = "lubricant", scale = 2},
      { item = "carbon", scale = 1}
   }),
    categories = { "chemistry" },
    subgroup = "intermediate-product",
    order = "z[ferrum]-a[ferrum-lubricant-pyrolysis]",
    enabled = true,
    energy_required = 2,
    ingredients = {
      { type = "item",  name = "ferrum-clay", amount = 2 },
      { type = "fluid", name = "lubricant", amount = 50  }
    },
    results = {
      { type = "item",  name = "carbon", amount = 1 },
      { type = "fluid", name = "petroleum-gas", amount = 20 }
    }
  },
  {
    type = "recipe",
    name = "ferrum-coal-agglomeration",
    icons = compose({
      {item = "carbon", shift = {-10, 0}},
      {item = "coal", shift = {10, 0}}
   }),
    categories = { "chemistry" },
    subgroup = "intermediate-product",
    order = "z[ferrum]-a[ferrum-coal-agglomeration]",
    enabled = true,
    energy_required = 2,
    allow_productivity = true,
    ingredients = {
      { type = "item",  name = "carbon", amount = 5 },
      { type = "fluid", name = "sulfuric-acid", amount = 25  }
    },
    results = {
      { type = "item",  name = "coal", amount = 1 },
      { type = "fluid", name = "water", amount = 25 }
    }
  },
  {
    type = "recipe",
    name = "ferrum-rare-earth-solution",
    categories = { "chemistry" },
    enabled = true,
    energy_required = 2,
    ingredients = {
      { type = "item",  name = "ferrum-concentrated-clay", amount = 1 },
      { type = "fluid", name = "sulfuric-acid",     amount = 10 }
    },
    results = {
      { type = "fluid", name = "ferrum-rare-earth-solution", amount = 15 },
      { type = "item",  name = "uranium-238",         amount = 1, probability = 0.33 }
    },
    main_product = "ferrum-rare-earth-solution"
  },
  {
    type = "recipe",
    name = "ferrum-rare-earth-separation",
    icons = own("rare-earth-oxide"),
    categories = { "ferrum-fabrication" },
    subgroup = "raw-material",
    order = "z[ferrum]-c[ferrum-rare-earth-separation]",
    enabled = true,
    energy_required = 0.5,
    allow_productivity = true,
    ingredients = { { type = "fluid", name = "ferrum-rare-earth-solution", amount = 10 } },
    results = {
      { type = "fluid", name = "ferrum-rare-earth-solution", amount = 10, probability = 0.85, ignored_by_productivity = 10 },
      { type = "item",  name = "stone",               amount = 1,  probability = 0.02 },
      { type = "item",  name = "holmium-ore",        amount = 1,  probability = 0.02 },
      { type = "item",  name = "uranium-238",         amount = 1,  probability = 0.02 },
      { type = "item",  name = "ferrum-clay",                amount = 1,  probability = 0.02 },
      { type = "item",  name = "ferrum-rare-earth-oxide",    amount = 1,  probability = 0.02 }
    }
  },
  {
    type = "recipe",
    name = "ferrum-rare-earth-magnet",
    categories = { "metallurgy" },
    enabled = true,
    energy_required = 5,
    allow_productivity = true,
    ingredients = {
      { type = "item",  name = "ferrum-rare-earth-oxide", amount = 5 },
      { type = "fluid", name = "electrolyte",      amount = 10 },
      { type = "fluid", name = "molten-iron",      amount = 20 }
    },
    results = { { type = "item", name = "ferrum-rare-earth-magnet", amount = 1 } }
  }
})

data:extend({
  {
    type = "recipe",
    name = "ferrum-lubricant-reclamation",
    icons = compose({
      { fluid = "lubricant",     scale = 0.55, shift = { 0, -15 } },
      { fluid = "water",         scale = 0.55, shift = { -15, 0 } },
      { fluid = "heavy-oil",     scale = 0.55, shift = { 15, 0 } },
      { fluid = "sulfuric-acid", scale = 0.55, shift = { 0, 15 } }
    }),
    categories = { "chemistry" },
    subgroup = "fluid-recipes",
    order = "z[ferrum]-a[ferrum-lubricant-reclamation]",
    enabled = true,
    energy_required = 2,
    surface_conditions = { { property = "ferrum-habitability", min = 100 } },
    ingredients = {
      { type = "fluid", name = "lubricant", amount = 100 },
      { type = "fluid", name = "water",     amount = 50 }
    },
    results = {
      { type = "fluid", name = "sulfuric-acid", amount = 10 },
      { type = "fluid", name = "heavy-oil",     amount = 90 }
    }
  }
})

data:extend({
  {
    type = "recipe",
    name = "ferrum-atmospheric-condensation",
    icons = compose({
      { fluid = "steam",       scale = 0.6, shift = { 0, -14 } },
      { fluid = "water",       scale = 0.6, shift = { -13, 11 } },
      { fluid = "electrolyte", scale = 0.6, shift = { 13, 11 } }
    }),
    categories = { "chemistry" },
    subgroup = "fluid-recipes",
    order = "z[ferrum]-b[ferrum-atmospheric-condensation]",
    enabled = true,
    energy_required = 1,
    allow_productivity=true,
    surface_conditions = { { property = "ferrum-habitability", min = 100 } },
    ingredients = {},
    results = {
      { type = "fluid", name = "water",       amount = 5 },
      { type = "fluid", name = "electrolyte", amount = 5 }
    }
  }
})

data:extend({
  {
    type = "recipe",
    name = "ferrum-holmium-separation",
    icons = compose({
      { fluid = "ferrum-rare-earth-solution", scale = 0.7, shift = { -12, 0 } },
      { fluid = "holmium-solution",    scale = 0.7, shift = { 12, 0 } }
    }),
    categories = { "chemistry" },
    subgroup = "fluid-recipes",
    order = "z[ferrum]-c[ferrum-holmium-separation]",
    enabled = true,
    energy_required = 2,
    ingredients = { { type = "fluid", name = "ferrum-rare-earth-solution", amount = 20 } },
    results = { { type = "fluid", name = "holmium-solution", amount = 10 } }
  },
  {
    type = "recipe",
    name = "ferrum-rare-earth-micronutrients",
    icons = compose({
      { item = "ferrum-rare-earth-oxide" },
      { item = "nutrients", scale = 0.45 }
    }),
    categories = { "ferrum-fabrication" },
    subgroup = "agriculture-products",
    order = "z[ferrum]-a[ferrum-rare-earth-micronutrients]",
    enabled = true,
    energy_required = 2,
    ingredients = {
      { type = "item", name = "ferrum-concentrated-clay", amount = 1 },
      { type = "item", name = "stone",             amount = 5 }
    },
    results = { { type = "item", name = "nutrients", amount = 10 } }
  }
})