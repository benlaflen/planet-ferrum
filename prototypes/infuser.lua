local compose = require("prototypes.compose")
local rescale = require("prototypes.rescale")

local INFUSER = "ferrum-infuser"
local CATEGORY = "ferrum-infusion"
-- Rows of the belt sheet, 0-based: east, west, north, south. The belt runs the way the infuser faces.
local BELT_ROW = { north = 2, east = 0, south = 3, west = 1 }

local icons = compose({
  { item = "express-transport-belt", shift = {0, 5} },
  { item = "chemical-plant", scale = 0.75, shift = {0, -5} }
})

local item = table.deepcopy(data.raw.item["express-transport-belt"])
item.name = INFUSER
item.place_result = INFUSER
item.order = "z[infuser]"
item.icon = nil
item.icons = icons

local machine = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
local pipes = machine.fluid_boxes[1]
machine.name = INFUSER
machine.minable = { mining_time = 0.1, result = INFUSER }
machine.collision_box = { { -0.4, -0.4 }, { 0.4, 0.4 } }
machine.selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } }
machine.corpse = nil
machine.dying_explosion = nil

rescale(machine.graphics_set, 1 / 3)

-- All layers need the body's frame count: the belt is cut short or repeated to match.
local belt = data.raw["transport-belt"]["express-transport-belt"].belt_animation_set.animation_set
local body_layers = machine.graphics_set.animation.layers
local frames = (body_layers[1].frame_count or 1) * (body_layers[1].repeat_count or 1)
local belt_frames = math.min(belt.frame_count, frames)
machine.graphics_set.animation = {}
for direction, row in pairs(BELT_ROW) do
  local directional = {
    {
      filename = belt.filename,
      priority = belt.priority,
      size = belt.size,
      scale = belt.scale,
      frame_count = belt_frames,
      repeat_count = frames / belt_frames,
      line_length = belt.line_length or belt.frame_count,
      y = row * belt.size * math.ceil(belt.frame_count / (belt.line_length or belt.frame_count))
    }
  }
  for _, layer in pairs(body_layers) do table.insert(directional, layer) end
  machine.graphics_set.animation[direction] = { layers = directional }
end

machine.water_reflection = nil
machine.working_sound = nil
machine.circuit_connector = nil
machine.circuit_wire_max_distance = 0
machine.next_upgrade = nil
machine.fast_replaceable_group = nil
machine.icon = nil
machine.icons = icons
machine.crafting_categories = { CATEGORY }
machine.crafting_speed = 8
machine.energy_usage = "500kW"
machine.module_slots = 0
machine.effect_receiver = { base_effect = { productivity = 0.5 }, uses_module_effects = false, uses_beacon_effects = false }
machine.icon_draw_specification = { scale = 0.5 }
-- Keeps the pipe ends drawn with no recipe set.
machine.fluid_boxes_off_when_no_fluid_recipe = false
-- Oriented for a north-facing infuser (items in from the south, out to the north): fluid enters on the west, leaves on the east. Index 1 is read by scripts/infuser.lua.
machine.fluid_boxes = {
  {
    production_type = "input",
    volume = 200,
    pipe_picture = pipes.pipe_picture,
    pipe_covers = pipes.pipe_covers,
    pipe_connections = { { flow_direction = "input", direction = defines.direction.west, position = { 0, 0 } } }
  },
  {
    production_type = "output",
    volume = 200,
    pipe_picture = pipes.pipe_picture,
    pipe_covers = pipes.pipe_covers,
    pipe_connections = { { flow_direction = "output", direction = defines.direction.east, position = { 0, 0 } } }
  }
}

-- Placeholder amounts and unlock.
local cementation = {
  type = "recipe",
  name = "ferrum-copper-cementation",
  icons = compose({
    { item = "copper-plate" },
    { fluid = "electrolyte", scale = 0.5, shift = { 13, -12 } }
  }),
  enabled = true,
  energy_required = 1,
  allow_productivity = true,
  auto_recycle=false,
  ingredients = {
    { type = "item",  name = "iron-plate",  amount = 1 },
    { type = "fluid", name = "electrolyte", amount = 10 }
  },
  results = {
    { type = "item",  name = "copper-plate",  amount = 1 },
    { type = "fluid", name = "sulfuric-acid", amount = 2 }
  },
  main_product = "copper-plate",
  categories = { CATEGORY, "chemistry" }
}

local solvent_extraction = {
  type = "recipe",
  name = "ferrum-solvent-extraction",
  icons = compose({
    { item = "ferrum-rare-earth-oxide" },
    { fluid = "lubricant", scale = 0.8, shift = { 0, -10 } }
  }),
  enabled = true,
  energy_required = 2,
  allow_productivity = true,
  ingredients = {
    { type = "fluid", name = "lubricant",         amount = 50 },
    { type = "item",  name = "ferrum-concentrated-clay", amount = 3 }
  },
  results = {
    { type = "fluid", name = "heavy-oil",        amount = 20 },
    { type = "item",  name = "ferrum-rare-earth-oxide", amount = 1 }
  },
  main_product = "ferrum-rare-earth-oxide",
  categories = { CATEGORY }
}

data:extend({
  { type = "recipe-category", name = CATEGORY },
  item,
  machine,
  cementation,
  solvent_extraction,
  {
    type = "recipe",
    name = INFUSER,
    categories = { "ferrum-fabrication" },
    enabled = true,
    energy_required = 5,
    ingredients = {
      { type = "item", name = "express-transport-belt", amount = 1 },
      { type = "item", name = "chemical-plant",       amount = 1 },
      { type = "item", name = "processing-unit",      amount = 10 }
    },
    results = { { type = "item", name = INFUSER, amount = 1 } }
  }
})