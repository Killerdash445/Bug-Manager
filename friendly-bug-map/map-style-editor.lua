local Text = require("ui-text")
local L = Text.get
local Editor = {}

local limits = { "icon_min", "label_min", "nest_slots" }
local identity = { "prefix", "colour" }

local function form(parent, name, fields, numeric)
  local box = parent.add { type = "flow", name = name, direction = "vertical" }
  local grid = box.add { type = "table", name = "fields", column_count = 2 }
  for _, key in ipairs(fields) do
    grid.add { type = "label", caption = L(key), tooltip = L(key .. "-hint") }
    local input = grid.add { type = "textfield", name = key, numeric = numeric, tooltip = L(key .. "-hint") }
    input.style.width = 92
  end
  box.add {
    type = "button", caption = L("apply-" .. name), name = "apply_" .. name,
    tags = { fbm_quick = "apply_" .. name },
  }
end

function Editor.add_limits(options) form(options, "limits", limits, true) end
function Editor.add_identity(options) form(options, "identity", identity, false) end

local function values(pref, source)
  if source == nil then
    return { tostring(pref.icon_min or 1), tostring(pref.label_min or 1), tostring(pref.nest_slots or 0) }
  end
  local id = pref.identities and pref.identities[source] or {}
  return { id.prefix or "", id.colour or "" }
end

local function inputs(box, fields)
  local result = {}
  for i, key in ipairs(fields) do result[i] = box.fields[key].text end
  return result
end

local function restore(box, fields, force, source, saved)
  for i, key in ipairs(fields) do box.fields[key].text = saved[i] end
  box.tags = { force = force.index, source = source, saved = saved }
end

local function sync(box, fields, force, source, pref)
  local draft, saved = box.tags, values(pref, source)
  if draft.force ~= force.index or draft.source ~= source
    or (not Text.same(draft.saved, saved) and Text.same(inputs(box, fields), draft.saved)) then
    restore(box, fields, force, source, saved)
  end
end

function Editor.refresh(options, force, source, pref)
  sync(options.limits, limits, force, nil, pref)
  sync(options.identity, identity, force, source or "", pref)
  options.identity.enabled = source ~= nil and source ~= ""
end

-- Return the scope of an accepted change so cosmetic edits can reuse existing markers.
function Editor.apply(p, options, source, pref, editing_limits)
  if not editing_limits and (not source or source == "") then return end
  local box, fields = options.identity, identity
  if editing_limits then box, fields, source = options.limits, limits, nil end
  local saved, draft = values(pref, source), box.tags
  if draft.force ~= p.force.index or draft.source ~= source or not Text.same(draft.saved, saved) then
    restore(box, fields, p.force, source, saved)
    p.print(L("style-stale"))
    return
  end
  local entered = inputs(box, fields)
  local change
  if editing_limits then
    local icon, label, slots = tonumber(entered[1]), tonumber(entered[2]), tonumber(entered[3])
    if not icon or not label or not slots or icon % 1 ~= 0 or label % 1 ~= 0 or slots % 1 ~= 0
      or icon < 1 or icon > 1000000 or label < 1 or label > 1000000 or slots < 0 or slots > 2048 then
      p.print(L("limits-error"))
      return
    end
    if icon ~= (pref.icon_min or 1) or slots ~= (pref.nest_slots or 0) then change = "markers"
    elseif label ~= (pref.label_min or 1) then change = "labels" end
    pref.icon_min, pref.label_min, pref.nest_slots = icon, label, slots
  else
    local prefix = entered[1]:match("^%s*(.-)%s*$")
    local colour = entered[2]:match("^%s*(.-)%s*$"):upper()
    local _, length = prefix:gsub("[^\128-\191]", "")
    if length > 12 or prefix:find("[%c%[%]]") or (colour ~= "" and not colour:match("^#%x%x%x%x%x%x$")) then
      p.print(L("identity-error"))
      return
    end
    if prefix ~= saved[1] or colour ~= saved[2] then
      pref.identities = pref.identities or {}
      pref.identities[source] = (prefix ~= "" or colour ~= "") and {
        prefix = prefix ~= "" and prefix or nil, colour = colour ~= "" and colour or nil,
      } or nil
      change = "labels"
    end
  end
  restore(box, fields, p.force, source, values(pref, source))
  return change
end

return Editor
