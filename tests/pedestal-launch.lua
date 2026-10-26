-- Run from the repository root with Lua, or: nvim --headless -l tests/pedestal-launch.lua
local handlers = {}
defines = {
  events = {
    on_research_finished = 1, on_gui_opened = 2, on_gui_click = 3,
    on_gui_closed = 4, on_rocket_launched = 5, on_cargo_pod_finished_ascending = 6
  },
  inventory = { cargo_unit = 7 }
}
script = {
  get_event_handler = function(event) return handlers[event] end,
  on_event = function(event, handler) handlers[event] = handler end,
  on_nth_tick = function() end
}
require("scripts.pedestal")
assert(not handlers[defines.events.on_rocket_launched], "The rocket no longer owns its cargo")
local launch = assert(handlers[defines.events.on_cargo_pod_finished_ascending])
local names = { "ferrum-full-agglomeration-slow", "ferrum-full-molten-iron-slow" }
local messages = 0
local force = { technologies = {}, print = function() messages = messages + 1 end }
for _, name in ipairs(names) do force.technologies[name] = { enabled = false, researched = false } end
local count = 1
local cargo = { get_item_count = function(name)
  assert(name == "ferrum-robotics-science-pack")
  return count
end }
local reads = 0
local pod = { valid = true, surface = { name = "ferrum" }, force = force,
  get_inventory = function(index)
    assert(index == defines.inventory.cargo_unit)
    reads = reads + 1
    return cargo
  end
}
local event = { cargo_pod = pod, launched_by_rocket = true }
launch({ launched_by_rocket = true })
pod.valid = false; launch(event); pod.valid = true
pod.surface.name = "nauvis"; launch(event); pod.surface.name = "ferrum"
event.launched_by_rocket = false; launch(event); event.launched_by_rocket = true
assert(reads == 0, "Ignore non-rocket, invalid, missing and off-planet pods")
force.technologies[names[1]].enabled = true
local inventory = cargo
cargo = nil; launch(event); cargo = inventory
count = 0; launch(event); count = 1
assert(messages == 0 and not force.technologies[names[1]].researched)
launch(event)
assert(force.technologies[names[1]].researched and not force.technologies[names[2]].researched)
assert(messages == 1)
launch(event)
assert(messages == 1, "Do not announce already completed research again")
force.technologies[names[2]].enabled = true
launch(event)
assert(force.technologies[names[2]].researched and messages == 2)
force.technologies[names[1]] = nil
launch(event)
assert(messages == 2)
print("PASS: cargo-pod launch research and rejection cases")
