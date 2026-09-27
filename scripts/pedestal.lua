local subscribe = require("scripts.events")

local PLANET = "ferrum"
local ORIGIN = { 0, 0 }
local KEYS = { "cementation", "pyrolysis", "reclamation" }
-- Which two options each pedestal offers, and which technology each button researches.
local OPTIONS = {
  ["ferrum-pedestal-first"] = {
    { tech = "ferrum-first-cementation", key = "cementation" },
    { tech = "ferrum-first-pyrolysis", key = "pyrolysis" },
    { tech = "ferrum-first-reclamation", key = "reclamation" }
  },
  ["ferrum-pedestal-second-cementation"] = {
    { tech = "ferrum-second-pyrolysis", key = "pyrolysis" },
    { tech = "ferrum-second-reclamation", key = "reclamation" }
  },
  ["ferrum-pedestal-second-pyrolysis"] = {
    { tech = "ferrum-second-cementation", key = "cementation" },
    { tech = "ferrum-second-reclamation", key = "reclamation" }
  },
  ["ferrum-pedestal-second-reclamation"] = {
    { tech = "ferrum-second-cementation", key = "cementation" },
    { tech = "ferrum-second-pyrolysis", key = "pyrolysis" }
  },
  ["ferrum-pedestal-third"] = {
    { tech = "ferrum-choose-agglomeration", key = "agglomeration" },
    { tech = "ferrum-choose-molten-iron", key = "molten-iron" }
  }
}
-- Must match the produced() triggers in prototypes/branch.lua. Counted from Ferrum's own production
-- statistics, because a research trigger cannot be restricted to one surface.
local WATCH = {
  ["ferrum-adaptive-chemistry"] = { item = "ferrum-fabricator", count = 1 },
  ["ferrum-infusion-chemistry"] = { item = "ferrum-infuser", count = 1 },
  ["ferrum-second-pedestal-cementation"] = { item = "holmium-plate", count = 150 },
  ["ferrum-second-pedestal-pyrolysis"] = { item = "plastic-bar", count = 500 },
  ["ferrum-second-pedestal-reclamation"] = { item = "rocket-fuel", count = 50 },
  ["ferrum-late-cementation"] = { item = "ferrum-infuser", count = 1 },
  ["ferrum-late-reclamation"] = { item = "ferrum-infuser", count = 10 },
  ["ferrum-late-pyrolysis"] = { item = "ferrum-rare-earth-magnet", count = 25 },
  ["ferrum-crude-agglomeration"] = { item = "carbon", count = 100 },
  ["ferrum-crude-molten-iron"] = { item = "solid-fuel", count = 100 },
  ["ferrum-full-agglomeration-cheap"] = { item = "coal", count = 500 },
  ["ferrum-full-molten-iron-cheap"] = { item = "ferrum-rare-earth-magnet", count = 50 }
}
-- The two slow variants wait on a launch instead of a count.
local LAUNCH = { "ferrum-full-agglomeration-slow", "ferrum-full-molten-iron-slow" }
local LAUNCH_ITEM = "ferrum-robotics-science-pack"
-- control.lua owns 120 and 6, scripts/fabricator.lua owns 60, scripts/infuser.lua owns 1.
local WATCH_TICK = 181
local FRAME = "ferrum-pedestal-frame"
local HIGHLIGHT = { r = 1, g = 0.3, b = 0.2 }
local SECOND_PEDESTAL = "ferrum-second-pedestal-"
local BUTTON = "ferrum-pedestal-choice-"

local function technologies(force)
  return force.technologies
end

-- Scripted research does not raise the usual completion toast, so announce it.
local function finish(force, name)
  local tech = force.technologies[name]
  if not (tech and not tech.researched) then return end
  tech.researched = true
  force.print({ "ferrum.research-finished", { "technology-name." .. name } },
    { sound_path = "utility/research_completed", color = { r = 0.6, g = 0.9, b = 1 } })
end

local function enable(force, name, state)
  local tech = force.technologies[name]
  if tech and not tech.researched then tech.enabled = state end
end

local function highlights()
  storage.ferrum_highlights = storage.ferrum_highlights or {}
  return storage.ferrum_highlights
end

local function clear_highlight(pedestal)
  local id = highlights()[pedestal]
  local object = id and rendering.get_object_by_id(id)
  if object and object.valid then object.destroy() end
  highlights()[pedestal] = nil
end

local function spawn(force, pedestal)
  local planet = game.planets[PLANET]
  local surface = planet and planet.surface
  if not surface then return end
  if surface.count_entities_filtered { name = pedestal } > 0 then return end
  local position = surface.find_non_colliding_position(pedestal, ORIGIN, 64, 1) or ORIGIN
  local entity = surface.create_entity { name = pedestal, position = position, force = force }
  if not entity then return end

  entity.destructible = false
  entity.minable_flag = false
  force.chart(surface, { { position.x - 16, position.y - 16 }, { position.x + 16, position.y + 16 } })

  clear_highlight(pedestal)
  highlights()[pedestal] = rendering.draw_rectangle {
    color = HIGHLIGHT,
    width = 3,
    filled = false,
    left_top = entity,
    left_top_offset = { -1.2, -1.2 },
    right_bottom = entity,
    right_bottom_offset = { 1.2, 1.2 },
    surface = surface,
    forces = { force },
    draw_on_ground = false
  }.id

  -- Reveal what this obelisk can grant; the scripted trigger keeps them unresearchable until it is used.
  for _, option in pairs(OPTIONS[pedestal]) do enable(force, option.tech, true) end

  local tag = string.format("[gps=%d,%d,%s]", position.x, position.y, surface.name)
  force.print({ "ferrum.pedestal-appeared", tag }, { sound_path = "utility/new_objective", color = HIGHLIGHT })
end

local function close(player)
  local frame = player.gui.screen[FRAME]
  if frame then frame.destroy() end
end

local function open(player, pedestal)
  close(player)
  local frame = player.gui.screen.add { type = "frame", name = FRAME, direction = "vertical", caption = { "ferrum." .. pedestal } }
  frame.auto_center = true
  frame.add { type = "label", caption = { "ferrum.pedestal-hint" } }
  local row = frame.add { type = "flow", direction = "horizontal" }
  for _, option in pairs(OPTIONS[pedestal]) do
    row.add {
      type = "button",
      name = BUTTON .. option.tech,
      caption = { "ferrum.option-" .. option.key },
      tooltip = { "ferrum.option-" .. option.key .. "-tooltip" }
    }
  end
  player.opened = frame
end

local function chosen(force, tech_name)
  local slot, key = tech_name:match("^ferrum%-(first)%-(.+)$")
  if not slot then slot, key = tech_name:match("^ferrum%-(second)%-(.+)$") end

  if slot == "first" then
    for _, other in pairs(KEYS) do
      if other ~= key then enable(force, "ferrum-first-" .. other, false) end
    end
    enable(force, "ferrum-second-pedestal-" .. key, true)
    storage.ferrum_first = key
  elseif slot == "second" then
    for _, other in pairs(KEYS) do
      if other ~= key then enable(force, "ferrum-second-" .. other, false) end
    end
    -- Whatever neither pick took unlocks on its own trigger.
    for _, other in pairs(KEYS) do
      if other ~= key and other ~= storage.ferrum_first then enable(force, "ferrum-late-" .. other, true) end
    end
  elseif tech_name == "ferrum-choose-agglomeration" or tech_name == "ferrum-choose-molten-iron" then
    local picked = tech_name == "ferrum-choose-agglomeration" and "agglomeration" or "molten-iron"
    local other = picked == "agglomeration" and "molten-iron" or "agglomeration"
    enable(force, "ferrum-choose-" .. other, false)
    enable(force, "ferrum-full-" .. picked .. "-cheap", true)
    enable(force, "ferrum-full-" .. other .. "-slow", true)
  end
end

subscribe(defines.events.on_research_finished, function(event)
  local force = event.research.force
  local name = event.research.name

  if name == "ferrum-adaptive-chemistry" then
    spawn(force, "ferrum-pedestal-first")
  elseif name == "ferrum-infusion-chemistry" then
    spawn(force, "ferrum-pedestal-third")
    enable(force, "ferrum-crude-agglomeration", true)
    enable(force, "ferrum-crude-molten-iron", true)
  elseif name:sub(1, #SECOND_PEDESTAL) == SECOND_PEDESTAL then
    spawn(force, "ferrum-pedestal-second-" .. name:sub(#SECOND_PEDESTAL + 1))
  else
    chosen(force, name)
  end
end)

subscribe(defines.events.on_gui_opened, function(event)
  local entity = event.entity
  if not (entity and entity.valid and OPTIONS[entity.name]) then return end
  local player = game.get_player(event.player_index)
  if not player.admin then return end
  storage.ferrum_pedestal = storage.ferrum_pedestal or {}
  storage.ferrum_pedestal[event.player_index] = entity.name
  open(player, entity.name)
end)

subscribe(defines.events.on_gui_click, function(event)
  -- Plain prefix compare: BUTTON contains dashes, which are quantifiers in a Lua pattern.
  local name = event.element.name
  if name:sub(1, #BUTTON) ~= BUTTON then return end
  local tech_name = name:sub(#BUTTON + 1)
  local player = game.get_player(event.player_index)
  local pedestal = storage.ferrum_pedestal and storage.ferrum_pedestal[event.player_index]
  local tech = technologies(player.force)[tech_name]
  if not tech then return end

  finish(player.force, tech_name)
  if pedestal then
    local planet = game.planets[PLANET]
    local surface = planet and planet.surface
    for _, entity in pairs(surface and surface.find_entities_filtered { name = pedestal } or {}) do entity.destroy() end
    clear_highlight(pedestal)
  end
  for _, other in pairs(game.connected_players) do close(other) end
end)

subscribe(defines.events.on_gui_closed, function(event)
  if event.element and event.element.valid and event.element.name == FRAME then event.element.destroy() end
end)

-- Production statistics are cumulative, so each trigger counts from the moment its technology
-- became reachable rather than from the start of the game.
local function baselines(force)
  storage.ferrum_baselines = storage.ferrum_baselines or {}
  storage.ferrum_baselines[force.index] = storage.ferrum_baselines[force.index] or {}
  return storage.ferrum_baselines[force.index]
end

script.on_nth_tick(WATCH_TICK, function()
  local planet = game.planets[PLANET]
  local surface = planet and planet.surface
  if not surface then return end
  for _, force in pairs(game.forces) do
    local produced = force.get_item_production_statistics(surface)
    local baseline = baselines(force)
    for name, target in pairs(WATCH) do
      local tech = force.technologies[name]
      -- enabled means the path has reached this trigger; researched means it already fired.
      if tech and tech.enabled and not tech.researched then
        local count = produced.get_input_count(target.item)
        if not baseline[name] then
          baseline[name] = count
        elseif count - baseline[name] >= target.count then
          finish(force, name)
          baseline[name] = nil
        end
      end
    end
  end
end)

subscribe(defines.events.on_rocket_launched, function(event)
  local rocket = event.rocket
  if not (rocket and rocket.valid and rocket.surface.name == PLANET) then return end
  local cargo = rocket.get_inventory(defines.inventory.rocket)
  if not (cargo and cargo.get_item_count(LAUNCH_ITEM) > 0) then return end
  local force = rocket.force
  for _, name in pairs(LAUNCH) do
    local tech = force.technologies[name]
    if tech and tech.enabled then finish(force, name) end
  end
end)