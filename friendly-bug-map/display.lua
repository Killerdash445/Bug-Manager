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
  local pref = Display.preferences(force)
  local chosen = presets[pref.preset] or {
    group = Rules.option("group"),
    cap = Rules.option("cap"),
    team = Rules.option("team"),
    count = Rules.option("count"),
    kind = Rules.option("kind"),
  }
  local cap = math.min(chosen.cap, Rules.option("cap"))
  return {
    group = chosen.group, cap = cap, team = chosen.team, count = chosen.count, kind = chosen.kind,
    reserve = math.min(pref.nest_slots or 0, cap),
    icon_min = pref.icon_min or 1, label_min = pref.label_min or 1,
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
    local identities = pref.identities
    if identities and identities[event.source_name] then
      identities[event.destination.name] = identities[event.destination.name] or identities[event.source_name]
      identities[event.source_name] = nil
    end
    if pref.excluded[event.source_name] then
      pref.excluded[event.source_name] = nil
      pref.excluded[event.destination.name] = true
    end
  end
end

return Display
