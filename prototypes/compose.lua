-- Layout in 64px icon space: shift is from the centre, scale is relative to a full-size icon.
local function compose(parts)
  local layers = {}
  for _, part in pairs(parts) do
    local prototype = part.prototype
    if not prototype then
      for _, kind in pairs({ "item", "fluid", "recipe", "technology", "tool" }) do
        prototype = prototype or (part[kind] and data.raw[kind][part[kind]])
      end
    end
    local source = prototype.icons and prototype.icons[1] or prototype
    table.insert(layers, {
      icon = source.icon,
      icon_size = source.icon_size or 64,
      tint = part.tint or source.tint,
      scale = 0.5 * (part.scale or 1) * (source.icon_size == 256 and 0.25 or 1),
      shift = part.shift
    })
  end
  return layers
end

return compose