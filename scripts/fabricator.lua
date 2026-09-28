local FABRICATOR = "ferrum-fabricator"
local DOCK = FABRICATOR .. "-dock"
local BOOSTER = FABRICATOR .. "-booster"
local SIGNALS = FABRICATOR .. "-signals"
local LOAD = FABRICATOR .. "-charger-load"
local FRAME = FABRICATOR .. "-dock-panel"

local SLOTS = 3
local PER_SLOT = 10
-- Idle bots per type the scheduler leaves in normal roboports instead of handing to fabricators.
local RESERVE = 0
-- How long a request shortfall is assumed to be bots in flight before the credit is dropped.
local PENDING_TIMEOUT = 600
-- Joules per tick per charging pad; must match dock.charging_energy in prototypes/fabricator.lua.
local CHARGE_PER_PAD = 500000 / 60

-- Any robot not listed here counts as special (productivity), including other mods' robots.
local VANILLA = { ["construction-robot"] = "quality", ["logistic-robot"] = "speed" }
local PRECEDENCE = { quality = 1, speed = 2, productivity = 3 }
local ROBOT_TYPES = { { filter = "type", type = { "construction-robot", "logistic-robot" } } }
local ROBOT_ITEMS = { { filter = "place-result", elem_filters = ROBOT_TYPES } }
local WIRES = { defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green }

local robots

local function robot_list()
  if robots then return robots end
  robots = { list = {}, effect = {}, index = {} }
  for _, entity in pairs(prototypes.get_entity_filtered(ROBOT_TYPES)) do
    for _, place in pairs(entity.items_to_place_this or {}) do
      if not robots.effect[place.name] then
        robots.effect[place.name] = VANILLA[place.name] or "productivity"
        table.insert(robots.list, place.name)
      end
    end
  end
  table.sort(robots.list, function(a, b)
    local rank_a, rank_b = PRECEDENCE[robots.effect[a]], PRECEDENCE[robots.effect[b]]
    if rank_a ~= rank_b then return rank_a < rank_b end
    return a < b
  end)
  for index, name in pairs(robots.list) do robots.index[name] = index end
  return robots
end

local function fabricators()
  storage.fabricators = storage.fabricators or {}
  return storage.fabricators
end

local function viewers()
  storage.fabricator_viewers = storage.fabricator_viewers or {}
  return storage.fabricator_viewers
end

local function export(fab)
  local filters = {}
  for slot = 1, SLOTS do filters[slot] = fab.filters[slot] or "" end
  return {
    priority = fab.priority,
    filters = filters,
    read = fab.read,
    set_priority = fab.set_priority,
    priority_signal = fab.priority_signal,
    set_filters = fab.set_filters
  }
end

local function import(fab, settings)
  fab.priority = settings.priority or 0
  fab.filters = {}
  for slot = 1, SLOTS do
    local name = settings.filters and settings.filters[slot]
    if name and robot_list().effect[name] then fab.filters[slot] = name end
  end
  fab.read = settings.read
  fab.set_priority = settings.set_priority
  fab.priority_signal = settings.priority_signal
  fab.set_filters = settings.set_filters
end

local function attach_signals(fab)
  local signals = fab.host.surface.create_entity { name = SIGNALS, position = fab.host.position, force = fab.host.force }
  signals.destructible = false
  for _, wire in pairs(WIRES) do
    signals.get_wire_connector(wire, true).connect_to(fab.host.get_wire_connector(wire, true), false, defines.wire_origin.script)
  end
  fab.signals = signals
  fab.output = nil
end

local function attach_load(fab)
  local load = fab.host.surface.create_entity { name = LOAD, position = fab.host.position, force = fab.host.force }
  load.destructible = false
  load.power_usage = 0
  fab.load = load
end

local function refresh(player, fab)
  local frame = player.gui.relative[FRAME]
  if not frame then return end
  for slot = 1, SLOTS do
    local button = frame.dock["docked_" .. slot]
    local entry = fab.slots and fab.slots[slot]
    if entry and entry.shown > 0 then
      button.sprite = "item/" .. entry.name
      button.number = entry.shown
    else
      button.sprite = ""
      button.number = nil
    end
    button.tooltip = entry and (entry.shown .. " docked / " .. entry.count .. " allocated") or "Empty"

    local picker = frame.dock["filter_" .. slot]
    picker.locked = fab.set_filters == true
    if fab.set_filters then picker.elem_value = fab.active_filters and fab.active_filters[slot] end
  end
  local field = frame.settings.priority
  field.enabled = not fab.set_priority
  if fab.set_priority then field.text = tostring(fab.active_priority or 0) end
end

local function on_built(event)
  local host = event.entity
  if not (host and host.valid and host.name == FABRICATOR) then return end

  local dock = host.surface.create_entity { name = DOCK, position = host.position, force = host.force }
  local booster = host.surface.create_entity { name = BOOSTER, position = host.position, force = host.force }
  dock.destructible = false
  booster.destructible = false

  local fab = {
    host = host,
    dock = dock,
    booster = booster,
    priority = 0,
    filters = {},
    requested = {},
    since = {},
    modules = ""
  }
  attach_signals(fab)
  attach_load(fab)
  if event.tags and event.tags.fabricator then import(fab, event.tags.fabricator) end
  fabricators()[host.unit_number] = fab
  script.register_on_object_destroyed(host)
end

local built_filter = { { filter = "name", name = FABRICATOR } }
script.on_event(defines.events.on_built_entity, on_built, built_filter)
script.on_event(defines.events.on_robot_built_entity, on_built, built_filter)
script.on_event(defines.events.script_raised_built, on_built, built_filter)
script.on_event(defines.events.script_raised_revive, on_built, built_filter)

script.on_event(defines.events.on_object_destroyed, function(event)
  local fab = fabricators()[event.useful_id]
  if not fab then return end
  fabricators()[event.useful_id] = nil

  if fab.dock.valid then
    local dock = fab.dock
    for _, stack in pairs(dock.get_inventory(defines.inventory.roboport_robot).get_contents()) do
      local robot = prototypes.item[stack.name].place_result
      for _ = 1, stack.count do
        dock.surface.create_entity { name = robot.name, quality = stack.quality, position = dock.position, force = dock.force }
      end
    end
    dock.destroy()
  end
  if fab.booster.valid then fab.booster.destroy() end
  if fab.signals and fab.signals.valid then fab.signals.destroy() end
  if fab.load and fab.load.valid then fab.load.destroy() end
end)

script.on_event(defines.events.on_player_setup_blueprint, function(event)
  local blueprint = event.record or event.stack
  if not blueprint or (blueprint.object_name == "LuaItemStack" and not blueprint.valid_for_read) then return end
  for index, entity in pairs(event.mapping.get()) do
    local fab = entity.valid and entity.name == FABRICATOR and fabricators()[entity.unit_number]
    if fab then blueprint.set_blueprint_entity_tag(index, "ferrum-fabricator", export(fab)) end
  end
end)

script.on_event(defines.events.on_entity_settings_pasted, function(event)
  local source = fabricators()[event.source.unit_number]
  local destination = fabricators()[event.destination.unit_number]
  if source and destination then import(destination, export(source)) end
end)

script.on_nth_tick(60, function(event)
  local known = robot_list()
  local groups = {}

  for _, fab in pairs(fabricators()) do
    if fab.host.valid and fab.dock.valid then
      if not (fab.signals and fab.signals.valid) then attach_signals(fab) end
      if not (fab.load and fab.load.valid) then attach_load(fab) end
      fab.load.power_usage = fab.dock.logistic_cell.charging_robot_count * CHARGE_PER_PAD

      local networks = {}
      for _, wire in pairs(WIRES) do
        local network = fab.host.get_circuit_network(wire)
        if network then table.insert(networks, network) end
      end

      fab.active_priority = fab.priority
      if fab.set_priority then
        fab.active_priority = 0
        if fab.priority_signal then
          for _, network in pairs(networks) do
            fab.active_priority = fab.active_priority + network.get_signal(fab.priority_signal)
          end
        end
      end

      fab.active_filters = fab.filters
      if fab.set_filters then
        local counts = {}
        for _, network in pairs(networks) do
          for _, signal in pairs(network.signals or {}) do
            local id = signal.signal
            if (id.type or "item") == "item" and known.effect[id.name] and (id.quality or "normal") == "normal" then
              counts[id.name] = (counts[id.name] or 0) + signal.count
            end
          end
        end

        local incoming = {}
        for name, count in pairs(counts) do
          if count > 0 then table.insert(incoming, { name = name, count = count }) end
        end
        table.sort(incoming, function(a, b)
          if a.count ~= b.count then return a.count > b.count end
          return known.index[a.name] > known.index[b.name]
        end)

        local chosen = {}
        if #incoming == 1 then
          for _ = 1, math.min(SLOTS, incoming[1].count) do table.insert(chosen, incoming[1].name) end
        elseif #incoming == 2 then
          chosen = { incoming[1].name, incoming[2].name }
          if incoming[1].count > incoming[2].count or incoming[1].count > 1 then
            table.insert(chosen, incoming[1].name)
          end
        else
          for i = 1, math.min(SLOTS, #incoming) do table.insert(chosen, incoming[i].name) end
        end
        table.sort(chosen, function(a, b) return known.index[a] < known.index[b] end)
        fab.active_filters = chosen
      end

      local network = fab.dock.logistic_network
      if network then
        local group = groups[network.network_id]
        if not group then
          group = { network = network, fabs = {} }
          groups[network.network_id] = group
        end
        table.insert(group.fabs, fab)
      end
    end
  end

  for _, group in pairs(groups) do
    local pool = {}
    for _, name in pairs(known.list) do pool[name] = 0 end

    for _, cell in pairs(group.network.cells) do
      local owner = cell.owner
      if owner.type == "roboport" then
        for _, stack in pairs(owner.get_inventory(defines.inventory.roboport_robot).get_contents()) do
          if stack.quality == "normal" and pool[stack.name] then pool[stack.name] = pool[stack.name] + stack.count end
        end
      end
    end

    for _, fab in pairs(group.fabs) do
      local contents = fab.dock.get_inventory(defines.inventory.roboport_robot).get_contents()
      fab.contents = {}
      for _, name in pairs(known.list) do fab.contents[name] = 0 end
      for _, stack in pairs(contents) do
        if stack.quality == "normal" and fab.contents[stack.name] then fab.contents[stack.name] = fab.contents[stack.name] + stack.count end
      end

      for _, name in pairs(known.list) do
        local held = fab.contents[name]
        local requested = fab.requested[name] or 0
        if held < requested then
          fab.since[name] = fab.since[name] or event.tick
          if event.tick - fab.since[name] < PENDING_TIMEOUT then pool[name] = pool[name] + requested - held end
        else
          fab.since[name] = nil
        end
      end

      local output = {}
      local keys = {}
      if fab.read then
        for _, stack in pairs(contents) do
          table.insert(output, stack)
          table.insert(keys, stack.name .. ":" .. stack.quality .. ":" .. stack.count)
        end
      end
      local key = table.concat(keys, ",")
      if key ~= fab.output then
        local behavior = fab.signals.get_or_create_control_behavior()
        local section = behavior.get_section(1) or behavior.add_section()
        for index = section.filters_count, 1, -1 do section.clear_slot(index) end
        for index, stack in pairs(output) do
          section.set_slot(index, { value = { type = "item", name = stack.name, quality = stack.quality }, min = stack.count })
        end
        fab.output = key
      end
    end

    for name, count in pairs(pool) do pool[name] = math.max(0, count - RESERVE) end

    table.sort(group.fabs, function(a, b)
      if a.active_priority ~= b.active_priority then return a.active_priority > b.active_priority end
      return a.host.unit_number < b.host.unit_number
    end)

    for _, fab in pairs(group.fabs) do
      local targets = {}
      local assigned = {}
      for slot = 1, SLOTS do
        local name = fab.active_filters[slot]
        if not name then
          for _, candidate in pairs(known.list) do
            if not name or pool[candidate] > pool[name] then name = candidate end
          end
        end
        local take = name and math.min(PER_SLOT, pool[name]) or 0
        if name then
          pool[name] = pool[name] - take
          targets[name] = (targets[name] or 0) + take
        end
        assigned[slot] = { name = name, count = take }
      end

      local sections = fab.dock.get_logistic_sections()
      local section = sections.sections[1] or sections.add_section()
      for _, name in pairs(known.list) do
        local target = targets[name] or 0
        if target ~= (fab.requested[name] or 0) then
          if target > 0 then
            section.set_slot(known.index[name], { value = { type = "item", name = name, quality = "normal" }, min = target })
          else
            section.clear_slot(known.index[name])
          end
        end
      end
      fab.requested = targets

      local remaining = {}
      for name, count in pairs(fab.contents) do remaining[name] = count end
      local boosts = {}
      for slot = 1, SLOTS do
        local entry = assigned[slot]
        entry.shown = entry.name and math.min(entry.count, remaining[entry.name]) or 0
        if entry.name then
          remaining[entry.name] = remaining[entry.name] - entry.shown
          local effect = known.effect[entry.name]
          boosts[effect] = (boosts[effect] or 0) + entry.shown
        end
      end
      fab.slots = assigned

      local modules = {}
      for effect, count in pairs(boosts) do
        if count > 0 then table.insert(modules, FABRICATOR .. "-dock-" .. effect .. "-" .. count) end
      end
      table.sort(modules)
      local module_key = table.concat(modules, ",")
      if module_key ~= fab.modules then
        local inventory = fab.booster.get_module_inventory()
        inventory.clear()
        for _, module in pairs(modules) do inventory.insert { name = module, count = 1 } end
        fab.modules = module_key
      end
    end
  end

  for index, unit in pairs(viewers()) do
    local player = game.get_player(index)
    local fab = fabricators()[unit]
    if player and fab then refresh(player, fab) end
  end
end)

script.on_event(defines.events.on_gui_opened, function(event)
  local entity = event.entity
  if not (entity and entity.valid and entity.name == FABRICATOR) then return end
  local fab = fabricators()[entity.unit_number]
  if not fab then return end

  local player = game.get_player(event.player_index)
  if player.gui.relative[FRAME] then player.gui.relative[FRAME].destroy() end
  local tags = { fabricator_unit = entity.unit_number }

  local frame = player.gui.relative.add {
    type = "frame",
    name = FRAME,
    caption = "Robot dock",
    direction = "vertical",
    anchor = {
      gui = defines.relative_gui_type.assembling_machine_gui,
      position = defines.relative_gui_position.right,
      names = { FABRICATOR }
    }
  }

  local dock = frame.add { type = "table", name = "dock", column_count = SLOTS }
  for slot = 1, SLOTS do
    dock.add { type = "sprite-button", name = "docked_" .. slot, style = "inventory_slot" }
  end
  for slot = 1, SLOTS do
    local picker = dock.add {
      type = "choose-elem-button",
      name = "filter_" .. slot,
      elem_type = "item",
      elem_filters = ROBOT_ITEMS,
      tooltip = "Slot filter (empty = any robot)",
      tags = { fabricator_unit = entity.unit_number, slot = slot }
    }
    picker.elem_value = fab.filters[slot]
  end

  local settings = frame.add { type = "flow", name = "settings", direction = "horizontal" }
  settings.style.vertical_align = "center"
  settings.add { type = "label", caption = "Priority" }
  local field = settings.add {
    type = "textfield",
    name = "priority",
    text = tostring(fab.priority),
    numeric = true,
    allow_negative = true,
    allow_decimal = false,
    tags = tags
  }
  field.style.width = 60

  frame.add { type = "line" }
  frame.add { type = "label", caption = "Circuit network", style = "caption_label" }
  frame.add { type = "checkbox", name = "read", caption = "Read dock contents", state = fab.read == true, tags = tags }
  local priority_row = frame.add { type = "flow", direction = "horizontal" }
  priority_row.style.vertical_align = "center"
  priority_row.add { type = "checkbox", name = "set_priority", caption = "Set priority", state = fab.set_priority == true, tags = tags }
  local chooser = priority_row.add { type = "choose-elem-button", name = "priority_signal", elem_type = "signal", tags = tags }
  chooser.elem_value = fab.priority_signal
  frame.add {
    type = "checkbox",
    name = "set_filters",
    caption = "Set filters",
    state = fab.set_filters == true,
    tags = tags,
    tooltip = "Robot signals above zero assign slots. One robot: min(3, value) slots. Two: one each, third to the higher value, "
      .. "or on a tie above 1 to special > logistic > construction. Three: one each."
  }

  viewers()[player.index] = entity.unit_number
  refresh(player, fab)
end)

script.on_event(defines.events.on_gui_closed, function(event)
  if not (event.entity and event.entity.valid and event.entity.name == FABRICATOR) then return end
  local player = game.get_player(event.player_index)
  if player.gui.relative[FRAME] then player.gui.relative[FRAME].destroy() end
  viewers()[event.player_index] = nil
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
  local element = event.element
  local fab = element.tags.fabricator_unit and fabricators()[element.tags.fabricator_unit]
  if not fab then return end
  fab[element.name] = element.state

  local player = game.get_player(event.player_index)
  local frame = player.gui.relative[FRAME]
  if frame and not element.state then
    if element.name == "set_filters" then
      for slot = 1, SLOTS do frame.dock["filter_" .. slot].elem_value = fab.filters[slot] end
    elseif element.name == "set_priority" then
      frame.settings.priority.text = tostring(fab.priority)
    end
  end
  refresh(player, fab)
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
  local element = event.element
  local tags = element.tags
  local fab = tags.fabricator_unit and fabricators()[tags.fabricator_unit]
  if not fab then return end
  if tags.slot then
    fab.filters[tags.slot] = element.elem_value
  elseif element.name == "priority_signal" then
    fab.priority_signal = element.elem_value
  end
end)

script.on_event(defines.events.on_gui_text_changed, function(event)
  local element = event.element
  local fab = element.tags.fabricator_unit and fabricators()[element.tags.fabricator_unit]
  local value = tonumber(element.text)
  if fab and value and element.name == "priority" then fab.priority = math.floor(value) end
end)

-- Must match the controls in prototypes/fabricator.lua.
local INSERT_MODES = {
  ["drop-cursor"] = "one",
  ["fast-entity-split"] = "half",
  ["fast-entity-transfer"] = "stack"
}

for control, mode in pairs(INSERT_MODES) do
  script.on_event(FABRICATOR .. "-" .. control, function(event)
    local player = game.get_player(event.player_index)
    local entity = player.selected
    if not (entity and entity.valid and entity.name == FABRICATOR and player.can_reach_entity(entity)) then return end
    local fab = fabricators()[entity.unit_number]
    local cursor = player.cursor_stack
    if not (fab and fab.dock.valid and cursor and cursor.valid_for_read and robot_list().effect[cursor.name]) then return end

    local count = mode == "one" and 1 or mode == "half" and math.ceil(cursor.count / 2) or cursor.count
    local inserted = fab.dock.get_inventory(defines.inventory.roboport_robot).insert({ name = cursor.name, quality = cursor.quality.name, count = count })
    if inserted == 0 then return end
    if inserted == cursor.count then cursor.clear() else cursor.count = cursor.count - inserted end
  end)
end