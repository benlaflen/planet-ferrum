local PREFIX = "overclocked-"
local COOLDOWN = 30

script.on_event(defines.events.on_script_trigger_effect, function(e)
  if e.effect_id ~= "ferrum-overclock" then return end
  local robot = e.source_entity or e.target_entity
  if not (robot and robot.valid) then return end

  local roboport = robot.surface.find_entities_filtered({ type = "roboport", position = robot.position, radius = 3, limit = 1 })[1]
  if not roboport then return end

  -- Entries for destroyed roboports are never pruned; one number each.
  storage.overclock_last = storage.overclock_last or {}
  local last = storage.overclock_last[roboport.unit_number]
  if last and e.tick - last < COOLDOWN then return end
  storage.overclock_last[roboport.unit_number] = e.tick

  local p, r = roboport.position, roboport.logistic_cell.logistic_radius
  local beacons = roboport.surface.find_entities_filtered({
    type = "beacon",
    force = roboport.force,
    area = { { p.x - r, p.y - r }, { p.x + r, p.y + r } }
  })
  for _, beacon in pairs(beacons) do
    local inventory = beacon.get_module_inventory()
    for i = 1, #inventory do
      local stack = inventory[i]
      if stack.valid_for_read then
        if stack.name:sub(1, #PREFIX) == PREFIX then
          stack.spoil_percent = 0
        elseif prototypes.item[PREFIX .. stack.name] then
          stack.set_stack({ name = PREFIX .. stack.name, count = stack.count, quality = stack.quality.name })
        end
      end
    end
  end
end)