require("scripts.fabricator")
-- Must stay after fabricator: infuser chains onto its event handlers.
require("scripts.infuser")
require("scripts.pedestal")
require("scripts.overclock")

local subscribe = require("scripts.events")

local PLANET = "ferrum"
local TECH = PLANET .. "-contact"
local PORT = PLANET .. "-roboport"
local BELT_TECH = "ferrum-deionizing-belts"
-- scripts/fabricator.lua owns on_nth_tick(60); on_nth_tick replaces any handler already on the same interval.
local SLOW_TICK = 120
-- Surface daytime is frozen and swung between these over the planet's day-night cycle (0.45 = fully dark).
local DAYTIME_DAY, DAYTIME_NIGHT = 0.40, 0.45
-- Lightning flashes briefly pull daytime toward noon (0.30 is about 80% brightness, 0.36 about 50%).
local FLASH_CHANCE = 0.01
local FLASH_MAX_PULSES = 3
local FLASH_DAYTIME = { 0.30, 0.36 }
-- Fire resistance per frontline-robotics level as { flat, percent }. Must match FRONTLINE in prototypes/techs.lua.
local FRONTLINE = { { 5, 0.90 }, { 10, 0.95 }, { 20, 0.99 }, { 0, 1 } }

local KIT = {
  {
    name = PORT,
    offset = { 0, 0 },
    stock = {
      { name = "logistic-robot",     count = 5 },
      { name = "construction-robot", count = 1 }
    }
  },
  {
    name = "storage-chest",
    offset = { 2.5, 2.5 },
    stock = {
      { name = "passive-provider-chest", count = 1 },
      { name = "requester-chest",        count = 1 },
      { name = "inserter",               count = 2 }
    }
  },
}

-- Tile offsets from the roboport position; the ring must stay clear of the KIT footprint.
local WALL_MIN, WALL_MAX = -4, 5

local function apply_belt_clearance(force, surface)
  if force.technologies[BELT_TECH].researched then surface.set_property("ferrum-belt-clearance", 0) end
end

subscribe(defines.events.on_research_finished, function(event)
  local force = event.research.force
  local planet = game.planets[PLANET]

  if event.research.name == BELT_TECH then
    if planet.surface then apply_belt_clearance(force, planet.surface) end
    return
  end
  if event.research.name ~= TECH then return end

  force.print({ "messages.ferrum-landing-impossible" })

  local surface = planet.surface or planet.create_surface()
  apply_belt_clearance(force, surface)
  if surface.count_entities_filtered { name = PORT } > 0 then return end

  surface.request_to_generate_chunks({ 0, 0 }, 4)
  surface.force_generate_chunk_requests()

  local found = surface.find_non_colliding_position(PORT, { 0, 0 }, 128, 1) or { x = 0, y = 0 }
  local base = { x = math.floor(found.x + 0.5), y = math.floor(found.y + 0.5) }
  local area = { { base.x + WALL_MIN, base.y + WALL_MIN }, { base.x + WALL_MAX + 1, base.y + WALL_MAX + 1 } }

  for _, obstacle in pairs(surface.find_entities_filtered { area = area, type = { "tree", "simple-entity", "cliff" } }) do
    obstacle.destroy()
  end

  local tiles, walls = {}, {}
  for x = WALL_MIN, WALL_MAX do
    for y = WALL_MIN, WALL_MAX do
      local edge = x == WALL_MIN or x == WALL_MAX or y == WALL_MIN or y == WALL_MAX
      table.insert(tiles, { name = edge and "hazard-concrete-left" or "refined-concrete", position = { base.x + x, base.y + y } })
      if edge then table.insert(walls, { base.x + x + 0.5, base.y + y + 0.5 }) end
    end
  end
  surface.set_tiles(tiles, true)
  for _, position in pairs(walls) do
    surface.create_entity { name = "stone-wall", position = position, force = force, raise_built = true }
  end

  for _, entry in pairs(KIT) do
    local entity = surface.create_entity {
      name = entry.name,
      position = { base.x + entry.offset[1], base.y + entry.offset[2] },
      direction = entry.direction,
      force = force,
      raise_built = true
    }
    if entity then
      entity.destructible = false
      entity.minable_flag = false
      for _, stack in pairs(entry.stock) do entity.insert(stack) end
    end
  end

  force.chart(surface, {
    { base.x - 128, base.y - 128 },
    { base.x + 128, base.y + 128 }
  })
end)

script.on_event(defines.events.on_space_platform_changed_state, function(event)
  local platform = event.platform
  if platform.state ~= defines.space_platform_state.waiting_at_station then return end
  if not (platform.space_location and platform.space_location.name == PLANET) then return end
  local tech = platform.force.technologies[TECH]
  if not tech.researched then tech.researched = true end
end)

script.on_nth_tick(SLOW_TICK, function()
  local surface = game.planets[PLANET].surface
  if not surface then return end

  surface.freeze_daytime = true
  local cycle = surface.get_property("day-night-cycle")
  local phase = (game.tick % cycle) / cycle
  storage.daytime = DAYTIME_DAY + (DAYTIME_NIGHT - DAYTIME_DAY) * (1 - math.cos(2 * math.pi * phase)) / 2
  if not storage.flash_on then surface.daytime = storage.daytime end
end)

script.on_event(defines.events.on_entity_damaged, function(event)
  local entity = event.entity
  local technologies = entity.force.technologies
  local tier
  for level = #FRONTLINE, 1, -1 do
    if technologies["ferrum-frontline-robotics-" .. level].researched then
      tier = FRONTLINE[level]
      break
    end
  end
  if not tier then return end

  -- Engine resistance formula: flat first, then percent.
  local flat, percent = tier[1], tier[2]
  local damage = event.original_damage_amount
  damage = damage > flat and damage - flat or 1 / (2 + flat - damage)
  damage = damage * (1 - percent)
  if damage < event.final_damage_amount then entity.health = entity.health + event.final_damage_amount - damage end
end, {
  { filter = "type", type = "construction-robot" },
  { filter = "type", type = "logistic-robot", mode = "or" },
  { filter = "damage-type", type = "fire", mode = "and" }
})

script.on_nth_tick(6, function()
  local surface = game.planets[PLANET].surface
  if surface then
    storage.flash_pulses = storage.flash_pulses or 0
    if storage.flash_on then
      storage.flash_on = false
      surface.daytime = storage.daytime or DAYTIME_NIGHT
    elseif storage.flash_pulses > 0 then
      storage.flash_pulses = storage.flash_pulses - 1
      storage.flash_on = true
      surface.daytime = FLASH_DAYTIME[1] + math.random() * (FLASH_DAYTIME[2] - FLASH_DAYTIME[1])
    elseif math.random() < FLASH_CHANCE then
      storage.flash_pulses = math.random(1, FLASH_MAX_PULSES)
    end
  end

  for _, player in pairs(game.connected_players) do
    local character = player.character
    if character and character.valid and character.surface.name == PLANET then
      character.damage(100, game.forces.neutral, "poison")
    end
  end
end)

script.on_event(defines.events.on_player_changed_surface, function(event)
  local player = game.get_player(event.player_index)
  local character = player and player.character
  if not character then return end

  storage.origins = storage.origins or {}
  local surface = character.surface
  if surface.platform then
    storage.origins[event.player_index] = surface.index
  elseif surface.name == PLANET then
    local previous = game.get_surface(event.surface_index)
    if previous and previous.platform then storage.origins[event.player_index] = previous.index end
  end
end)

script.on_event(defines.events.on_player_respawned, function(event)
  local player = game.get_player(event.player_index)
  if not player or not player.character then return end
  if player.character.surface.name ~= PLANET then return end

  local index = storage.origins and storage.origins[event.player_index]
  local origin = index and game.get_surface(index)
  local hub = origin and origin.platform and origin.platform.hub
  if hub and hub.valid then
    player.teleport(origin.find_non_colliding_position("character", hub.position, 32, 1) or hub.position, origin)
  else
    local nauvis = game.planets["nauvis"].surface
    player.teleport(player.force.get_spawn_position(nauvis), nauvis)
  end
end)
-- Unlocks for recipes added in an update (e.g. the Fabricator-only copies) only apply to already-researched techs after a reset.
script.on_configuration_changed(function()
  for _, force in pairs(game.forces) do force.reset_technology_effects() end
end)