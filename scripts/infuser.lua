local INFUSER = "ferrum-infuser"
local INTERVAL = 1
-- Crafts' worth of item ingredient kept inside the machine before items are left on the belt.
local BUFFER_CRAFTS = 2
local SPACING = 0.25
local INPUT = defines.inventory.crafter_input or defines.inventory.assembling_machine_input
local BELT_TYPES = { "transport-belt", "underground-belt", "splitter", "lane-splitter", "loader", "loader-1x1", "linked-belt" }
local OFFSET = {
  [defines.direction.north] = { 0, -1 },
  [defines.direction.east] = { 1, 0 },
  [defines.direction.south] = { 0, 1 },
  [defines.direction.west] = { -1, 0 }
}

local function infusers()
  storage.infuser_machines = storage.infuser_machines or {}
  return storage.infuser_machines
end

local function neighbor(machine, sign)
  local offset = OFFSET[machine.direction]
  if not offset then return nil end
  local at = { x = machine.position.x + offset[1] * sign, y = machine.position.y + offset[2] * sign }
  return machine.surface.find_entities_filtered { position = at, type = BELT_TYPES, limit = 1 }[1]
end

local function front(machine, belt, index)
  local offset = OFFSET[machine.direction]
  local line = belt.get_transport_line(index)
  local first, nearest
  for _, detail in pairs(line.get_detailed_contents()) do
    local p = belt.get_line_item_position(index, detail.position)
    local along = (machine.position.x - p.x) * offset[1] + (machine.position.y - p.y) * offset[2]
    if not first or along < nearest then first, nearest = detail, along end
  end
  if not first or nearest > 0.5 + SPACING then return nil end
  return { name = first.stack.name, count = 1, quality = first.stack.quality.name }, first.stack
end

local function take(stack)
  if stack.count > 1 then stack.count = stack.count - 1 else stack.clear() end
end

-- Side 1 is the left lane (defines.transport_line.left_line); flip the sign of lane if lanes come out swapped.
local function deliver(machine, target, side, item)
  local line = target.get_transport_line(side)
  return line.can_insert_at_back() and line.insert_at_back(item)
end

-- script.on_event replaces the previous handler, so this wraps whatever is already registered and merges filters.
local function subscribe(event, handler, filters)
  local previous = script.get_event_handler(event)
  if not previous then
    script.on_event(event, handler, filters)
    return
  end
  local existing = script.get_event_filter(event)
  local merged
  if existing and filters then
    merged = {}
    for _, filter in pairs(existing) do table.insert(merged, filter) end
    for _, filter in pairs(filters) do table.insert(merged, filter) end
  end
  script.on_event(event, function(e)
    previous(e)
    handler(e)
  end, merged)
end

local function on_built(event)
  local machine = event.entity
  if not (machine and machine.valid and machine.name == INFUSER) then return end
  infusers()[machine.unit_number] = machine
  script.register_on_object_destroyed(machine)
end

local filter = { { filter = "name", name = INFUSER } }
subscribe(defines.events.on_built_entity, on_built, filter)
subscribe(defines.events.on_robot_built_entity, on_built, filter)
subscribe(defines.events.on_space_platform_built_entity, on_built, filter)
subscribe(defines.events.script_raised_built, on_built, filter)
subscribe(defines.events.script_raised_revive, on_built, filter)

subscribe(defines.events.on_object_destroyed, function(event)
  infusers()[event.useful_id] = nil
end)

script.on_nth_tick(INTERVAL, function()
  for unit, machine in pairs(infusers()) do
    if machine.valid then
      local ahead = neighbor(machine, 1)
      if ahead and ahead.direction ~= machine.direction then ahead = nil end
      local behind = neighbor(machine, -1)
      if behind and behind.direction ~= machine.direction then behind = nil end
      local lines = behind and { behind.get_transport_line(1), behind.get_transport_line(2) }

      local output = machine.get_output_inventory()
      if ahead then
        for side = 1, 2 do
          local stack = output.get_contents()[1]
          if stack then
            local item = { name = stack.name, count = 1, quality = stack.quality }
            if deliver(machine, ahead, side, item) then output.remove(item) end
          end
        end
      end

      local recipe, quality = machine.get_recipe()
      if lines and recipe and machine.status ~= defines.entity_status.no_power then
        local input = machine.get_inventory(INPUT)
        local item, fluid
        for _, ingredient in pairs(recipe.ingredients) do
          if ingredient.type == "fluid" then fluid = ingredient else item = ingredient end
        end
        -- get_fluid_count reads the machine's buffer on both 2.0 and 2.1, unlike the fluidbox array.
        if item and fluid and machine.get_fluid_count(fluid.name) >= fluid.amount then
          local wanted = { name = item.name, quality = quality.name }
          local moved = true
          while moved do
            moved = false
            for side, line in pairs(lines) do
              local count = input.get_item_count(wanted)
              local insertable = input.get_insertable_count(wanted)
              local space = count < item.amount * BUFFER_CRAFTS and insertable > 0
              local first, stack
              if space then first, stack = front(machine, behind, side) end
              if first and first.name == wanted.name and first.quality == wanted.quality then
                take(stack)
                input.insert(first)
                moved = true
              end
            end
          end
        end
      end

      if lines and ahead then
        for side, line in pairs(lines) do
          local first, stack = front(machine, behind, side)
          if first and deliver(machine, ahead, side, first) then take(stack) end
        end
      end
    end
  end
end)