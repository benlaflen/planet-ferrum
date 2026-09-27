-- True on 2.0, where recipes take category plus additional_categories, science packs are tools,
-- research triggers mine a single entity, and products use probability. Everything else is written
-- for 2.1 and translated in data-final-fixes.lua, so switching versions is a change to info.json alone.
-- The data stage exposes mods; the control stage exposes script.active_mods.
local versions = mods or (script and script.active_mods) or {}
return (versions["base"] or ""):find("^2%.0%.") ~= nil
