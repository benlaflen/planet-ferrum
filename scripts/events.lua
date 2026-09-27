-- script.on_event replaces whatever handler is already registered, so every handler for a shared
-- event goes through here to chain onto the previous one instead of silently dropping it.
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

return subscribe