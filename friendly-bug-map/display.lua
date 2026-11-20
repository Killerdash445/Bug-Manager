-- Preferences belong to the receiving force. The master switch is server-wide.
local Rules = require("rules")

local Display = {}
Display.names = { "Server settings", "Minimal", "Balanced", "Detailed" }
local presets = {
  Minimal = { group = true, cap = 8, team = false, count = true, kind = false },
  Balanced = { group = true, cap = 32, team = true, count = true, kind = false },
  Detailed = { group = false, cap = 128, team = true, count = true, kind = true },
}

function Display.preferences(force)
  local pref = storage.displays[force.index]
  if not pref then
    pref = { show = true, nests = true, excluded = {}, preset = "Server settings" }
    storage.displays[force.index] = pref
  end
  pref.aliases = pref.aliases or {}
  return pref
end

function Display.style(force)
  local chosen = presets[Display.preferences(force).preset]
  if chosen then
    return {
      group = chosen.group,
      cap = math.min(chosen.cap, Rules.option("cap")),
      team = chosen.team,
      count = chosen.count,
      kind = chosen.kind,
    }
  end
  return {
    group = Rules.option("group"),
    cap = Rules.option("cap"),
    team = Rules.option("team"),
    count = Rules.option("count"),
    kind = Rules.option("kind"),
  }
end

function Display.allows(pref, source, kind)
  return pref.show and not pref.excluded[source] and (kind ~= "nest" or pref.nests)
end

function Display.merged(event)
  storage.displays[event.source_index] = nil
  for _, pref in pairs(storage.displays) do
    local aliases = pref.aliases
    if aliases and aliases[event.source_name] then
      aliases[event.destination.name] = aliases[event.destination.name]
        or aliases[event.source_name]
      aliases[event.source_name] = nil
    end
    if pref.excluded[event.source_name] then
      pref.excluded[event.source_name] = nil
      pref.excluded[event.destination.name] = true
    end
  end
end

return Display
