require("prototypes.rare-earth")
require("prototypes.robots")

local PLANET = "ferrum"
local SOURCE = data.raw.planet["fulgora"]
local STARMAP = "__planet-ferrum__/graphics/icons/starmap-planet-" .. PLANET .. ".png"
-- Fog exposes only colours and animation speed; lighter colours read as denser against the dark scene.
local FOG_COLORS = { { 70, 95, 170, 1 }, { 40, 55, 120, 1 } }
local CLOUD_OPACITY = 0.5
local asteroid_util = require("__space-age__.prototypes.planet.asteroid-spawn-definitions")

-- Ferrum's own belt: a shallow gravity well holds very little, so the planet's definitions are the
-- route's scaled right down by asteroid_spawn_influence.
local FERRUM_ORBIT_INFLUENCE = 0.15

local function route(from)
  local ratios = asteroid_util[from .. "_ratio"]
  local chunks = asteroid_util[from .. "_chunks"]
  local medium = asteroid_util[from .. "_medium"]
  return {
    probability_on_range_chunk = {
      { position = 0.1, probability = chunks, angle_when_stopped = asteroid_util.chunk_angle },
      { position = 0.9, probability = chunks * 0.5, angle_when_stopped = asteroid_util.chunk_angle }
    },
    probability_on_range_medium = {
      { position = 0.1, probability = medium, angle_when_stopped = asteroid_util.medium_angle },
      { position = 0.5, probability = medium * 3, angle_when_stopped = asteroid_util.medium_angle },
      { position = 0.9, probability = medium * 0.5, angle_when_stopped = asteroid_util.medium_angle }
    },
    type_ratios = {
      { position = 0.1, ratios = ratios },
      -- Iron-heavy, as the debris of a metal world should be.
      { position = 0.9, ratios = { 6, 2, 1, 0 } }
    }
  }
end

local fog = table.deepcopy(data.raw.planet["gleba"].surface_render_parameters.fog)
fog.color1, fog.color2 = FOG_COLORS[1], FOG_COLORS[2]
local clouds = table.deepcopy(SOURCE.surface_render_parameters.clouds)
clouds.opacity, clouds.opacity_at_night = CLOUD_OPACITY, CLOUD_OPACITY

data:extend({
  {
    type = "surface-property",
    name = "ferrum-habitability",
    default_value = 0,
    localised_unit_key = "surface-property-unit.ferrum-habitability"
  },
  {
    type = "surface-property",
    name = "ferrum-belt-clearance",
    default_value = 0,
    localised_unit_key = "surface-property-unit.ferrum-belt-clearance"
  }
})

data:extend({
  {
    type = "planet",
    name = PLANET,
    icon = STARMAP,
    icon_size = 512,
    starmap_icon = STARMAP,
    starmap_icon_size = 512,
    subgroup = "planets",
    order = "z[ferrum]",
    map_gen_settings = require("prototypes.mapgen"),
    pollutant_type = nil,
    gravity_pull = 10,
    distance = 28,
    orientation = 0.22,
    magnitude = 0.5,
    label_orientation = 0.25,
    surface_properties = {
      ["ferrum-habitability"] = 100,
      ["ferrum-belt-clearance"] = 100,
      ["day-night-cycle"] = 8 * 60 * 60,
      ["magnetic-field"] = 40,
      ["solar-power"] = 360,
      pressure = 2000,
      gravity = 20
    },
    asteroid_spawn_influence = FERRUM_ORBIT_INFLUENCE,
    asteroid_spawn_definitions = asteroid_util.spawn_definitions(route("fulgora"), 0.9),
    surface_render_parameters = {
      fog = fog,
      clouds = clouds,
      -- control.lua holds daytime between 0.40 and 0.6, so only this part of the cycle is ever shown.
      day_night_cycle_color_lookup = {
        { 0.0, "__space-age__/graphics/lut/fulgora-3-after-sunset.png" },
        { 0.5, "__space-age__/graphics/lut/fulgora-4-before-dawn.png" }
      }
    }
  },
  {
    type = "space-connection",
    name = "fulgora-" .. PLANET,
    subgroup = "planet-connections",
    order = "z",
    from = "fulgora",
    to = PLANET,
    length = 10000,
    asteroid_spawn_definitions = asteroid_util.spawn_definitions(route("fulgora"))
  },
  {
    type = "space-connection",
    name = "vulcanus-" .. PLANET,
    subgroup = "planet-connections",
    order = "z",
    from = "vulcanus",
    to = PLANET,
    length = 10000,
    asteroid_spawn_definitions = asteroid_util.spawn_definitions(route("vulcanus"))
  }
})

local port = table.deepcopy(data.raw.roboport["roboport"])
port.name = PLANET .. "-roboport"
port.next_upgrade = nil
port.energy_source = { type = "void" }
port.minable = nil
port.flags = { "placeable-player", "player-creation", "not-deconstructable", "not-blueprintable", "not-upgradable" }

data:extend({ port })

require("prototypes.fabricator")
require("prototypes.infuser")
require("prototypes.branch")
require("prototypes.techs")