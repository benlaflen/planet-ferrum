local util = require("util")

local compose = require("prototypes.compose")

local FABRICATOR = "ferrum-fabricator"
local MAX_BOTS = 30
local LEGACY = require("prototypes.version")
-- 2.1 divided quality effect values by 10; both are 0.5% per bot.
local PER_BOT = { quality = LEGACY and 0.05 or 0.005, speed = 0.05, productivity = 0.015 }
local MODULE_ICON = { quality = "quality-module", speed = "speed-module", productivity = "productivity-module" }
local HIDDEN_FLAGS = {
  "not-on-map", "not-blueprintable", "not-deconstructable", "hide-alt-info", "not-selectable-in-game",
  "placeable-off-grid", "no-copy-paste", "not-upgradable", "not-in-kill-statistics"
}
local TINT = { 0.75, 0.55, 1.0 }
-- Charger crops out of roboport-base.png, in image pixels around each charging offset. Estimated without viewing the image.
local PAD_WIDTH, PAD_ABOVE, PAD_BELOW = 56, 64, 28
local PAD_SCALE = 0.75
local PAD_POSITION = 1.15
local HATCH_SCALE = 0.75
local HATCH_Y = -0.35

local fabricator = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
fabricator.name = FABRICATOR
fabricator.minable.result = FABRICATOR
fabricator.module_slots = 3
table.insert(fabricator.crafting_categories, "ferrum-fabrication")
fabricator.next_upgrade = nil
fabricator.fast_replaceable_group = nil

-- Assembler 3's layer split differs between 2.0 (body, shadow) and 2.1 (base, animation, shadow).
local layers = fabricator.graphics_set.animation.layers
local frames = (layers[1].frame_count or 1) * (layers[1].repeat_count or 1)
for _, layer in pairs(layers) do
  if not layer.draw_as_shadow then layer.tint = TINT end
end

local port = data.raw.roboport["roboport"]
local body = port.base.layers[1]
local pixels_per_tile = 32 / body.scale
local center = { body.width / 2 - body.shift[1] * pixels_per_tile, body.height / 2 - body.shift[2] * pixels_per_tile }
local extra = {}
for _, offset in pairs(port.charging_offsets) do
  local pad = { center[1] + offset[1] * pixels_per_tile, center[2] + offset[2] * pixels_per_tile }
  local x = math.max(0, math.min(body.width - PAD_WIDTH, math.floor(pad[1] - PAD_WIDTH / 2)))
  local y = math.max(0, math.min(body.height - PAD_ABOVE - PAD_BELOW, math.floor(pad[2] - PAD_ABOVE)))
  local crop_center = { x + PAD_WIDTH / 2, y + (PAD_ABOVE + PAD_BELOW) / 2 }
  table.insert(extra, {
    filename = body.filename,
    width = PAD_WIDTH,
    height = PAD_ABOVE + PAD_BELOW,
    x = x,
    y = y,
    scale = body.scale * PAD_SCALE,
    repeat_count = frames,
    shift = {
      (offset[1] > 0 and 1 or -1) * PAD_POSITION + (crop_center[1] - pad[1]) / pixels_per_tile * PAD_SCALE,
      (offset[2] > 0 and 1 or -1) * PAD_POSITION + (crop_center[2] - pad[2]) / pixels_per_tile * PAD_SCALE
    }
  })
end

for i, layer in pairs(extra) do table.insert(layers, 2 + i, layer) end

-- Roboport door halves for the dock, re-centred on the seam between them. The dock sits at the fabricator's position.
local seam = port.door_animation_up.shift[2] + port.door_animation_up.height * port.door_animation_up.scale / 64
local hatch = {}
for key, half in pairs({ up = port.door_animation_up, down = port.door_animation_down }) do
  local door = table.deepcopy(half)
  door.scale = half.scale * HATCH_SCALE
  door.shift = { half.shift[1] * HATCH_SCALE, HATCH_Y + (half.shift[2] - seam) * HATCH_SCALE }
  hatch[key] = door
end

local item = table.deepcopy(data.raw.item["assembling-machine-3"])
item.name = FABRICATOR
item.place_result = FABRICATOR
item.order = "z[ferrum-fabricator]"
item.icon = nil
item.icons = compose({
  { item = "assembling-machine-3", tint = TINT },
  { item = "construction-robot", scale = 0.75, shift = { 0, -13 } }
})

local dock = table.deepcopy(data.raw.roboport["roboport"])
dock.name = FABRICATOR .. "-dock"
dock.next_upgrade = nil
dock.hidden = true
dock.flags = HIDDEN_FLAGS
dock.minable = nil
dock.selection_box = nil
dock.collision_box = { { -0.4, -0.4 }, { 0.4, 0.4 } }
dock.collision_mask = { layers = {} }
dock.corpse = nil
dock.dying_explosion = nil
dock.logistics_radius = 1
dock.logistics_connection_distance = 1
dock.construction_radius = 0
dock.icon_draw_specification = table.deepcopy(fabricator.icon_draw_specification)
-- Must match CHARGE_PER_PAD in scripts/fabricator.lua.
dock.energy_source = { type = "void" }
dock.charging_energy = "500kW"
dock.robot_slots_count = 4
dock.material_slots_count = 1
dock.draw_logistic_radius_visualization = false
dock.draw_construction_radius_visualization = false
dock.base = util.empty_sprite()
dock.base_patch = util.empty_sprite()
dock.base_animation = util.empty_animation(1)
dock.door_animation_up = hatch.up
dock.door_animation_down = hatch.down
dock.recharging_animation = util.empty_animation(1)
dock.water_reflection = nil
dock.circuit_connector = nil
dock.circuit_wire_max_distance = 0
dock.working_sound = nil
dock.open_sound = nil
dock.close_sound = nil

local booster = table.deepcopy(data.raw.beacon["beacon"])
booster.name = FABRICATOR .. "-booster"
booster.next_upgrade = nil
booster.hidden = true
booster.flags = HIDDEN_FLAGS
booster.minable = nil
booster.selection_box = nil
booster.collision_box = { { -0.4, -0.4 }, { 0.4, 0.4 } }
booster.collision_mask = { layers = {} }
booster.corpse = nil
booster.dying_explosion = nil
booster.graphics_set = nil
booster.radius_visualisation_picture = nil
booster.water_reflection = nil
booster.working_sound = nil
booster.open_sound = nil
booster.close_sound = nil
booster.energy_source = { type = "void" }
booster.energy_usage = "1W"
booster.supply_area_distance = 0
booster.module_slots = 3
booster.allowed_effects = { "quality", "speed", "productivity" }
booster.allowed_module_categories = { FABRICATOR .. "-dock" }
booster.distribution_effectivity = 1
booster.distribution_effectivity_bonus_per_quality_level = 0
booster.profile = { 1 }
booster.beacon_counter = "same_type"

data:extend({
  fabricator,
  item,
  dock,
  booster,
  {
    type = "recipe",
    name = FABRICATOR,
    enabled = true,
    energy_required = 10,
    surface_conditions = { { property = "ferrum-habitability", min = 100 } },
    ingredients = {
      { type = "item", name = "assembling-machine-2", amount = 1 },
      { type = "item", name = "flying-robot-frame",   amount = 5 },
      { type = "item", name = "accumulator",          amount = 3 },
      { type = "item", name = "electric-engine-unit",     amount = 5}
    },
    results = { { type = "item", name = FABRICATOR, amount = 1 } }
  },
  { type = "module-category", name = FABRICATOR .. "-dock" }
})

for kind, per in pairs(PER_BOT) do
  local icon_source = data.raw.module[MODULE_ICON[kind]]
  for count = 1, MAX_BOTS do
    data:extend({
      {
        type = "module",
        name = FABRICATOR .. "-dock-" .. kind .. "-" .. count,
        icon = icon_source.icon,
        icon_size = icon_source.icon_size,
        hidden = true,
        hidden_in_factoriopedia = true,
        auto_recycle = false,
        category = FABRICATOR .. "-dock",
        tier = 1,
        stack_size = 1,
        effect = { [kind] = per * count }
      }
    })
  end
end

local signals = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
signals.name = FABRICATOR .. "-signals"
signals.next_upgrade = nil
signals.hidden = true
signals.flags = HIDDEN_FLAGS
signals.minable = nil
signals.selection_box = nil
signals.collision_box = { { -0.2, -0.2 }, { 0.2, 0.2 } }
signals.collision_mask = { layers = {} }
signals.corpse = nil
signals.dying_explosion = nil
signals.sprites = util.empty_sprite()
signals.activity_led_sprites = util.empty_sprite()
signals.water_reflection = nil
data:extend({ signals })

data:extend({
  {
    type = "electric-energy-interface",
    name = FABRICATOR .. "-charger-load",
    icon = data.raw.item["accumulator"].icon,
    icon_size = data.raw.item["accumulator"].icon_size,
    hidden = true,
    flags = HIDDEN_FLAGS,
    collision_box = table.deepcopy(fabricator.collision_box),
    collision_mask = { layers = {} },
    icon_draw_specification = table.deepcopy(fabricator.icon_draw_specification),
    gui_mode = "none",
    picture = util.empty_sprite(),
    energy_source = {
      type = "electric",
      usage_priority = "secondary-input",
      buffer_capacity = "100kJ",
      input_flow_limit = "5MW",
      render_no_power_icon = false,
      render_no_network_icon = false
    }
  }
})

-- Must match INSERT_MODES in scripts/fabricator.lua.
for _, control in pairs({ "drop-cursor", "fast-entity-transfer", "fast-entity-split" }) do
  data:extend({
    {
      type = "custom-input",
      name = FABRICATOR .. "-" .. control,
      key_sequence = "",
      linked_game_control = control,
      include_selected_prototype = true
    }
  })
end