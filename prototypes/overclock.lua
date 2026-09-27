local DURATION = 3 * 60
local BOOST = 1.25
-- Dock modules are written into the fabricator booster by scripts/fabricator.lua; overclocking them would inflate fabricator bonuses.
local EXCLUDED_CATEGORY = "ferrum-fabricator-dock"

local overclocked = {}
for name, module in pairs(data.raw.module) do
  if module.category ~= EXCLUDED_CATEGORY then
    local copy = table.deepcopy(module)
    copy.name = "overclocked-" .. name
    copy.localised_name = { "item-name.overclocked-module", module.localised_name or { "item-name." .. name } }
    -- Scales penalties (e.g. speed module consumption) as well as bonuses.
    for effect, value in pairs(copy.effect) do copy.effect[effect] = value * BOOST end
    copy.hidden = true
    copy.next_upgrade = nil
    copy.hidden_in_factoriopedia = true
    copy.auto_recycle = false
    copy.spoil_ticks = DURATION
    copy.spoil_result = name
    copy.spoil_to_trigger_result = nil
    table.insert(overclocked, copy)
  end
end
data:extend(overclocked)