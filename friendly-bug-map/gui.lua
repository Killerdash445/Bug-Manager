local Rules = require("rules")
local Tracker = require("tracker")

local RuleEditor = {}
local root = "fbm_window"

local function close(p)
  local f = p.gui.screen[root]
  if f then f.destroy() end
  storage.editors[p.index] = nil
end

local function button(parent, label, id, extra)
  local tags = extra or {}
  tags.fbm = id
  return parent.add { type = "button", caption = label, tags = tags }
end

local function window(p, title)
  close(p)
  local f =
    p.gui.screen.add { type = "frame", name = root, caption = title, direction = "vertical" }
  p.opened = f
  f.auto_center = true
  return f
end

function RuleEditor.fit(p)
  local f = p.gui.screen[root]
  if not f or not f.body then return end
  local width = math.max(180, math.floor(p.display_resolution.width / p.display_scale) - 64)
  local height = math.floor(p.display_resolution.height / p.display_scale)
  local box = f.body
  box.style.maximal_width = width
  box.style.maximal_height = math.max(64, math.min(450, height - 175))
  if f.error then
    f.error.style.maximal_width = width
    f.error.style.single_line = false
    box.fields.field_source.style.maximal_width = math.max(120, math.floor(width / 2))
    box.fields.field_receiver.style.maximal_width = math.max(120, math.floor(width / 2))
    if box.surface_summary then
      box.surface_summary.style.maximal_width = math.min(500, width - 32)
    end
  else
    for _, row in pairs(box.children) do
      if row.summary then row.summary.style.maximal_width = math.min(620, width - 36) end
    end
  end
end

function RuleEditor.list(p)
  local f = window(p, "Bug Manager")
  f.add { type = "label", caption = storage.enabled and "Processing enabled" or "Processing stopped" }
  f.add {
    type = "label",
    caption = "For grouping, labels and caps, open Settings → Mod settings → Map.",
  }
  button(f, "Marker settings", "marker_settings")
  if #storage.rules == 0 then
    f.add { type = "label", caption = "No sharing rules yet. Add a rule and choose both teams." }
  end
  if storage.notice then f.add { type = "label", caption = storage.notice } end
  local pane = f.add { type = "scroll-pane", name = "body", direction = "vertical" }
  for i, r in ipairs(storage.rules) do
    local block = pane.add { type = "flow", direction = "vertical" }
    block.add {
      type = "label",
      name = "summary",
      caption = r.name
        .. "   "
        .. r.source
        .. (r.two and " ↔ " or " → ")
        .. r.receiver
        .. "   "
        .. Rules.description(r),
    }.style.single_line =
      false
    local row = block.add { type = "flow" }
    button(row, "Edit", "edit", { i = i })
    button(row, "Duplicate", "copy", { i = i })
    button(row, r.enabled and "Disable" or "Enable", "toggle", { i = i })
    button(row, "Delete", "delete", { i = i })
  end
  local row = f.add { type = "flow" }
  button(row, "Add rule", "add")
  button(row, "Status", "status")
  button(row, "Close", "close")
  storage.editors[p.index] = { rev = storage.revision, mode = "list" }
  RuleEditor.fit(p)
end

local function surface_names(text)
  local names, seen = {}, {}
  if text:match("^%s*$") then return names, seen end
  for token in (text .. ","):gmatch("(.-),") do
    local name = token:match("^%s*(.-)%s*$")
    if name == "" then return nil end
    if not seen[name] then
      names[#names + 1] = name
      seen[name] = true
    end
  end
  return names, seen
end

local function show_surfaces(box)
  local fields = box.fields
  local override = fields.field_surface_override.state
  local mode = fields.field_mode.selected_index
  local choose = override and mode ~= 1
  fields.field_mode.enabled = override
  fields.field_surfaces.enabled = choose
  fields.field_platform.enabled = override
  fields.field_sandbox.enabled = override
  local names, seen = surface_names(fields.field_surfaces.text)
  box.surface_choices.visible = choose
  for _, el in pairs(box.surface_choices.children) do
    el.state = seen and seen[el.tags.surface] == true or false
    el.enabled = names ~= nil
  end
  local summary
  if not override then
    summary = "Uses the map’s default surface filters."
  elseif mode == 1 then
    summary = "All surfaces"
  elseif not names then
    summary = "Remove the empty entry in Surface names."
  elseif mode == 2 then
    summary = #names > 0 and (table.concat(names, ", ") .. " only") or "No surfaces selected"
  else
    summary = #names > 0 and ("All surfaces except " .. table.concat(names, ", ")) or "All surfaces"
  end
  if override then
    if fields.field_platform.state then summary = summary .. " · excludes space platforms" end
    if fields.field_sandbox.state then summary = summary .. " · excludes sandbox names" end
  end
  box.surface_summary.caption = summary
end

function RuleEditor.surface_event(event)
  local el = event.element
  if not el or not el.valid or el.get_mod() ~= script.mod_name or not el.tags.fbm_surface then
    return
  end
  local p = game.get_player(event.player_index)
  local d = storage.editors[p.index]
  if not p.admin or not d or d.rev ~= storage.revision or d.mode ~= "edit" then return end
  local box = p.gui.screen[root].body
  if el.tags.surface then
    local field = box.fields.field_surfaces
    local names, seen = surface_names(field.text)
    if not names or not field.enabled then return end
    local name = el.tags.surface
    if el.state and not seen[name] then
      names[#names + 1] = name
    elseif not el.state then
      for i, v in ipairs(names) do
        if v == name then
          table.remove(names, i)
          break
        end
      end
    end
    field.text = table.concat(names, ", ")
  end
  show_surfaces(box)
end

local function edit(p, r, i)
  local f = window(p, i and "Edit sharing rule" or "New sharing rule")
  local box = f.add { type = "scroll-pane", name = "body", direction = "vertical" }
  local fields = box.add { type = "table", name = "fields", column_count = 2 }
  local function field(k, label, spec)
    fields.add { type = "label", caption = label }
    spec.name = "field_" .. k
    fields.add(spec)
  end
  local function check(k, label)
    field(k, label, { type = "checkbox", state = r[k] })
  end
  local function entry(k, label)
    field(k, label, { type = "textfield", text = tostring(r[k]) })
  end
  local function choice(k, label, items, value)
    local index = 0
    for n, v in ipairs(items) do
      if v == value then index = n end
    end
    field(k, label, { type = "drop-down", items = items, selected_index = index })
  end
  entry("name", "Rule name")
  check("enabled", "Enabled")
  local names = {}
  for _, force in pairs(game.forces) do
    names[#names + 1] = force.name
  end
  for _, k in ipairs({ "source", "receiver" }) do
    if r[k] ~= "" and not game.forces[r[k]] then
      local found = false
      for _, name in ipairs(names) do
        if name == r[k] then found = true end
      end
      if not found then names[#names + 1] = r[k] end
    end
  end
  table.sort(names)
  choice("source", "Source force", names, r.source)
  choice("receiver", "Receiving force", names, r.receiver)
  button(fields, "Swap forces", "swap")
  fields.add { type = "empty-widget" }
  check("two", "Share in both directions")
  check("marker", "Show markers")
  check("discover", "Discover terrain (permanent)")
  check("refresh", "Refresh discovered terrain")
  entry("radius", "Square radius (0–128 tiles)")
  check("entity_override", "Override default entity filters")
  for _, k in ipairs(Rules.categories) do
    check(k, "   " .. k)
  end
  entry("include", "   Include prototypes (CSV)")
  entry("exclude", "   Exclude prototypes (CSV)")
  check("surface_override", "Override surface filters")
  choice("mode", "   Surface mode", { "All", "Allowlist", "Blocklist" }, r.mode)
  entry("surfaces", "   Surface names (advanced)")
  fields.field_surfaces.tooltip =
    "Comma-separated exact names. You can include a surface that will exist later."
  check("platform", "   Exclude space platforms")
  check("sandbox", "   Exclude sandbox names")
  local surfaces = {}
  for _, s in pairs(game.surfaces) do
    if not s.name:find(",", 1, true) and s.name == s.name:match("^%s*(.-)%s*$") then
      surfaces[#surfaces + 1] = s.name
    end
  end
  table.sort(surfaces)
  for _, key in ipairs({ "surface_override", "mode", "surfaces", "platform", "sandbox" }) do
    fields["field_" .. key].tags = { fbm_surface = true }
  end
  local picker = box.add { type = "flow", name = "surface_choices", direction = "vertical" }
  for _, name in ipairs(surfaces) do
    picker.add {
      type = "checkbox",
      caption = name,
      state = false,
      tags = {
        fbm_surface = true,
        surface = name,
      },
    }
  end
  box.add { type = "label", name = "surface_summary" }.style.single_line = false
  show_surfaces(box)
  box.add { type = "label", caption = "Unchecked override sections use the map defaults." }
  f.add { type = "label", name = "error", caption = "" }
  local row = f.add { type = "flow" }
  button(row, "Apply", "apply")
  button(row, "Cancel", "cancel")
  storage.editors[p.index] = { rev = storage.revision, mode = "edit", i = i, names = names }
  RuleEditor.fit(p)
end

function RuleEditor.add(p)
  edit(p, Rules.new())
end

function RuleEditor.changed()
  storage.revision = storage.revision + 1
  Tracker.reset()
  for _, p in pairs(game.connected_players) do
    local d = storage.editors[p.index]
    if d then
      if not p.admin then
        close(p)
      elseif d.mode == "list" then
        RuleEditor.list(p)
      else
        p.gui.screen[root].error.caption =
          "Configuration changed. Cancel and reopen to edit the latest version."
      end
    end
  end
end

local function read_rule(fields, d)
  local r = Rules.new()
  for k, default in pairs(r) do
    local f = fields["field_" .. k]
    if type(default) == "boolean" then
      r[k] = f.state
    elseif k == "source" or k == "receiver" then
      r[k] = d.names[f.selected_index]
    elseif k == "mode" then
      r[k] = ({ "All", "Allowlist", "Blocklist" })[f.selected_index]
    else
      r[k] = f.text:match("^%s*(.-)%s*$")
    end
  end
  if not r.source or not r.receiver then
    return nil, "Choose a source team and a receiving team."
  end
  if #r.name < 1 or #r.name > 80 then return nil, "Use a rule name of 1–80 bytes." end
  r.radius = tonumber(r.radius)
  if not r.radius or r.radius % 1 ~= 0 or r.radius < 0 or r.radius > 128 then
    return nil, "Radius must be a whole number from 0 to 128."
  end
  for _, k in ipairs({ "include", "exclude", "surfaces" }) do
    local value = r[k]
    if #value > 2048 then return nil, k .. " exceeds 2048 bytes." end
    if value ~= "" then
      for token in (value .. ","):gmatch("(.-),") do
        local name = token:match("^%s*(.-)%s*$")
        if name == "" then return nil, "Empty entry in " .. k .. "." end
        if k ~= "surfaces" and r.entity_override and not prototypes.entity[name] then
          return nil, "Unknown entity prototype: " .. name
        end
      end
    end
  end
  return r
end

function RuleEditor.click(event, status, open_marker_panel)
  local el = event.element
  if not el.valid or not el.tags.fbm or el.get_mod() ~= script.mod_name then return end
  local p = game.get_player(event.player_index)
  if not p.admin then
    close(p)
    return
  end
  local d = storage.editors[p.index]
  if not d then return end
  local a, i = el.tags.fbm, el.tags.i
  if a == "close" then
    close(p)
    return
  end
  if a == "marker_settings" then
    close(p)
    open_marker_panel(p)
    return
  end
  if a == "cancel" then
    RuleEditor.list(p)
    return
  end
  if d.rev ~= storage.revision then
    p.print("Configuration changed. Reopen /bug-map config.")
    return
  end
  local r = storage.rules[i]
  if a == "status" then
    p.print(status())
    return
  end
  if a == "add" then
    RuleEditor.add(p)
    return
  end
  if a == "edit" then
    edit(p, r, i)
    return
  end
  if a == "copy" then
    local copy = {}
    for k, v in pairs(r) do
      copy[k] = v
    end
    copy.name = copy.name .. " copy"
    edit(p, copy)
    return
  end
  if a == "swap" or a == "apply" then
    local f = p.gui.screen[root]
    local fields = f.body.fields
    if a == "swap" then
      fields.field_source.selected_index, fields.field_receiver.selected_index =
        fields.field_receiver.selected_index, fields.field_source.selected_index
      return
    end
    local new, err = read_rule(fields, d)
    if not new then
      f.error.caption = err
      return
    end
    storage.rules[d.i or (#storage.rules + 1)] = new
  elseif a == "delete" then
    table.remove(storage.rules, i)
  elseif a == "toggle" then
    r.enabled = not r.enabled
  else
    return
  end
  RuleEditor.changed()
  RuleEditor.list(p)
end

function RuleEditor.closed(event)
  if event.element and event.element.valid and event.element.name == root then
    close(game.get_player(event.player_index))
  end
end

RuleEditor.close = close
return RuleEditor
