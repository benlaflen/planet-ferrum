local BOT = "ferrum-overclock-robot"
local TINT = { 0.85, 0.65, 1.0 }

local magnet = data.raw.item["ferrum-rare-earth-magnet"]

local function tint_sprites(node, tint)
  if type(node) ~= "table" then return end
  if node.filename or node.filenames or node.stripes then node.tint = tint end
  for key, child in pairs(node) do
    if not (type(key) == "string" and (key:find("^shadow") or key == "sparks" or key == "smoke")) then
      tint_sprites(child, tint)
    end
  end
end

local robot = table.deepcopy(data.raw["logistic-robot"]["logistic-robot"])
robot.name = BOT
robot.minable.result = BOT
-- Fires on every dispatch from a roboport; handled in scripts/overclock.lua.
robot.created_effect = {
  type = "direct",
  action_delivery = {
    type = "instant",
    source_effects = { type = "script", effect_id = "ferrum-overclock" }
  }
}
tint_sprites(robot, TINT)

local base_item = data.raw.item["logistic-robot"]
local icons = {
  { icon = base_item.icon, icon_size = base_item.icon_size },
  { icon = magnet.icons[1].icon, icon_size = magnet.icons[1].icon_size, scale = 0.3 }
}
robot.icon = nil
robot.icons = icons

local item = table.deepcopy(base_item)
item.name = BOT
item.place_result = BOT
item.icon = nil
item.icons = icons
item.order = base_item.order .. "-overclock"

data:extend({
  robot,
  item,
  {
    type = "recipe",
    name = BOT,
    categories = { "ferrum-fabrication" },
    enabled = true,
    energy_required = 1,
    ingredients = {
      { type = "item", name = "flying-robot-frame", amount = 1 },
      { type = "item", name = "ferrum-rare-earth-magnet",  amount = 1 },
      { type = "item", name = "processing-unit",    amount = 2 }
    },
    results = { { type = "item", name = BOT, amount = 1 } }
  }
})