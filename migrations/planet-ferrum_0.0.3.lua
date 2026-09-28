-- 0.0.2 ran fabricators on their own recipe copies; the engine has already cleared those, this clears the rest.
for _, surface in pairs(game.surfaces) do
  for _, host in pairs(surface.find_entities_filtered({ name = "ferrum-fabricator" })) do
    for _, item in pairs(host.set_recipe(nil)) do
      surface.spill_item_stack({ position = host.position, stack = item })
    end
  end
end