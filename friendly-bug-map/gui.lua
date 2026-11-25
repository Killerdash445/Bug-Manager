local Text = require("ui-text")
local L = Text.get
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

local function stretch(el)
  el.style.horizontally_stretchable = true
  return el
end

local function action_bar(frame)
  local row = stretch(frame.add { type = "flow", name = "action_bar" })
  row.style.top_margin = 4
  return row
end

local function table_section(box, name)
  local grid = stretch(box.add { type = "table", name = name, column_count = 2 })
  grid.style.horizontal_spacing = 12
  grid.style.vertical_spacing = 4
  return grid
end

function RuleEditor.fit(p)
  local f = p.gui.screen[root]
  if not f or not f.body then return end
  local width =
    math.min(480, math.max(240, math.floor(p.display_resolution.width / p.display_scale) - 56))
  local height = math.floor(p.display_resolution.height / p.display_scale)
  local box = f.body
  box.style.width = width
  box.style.maximal_height = math.max(72, height - 168)
  local inner = width - 48
  if f.error then
    local column = math.floor((inner - 12) / 2)
    for _, field in ipairs({
      box.fields.field_source,
      box.fields.field_receiver,
      box.filters.field_mode,
      box.filters.field_include,
      box.filters.field_exclude,
      box.filters.field_surfaces,
    }) do
      field.style.width = column
    end
    box.identity.field_name.style.width = math.max(72, width - 232)
    f.preview.style.maximal_width = width - 8
    f.error.style.maximal_width = width - 8
    box.surface_summary.style.maximal_width = inner
  else
    for _, block in pairs(box.children) do
      if block.route then
        block.route.style.maximal_width = inner - 18
        block.header.rule_name.style.maximal_width = math.floor(inner * 0.57)
        block.header.status.style.maximal_width = math.floor(inner * 0.38)
      end
    end
  end
end

function RuleEditor.list(p)
  local f = window(p, L("sharing-rules"))
  local pane = f.add {
    type = "scroll-pane",
    name = "body",
    direction = "vertical",
    horizontal_scroll_policy = "never",
  }
  local bar = stretch(pane.add { type = "flow" })
  bar.style.vertical_align = "center"
  stretch(
    bar.add {
      type = "label",
      style = "semibold_label",
      caption = storage.enabled and L("processing-enabled") or L("processing-stopped"),
    }
  )
  button(bar, L("marker-settings"), "marker_settings")
  local hint = pane.add { type = "label", caption = L("map-settings-hint") }
  hint.style.single_line = false
  hint.style.horizontally_squashable = true
  if #storage.rules == 0 then
    pane.add { type = "label", caption = L("no-rules") }.style.single_line = false
  end
  if storage.notice then
    pane.add { type = "label", caption = storage.notice }.style.single_line = false
  end
  for i, r in ipairs(storage.rules) do
    local block = stretch(
      pane.add { type = "frame", direction = "vertical", style = "inside_shallow_frame_with_padding" }
    )
    local header = stretch(block.add { type = "flow", name = "header" })
    stretch(
      header.add { type = "label", name = "rule_name", caption = r.name, style = "heading_2_label" }
    ).style.single_line =
      false
    header.add {
      type = "label",
      name = "status",
      caption = Rules.description(r),
      style = "semibold_label",
    }.style.single_line =
      false
    block.add {
      type = "label",
      name = "route",
      caption = { "", r.source, r.two and " ↔ " or " → ", r.receiver },
    }.style.single_line =
      false
    local row = stretch(block.add { type = "flow" })
    row.style.top_margin = 4
    for _, action in ipairs({
      { "edit-rule", "edit" },
      { "duplicate", "copy" },
      { r.enabled and "disable" or "enable", "toggle" },
    }) do
      button(row, L(action[1]), action[2], { i = i }).style.minimal_width = 48
    end
    stretch(row.add { type = "empty-widget" })
    button(row, L("delete"), "delete", { i = i }).style.minimal_width = 48
  end
  local row = action_bar(f)
  button(row, L("close"), "close")
  button(row, L("status"), "status")
  stretch(row.add { type = "empty-widget" })
  button(row, L("add-rule"), "add").style = "confirm_button"
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

local function inherit_checkbox(fields, key, override)
  local field = fields["field_" .. key]
  if not override then
    if field.enabled then
      local tags = field.tags
      tags.custom = field.state
      field.tags = tags
    end
    field.state = Rules.option(key)
  elseif not field.enabled and field.tags.custom ~= nil then
    field.state = field.tags.custom
  end
  field.enabled = override
end

local function show_surfaces(box)
  local fields = box.filters
  local override = fields.field_surface_override.state
  local mode = fields.field_mode.selected_index
  local choose = override and mode ~= 1
  fields.field_mode.enabled = override
  fields.field_surfaces.enabled = choose
  inherit_checkbox(fields, "platform", override)
  inherit_checkbox(fields, "sandbox", override)
  local names, seen = surface_names(fields.field_surfaces.text)
  box.surface_choices.visible = box.filters.visible and choose
  for _, el in pairs(box.surface_choices.children) do
    el.state = seen and seen[el.tags.surface] == true or false
    el.enabled = names ~= nil
  end
  local summary
  if not override then
    summary = L("surface-defaults")
  elseif mode == 1 then
    summary = L("all-surfaces")
  elseif not names then
    summary = L("invalid-surface")
  elseif mode == 2 then
    summary = #names > 0 and L("surface-only", table.concat(names, ", ")) or L("no-surfaces")
  else
    summary = #names > 0 and L("surface-except", table.concat(names, ", ")) or L("all-surfaces")
  end
  if override then
    if fields.field_platform.state then summary = L("without-platforms", summary) end
    if fields.field_sandbox.state then summary = L("without-sandboxes", summary) end
  end
  box.surface_summary.caption = summary
end

local function preview(frame, names)
  local box = frame.body
  local fields, outputs = box.fields, box.outputs
  local enabled = {}
  for _, key in ipairs({ "marker", "discover", "refresh" }) do
    if outputs["field_" .. key].state then enabled[#enabled + 1] = L("output-" .. key) end
  end
  local radius = tonumber(outputs.field_radius.text)
  local range = radius and radius % 1 == 0 and radius >= 0 and radius <= 128 and L("tiles", radius)
    or L("invalid-radius")
  local summary = L(
    "preview",
    names[fields.field_source.selected_index] or L("choose-source"),
    fields.field_two.state and "↔" or "→",
    names[fields.field_receiver.selected_index] or L("choose-receiver"),
    #enabled > 0 and Text.join(enabled, ", ") or L("no-output"),
    range
  )
  frame.preview.caption = box.identity.field_enabled.state and summary
    or L("preview-disabled", summary)
end

local function show_filters(box)
  local fields = box.filters
  local override = fields.field_entity_override.state
  for _, key in ipairs(Rules.categories) do
    inherit_checkbox(fields, key, override)
  end
  for _, key in ipairs({ "include", "exclude" }) do
    local field = fields["field_" .. key]
    if not override and field.enabled then
      field.tags = { custom = field.text }
      field.text = ""
    elseif override and not field.enabled then
      field.text = field.tags.custom
    end
    field.enabled = override
  end
  fields.visible = box.advanced.state
  box.surface_summary.visible = fields.visible
  show_surfaces(box)
end

function RuleEditor.field_event(event)
  local el = event.element
  if not el or not el.valid or el.get_mod() ~= script.mod_name or not el.tags.fbm_field then
    return
  end
  local p = game.get_player(event.player_index)
  local d = storage.editors[p.index]
  if not p.admin or not d or d.rev ~= storage.revision or d.mode ~= "edit" then return end
  local frame = p.gui.screen[root]
  local box = frame.body
  if el.tags.fbm_field == "preview" then
    preview(frame, d.names)
    return
  end
  if el.tags.fbm_field == "filters" then
    show_filters(box)
    if el == box.advanced then frame.force_auto_center() end
    return
  end
  if el.tags.surface then
    local field = box.filters.field_surfaces
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
  local f = window(p, i and L("edit-title") or L("new-title"))
  local box = f.add {
    type = "scroll-pane",
    name = "body",
    style = "deep_scroll_pane_with_padding",
    direction = "vertical",
    horizontal_scroll_policy = "never",
  }
  local fields = stretch(box.add { type = "flow", name = "identity" })
  fields.style.vertical_align = "center"
  local function label(key)
    fields.add { type = "label", caption = L(key), style = "semibold_label" }
  end
  local function check(k, caption)
    return fields.add { type = "checkbox", name = "field_" .. k, state = r[k], caption = caption }
  end
  local function entry(k, caption)
    fields.add { type = "label", caption = caption }
    return fields.add { type = "textfield", name = "field_" .. k, text = tostring(r[k]) }
  end
  local function choice(k, items, value)
    local index = 0
    for n, v in ipairs(items) do
      if v == value then index = n end
    end
    local labels = items
    if k == "mode" then labels = { L("mode-all"), L("mode-allow"), L("mode-block") } end
    return fields.add {
      type = "drop-down",
      name = "field_" .. k,
      items = labels,
      selected_index = index,
    }
  end
  entry("name", L("rule-name"))
  stretch(fields.add { type = "empty-widget" })
  check("enabled", L("enabled")).tags = { fbm_field = "preview" }
  box.add { type = "line" }
  fields = table_section(box, "fields")
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
  label("source")
  label("receiver")
  choice("source", names, r.source).tags = { fbm_field = "preview" }
  choice("receiver", names, r.receiver).tags = { fbm_field = "preview" }
  button(fields, L("swap"), "swap")
  check("two", L("both")).tags = { fbm_field = "preview" }
  box.add { type = "line" }
  fields = table_section(box, "outputs")
  for _, key in ipairs({ "marker", "discover", "refresh" }) do
    check(key, L(key)).tags = { fbm_field = "preview" }
  end
  fields.add { type = "empty-widget" }
  entry("radius", L("radius")).tags = { fbm_field = "preview" }
  fields.field_radius.style.width = 76
  box.add { type = "line" }
  box.add {
    type = "checkbox",
    name = "advanced",
    caption = L("advanced"),
    state = false,
    tags = { fbm_field = "filters" },
  }
  fields = table_section(box, "filters")
  check("entity_override", L("entity-override"))
  fields.add { type = "empty-widget" }
  for _, k in ipairs(Rules.categories) do
    check(k, L("category-" .. k))
  end
  fields.add { type = "empty-widget" }
  fields.field_entity_override.tags = { fbm_field = "filters" }
  entry("include", L("field-include"))
  entry("exclude", L("field-exclude"))
  fields.add { type = "line" }
  fields.add { type = "line" }
  check("surface_override", L("surface-override"))
  fields.add { type = "empty-widget" }
  label("surface-mode")
  choice("mode", { "All", "Allowlist", "Blocklist" }, r.mode)
  entry("surfaces", L("field-surfaces"))
  fields.field_surfaces.tooltip = L("surfaces-help")
  check("platform", L("platform"))
  check("sandbox", L("sandbox"))
  local surfaces = {}
  for _, s in pairs(game.surfaces) do
    if not s.name:find(",", 1, true) and s.name == s.name:match("^%s*(.-)%s*$") then
      surfaces[#surfaces + 1] = s.name
    end
  end
  table.sort(surfaces)
  for _, key in ipairs({ "surface_override", "mode", "surfaces", "platform", "sandbox" }) do
    fields["field_" .. key].tags = { fbm_field = "surface" }
  end
  local picker = table_section(box, "surface_choices")
  for _, name in ipairs(surfaces) do
    picker.add {
      type = "checkbox",
      caption = name,
      state = false,
      tags = {
        fbm_field = "surface",
        surface = name,
      },
    }
  end
  box.add { type = "label", name = "surface_summary" }.style.single_line = false
  show_filters(box)
  local summary = f.add { type = "label", name = "preview", style = "semibold_caption_label" }
  summary.style.single_line = false
  summary.style.top_margin = 4
  preview(f, names)
  local error_label = f.add { type = "label", name = "error", caption = "" }
  error_label.style.single_line = false
  error_label.visible = false
  local row = action_bar(f)
  button(row, L("cancel"), "cancel")
  stretch(row.add { type = "empty-widget" })
  button(row, L("apply"), "apply").style = "confirm_button"
  storage.editors[p.index] = { rev = storage.revision, mode = "edit", i = i, names = names }
  RuleEditor.fit(p)
end

function RuleEditor.add(p)
  local rule = Rules.new()
  rule.platform, rule.sandbox = Rules.option("platform"), Rules.option("sandbox")
  for _, key in ipairs(Rules.categories) do
    rule[key] = Rules.option(key)
  end
  edit(p, rule)
end

function RuleEditor.changed()
  storage.revision = storage.revision + 1
  Tracker.reset()
  for _, p in pairs(game.connected_players) do
    local d = storage.editors[p.index]
    if d then
      if not p.admin or not p.gui.screen[root] then
        close(p)
      elseif d.mode == "list" then
        RuleEditor.list(p)
      else
        local message = p.gui.screen[root].error
        message.caption = L("stale-edit")
        message.visible = true
      end
    end
  end
end

local function read_rule(box, d)
  local r = Rules.new()
  for k, default in pairs(r) do
    local name = "field_" .. k
    local f = box.fields[name] or box.identity[name] or box.outputs[name] or box.filters[name]
    if not f.enabled and f.tags.custom ~= nil then
      r[k] = f.tags.custom
    elseif type(default) == "boolean" then
      r[k] = f.state
    elseif k == "source" or k == "receiver" then
      r[k] = d.names[f.selected_index]
    elseif k == "mode" then
      r[k] = ({ "All", "Allowlist", "Blocklist" })[f.selected_index]
    else
      r[k] = f.text:match("^%s*(.-)%s*$")
    end
  end
  if not r.source or not r.receiver then return nil, L("need-teams") end
  if #r.name < 1 or #r.name > 80 then return nil, L("invalid-name") end
  r.radius = tonumber(r.radius)
  if not r.radius or r.radius % 1 ~= 0 or r.radius < 0 or r.radius > 128 then
    return nil, L("radius-error")
  end
  for _, k in ipairs({ "include", "exclude", "surfaces" }) do
    local value = r[k]
    if #value > 2048 then return nil, L("too-long", L("field-" .. k)) end
    if value ~= "" then
      for token in (value .. ","):gmatch("(.-),") do
        local name = token:match("^%s*(.-)%s*$")
        if name == "" then return nil, L("empty-entry", L("field-" .. k)) end
        if k ~= "surfaces" and r.entity_override and not prototypes.entity[name] then
          return nil, L("unknown-prototype", name)
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
    p.print(L("stale-list"))
    return
  end
  local r = storage.rules[i]
  if a == "status" then
    status(function(line)
      p.print(line)
    end)
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
      preview(f, d.names)
      return
    end
    local new, err = read_rule(f.body, d)
    if not new then
      f.error.caption = err
      f.error.visible = true
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
