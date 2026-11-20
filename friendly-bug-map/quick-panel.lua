local Display = require("display")
local Rules = require("rules")
local Tracker = require("tracker")
local RuleEditor = require("gui")
local Markers = require("markers")
local mod_gui = require("__core__/lualib/mod-gui")

local Panel = {}
local window = "fbm_quick_panel"
local map_button = "fbm_map_visibility"
local scope = "Admins change Bug Manager markers for every member of this receiving team. "
  .. "Terrain discovery and map refresh follow the sharing rules."

local function add(parent, action, spec)
  spec.name = action
  spec.tags = { fbm_quick = action }
  return parent.add(spec)
end

local function same(a, b)
  if #a ~= #b then return false end
  for i, v in ipairs(a) do
    if v ~= b[i] then return false end
  end
  return true
end

-- Keep an open drop-down and its selection intact while tags move.
local function choices(menu, keys, labels)
  local saved = menu.tags
  local previous = saved.keys or {}
  if same(keys, previous) and same(labels, saved.labels or {}) then return end
  local selected = previous[menu.selected_index]
  local index = 1
  for i, k in ipairs(keys) do
    if k == selected then index = i end
  end
  menu.items = labels
  menu.selected_index = index
  menu.tags = { fbm_quick = saved.fbm_quick, keys = keys, labels = labels }
end

local function selected(menu)
  return (menu.tags.keys or {})[menu.selected_index]
end

local function may_locate(p, rec)
  if not rec or not rec.group or not rec.marker.valid then return false end
  local tag = rec.marker
  if rec.force ~= p.force or tag.surface ~= p.surface or p.force.get_surface_hidden(p.surface) then
    return false
  end
  if
    p.controller_type ~= defines.controllers.remote
    and p.controller_type ~= defines.controllers.character
  then
    return false
  end
  local permissions = p.permission_group or game.permissions.get_group(0)
  local pos = rec.position
  return permissions.allows_action(defines.input_action.remote_view_surface)
    and p.force.is_chunk_charted(p.surface, { math.floor(pos.x / 32), math.floor(pos.y / 32) })
end

-- A refresh batch shares one census across open panels. Selections, access and
-- personal visibility are always evaluated for the player receiving the panel.
local function panel_views(players)
  local teams = {}
  for _, p in pairs(players) do
    if p.gui.screen[window] then
      local id = p.force.index
      teams[id] = teams[id] or { total = 0, groups = 0, surfaces = {}, sources = {} }
      teams[id].surfaces[p.surface.index] = { rows = {} }
    end
  end
  if not next(teams) then return teams end
  for source, routes in pairs(storage.routes or {}) do
    local added = {}
    for _, route in ipairs(routes) do
      local force = game.forces[route.target]
      local team = force and teams[force.index]
      if team and route.rule.marker and not added[force.index] then
        team.sources[#team.sources + 1] = source
        added[force.index] = true
      end
    end
  end
  for key, rec in pairs(storage.tags or {}) do
    if rec.marker.valid and rec.force.valid then
      local team = teams[rec.force.index]
      if team then
        team.total = team.total + 1
        if rec.group then
          team.groups = team.groups + 1
          local view = team.surfaces[rec.marker.surface.index]
          if view then
            local rows = view.rows
            rows[#rows + 1] = { key = key, record = rec }
          end
        end
      end
    end
  end
  for id, team in pairs(teams) do
    table.sort(team.sources)
    local aliases = Display.preferences(game.forces[id]).aliases
    for _, view in pairs(team.surfaces) do
      table.sort(view.rows, function(a, b)
        local ac, bc = a.record.count or 0, b.record.count or 0
        if ac ~= bc then return ac > bc end
        return a.key < b.key
      end)
      view.keys, view.names = { "" }, { "Choose a group on this surface" }
      local duplicates = {}
      for i, row in ipairs(view.rows) do
        local r = row.record
        local noun = r.kind or "bug"
        local size = r.count and (r.count .. " " .. noun .. (r.count == 1 and "" or "s"))
          or "count pending"
        local label = (aliases[r.source] or r.source or "Group") .. " · " .. size
        view.keys[i + 1], view.names[i + 1] = row.key, label
        duplicates[label] = (duplicates[label] or 0) + 1
      end
      for i, row in ipairs(view.rows) do
        local label = view.names[i + 1]
        if duplicates[label] > 1 then view.names[i + 1] = label .. "  #" .. row.record.marker.id end
      end
    end
  end
  return teams
end

local function refresh(p, frame, teams)
  local b = frame.body
  local team = (teams or panel_views({ p }))[p.force.index]
  local pref = Display.preferences(p.force)
  frame.header.heading.caption = p.admin and "Bug Manager configuration" or "Bug Manager"
  for _, name in ipairs({
    "show",
    "config",
    "source_label",
    "source",
    "include",
    "alias_label",
    "alias_field",
    "apply_alias",
    "nests",
    "preset_label",
    "preset",
    "settings",
    "filters_line",
  }) do
    b[name].visible = p.admin
  end
  frame.tags = { force = p.force.index }
  b.team.caption = "Receiving team · " .. p.force.name
  b.team.tooltip = p.force.name
  b.show.state = pref.show
  b.show.enabled = p.admin
  b.nests.state = pref.nests
  b.nests.enabled = p.admin
  b.config.visible = p.admin
  b.preset.enabled = p.admin
  for i, name in ipairs(Display.names) do
    if name == pref.preset then
      if b.preset.selected_index ~= i then b.preset.selected_index = i end
      break
    end
  end
  local style = Display.style(p.force)
  local labels = {}
  if style.team then labels[#labels + 1] = "source" end
  if style.count then labels[#labels + 1] = "count" end
  if style.kind then labels[#labels + 1] = "type" end
  b.settings.caption = (style.group and "Grouped" or "Individual")
    .. " · Cap "
    .. style.cap
    .. " · "
    .. (#labels > 0 and table.concat(labels, " + ") or "No labels")
  local state = "Icons on"
  if not storage.enabled then
    state = "Tracking paused"
  elseif not Rules.option("show") then
    state = "Icons off · server master switch"
  elseif not pref.show then
    state = "Icons off · team preference"
  end
  local pass = storage.pass
  if not storage.enabled then
    b.update.caption = "Updates paused"
  elseif
    pass
    and (
      game.tick > storage.next_chart or (Rules.option("show") and game.tick > storage.next_marker)
    )
  then
    b.update.caption = "Updates delayed · " .. pass.phase .. " pass in progress"
  elseif pass then
    b.update.caption = "Updating · " .. pass.phase
  else
    b.update.caption = ""
  end
  if storage.enabled then
    local age = storage.last_update
        and ("Last update: " .. math.floor((game.tick - storage.last_update) / 60) .. " s ago")
      or "Waiting for first update"
    b.update.caption = pass and (b.update.caption .. " · " .. age) or age
  end
  local sources = team.sources
  if #sources == 0 and state == "Icons on" then state = "No rules share icons with this team" end
  if state == "Icons on" and storage.hidden_details[p.index] then
    state = "Details hidden on your map"
  end
  b.visibility.caption = state
  if #sources == 0 then
    choices(b.source, { "" }, { "No active sources" })
  else
    choices(b.source, sources, sources)
  end
  b.source.enabled = #sources > 0
  local source = selected(b.source)
  local field = b.alias_field
  local draft = field.tags
  local saved = pref.aliases[source] or ""
  -- Periodic refresh must preserve a draft for the same source and receiver.
  if
    draft.force ~= p.force.index
    or draft.source ~= source
    or (draft.saved ~= saved and field.text == draft.saved)
  then
    field.text = saved
    field.tags = { force = p.force.index, source = source, saved = saved }
  end
  field.enabled = p.admin and #sources > 0
  b.apply_alias.enabled = field.enabled
  b.include.enabled = p.admin and #sources > 0
  b.include.state = #sources > 0 and not pref.excluded[source]
  local filtered = {}
  for _, name in ipairs(sources) do
    if pref.excluded[name] then filtered[#filtered + 1] = name end
  end
  local reasons = {}
  if #filtered > 0 then
    reasons[1] = "Sources filtered out for this team: " .. table.concat(filtered, ", ")
  end
  local stats = storage.marker_stats
  local hidden = stats
    and stats.hidden_by_bucket
    and stats.hidden_by_bucket[p.force.index .. "/" .. p.surface.index]
  if hidden then
    local noun = style.group and "group" or "individual marker"
    reasons[#reasons + 1] = hidden
      .. " "
      .. noun
      .. (hidden == 1 and "" or "s")
      .. " hidden by the marker limit on "
      .. p.surface.name
      .. " at last count."
  end
  b.reasons.caption = table.concat(reasons, "\n")
  b.reasons.visible = #reasons > 0
  b.count.caption = "Team groups: " .. team.groups .. "   •   Total icons: " .. team.total
  local view = team.surfaces[p.surface.index]
  choices(b.group_list, view.keys, view.names)
  b.group_list.enabled = #view.rows > 0
  local permissions = p.permission_group or game.permissions.get_group(0)
  b.group_list.visible = permissions.allows_action(defines.input_action.remote_view_surface)
  b.locate.visible = b.group_list.visible
  b.locate.enabled = may_locate(p, storage.tags[selected(b.group_list)])
end

local function fit(p, frame)
  local size = p.display_resolution
  frame.body.style.maximal_height = math.max(100, math.floor(size.height / p.display_scale) - 110)
  local width = math.min(360, math.max(180, math.floor(size.width / p.display_scale) - 76))
  frame.body.team.style.maximal_width = width
  frame.body.source.style.maximal_width = width
  frame.body.group_list.style.maximal_width = width
  frame.body.reasons.style.maximal_width = width
  frame.body.update.style.maximal_width = width
end

local function open(p)
  local frame = p.gui.screen.add { type = "frame", name = window, direction = "vertical" }
  local title = frame.add { type = "flow", name = "header" }
  title.drag_target = frame
  title.add { type = "label", name = "heading", caption = "Bug Manager", style = "frame_title" }.drag_target =
    frame
  local spacer = title.add { type = "empty-widget", style = "draggable_space_header" }
  spacer.style.horizontally_stretchable = true
  spacer.drag_target = frame
  add(title, "close", {
    type = "sprite-button",
    sprite = "utility/close",
    style = "frame_action_button",
    tooltip = "Close",
  })
  local b = frame.add {
    type = "scroll-pane",
    name = "body",
    direction = "vertical",
    horizontal_scroll_policy = "never",
  }
  b.add { type = "label", name = "team", style = "heading_2_label" }
  b.add { type = "label", name = "visibility" }
  add(
    b,
    "show",
    { type = "checkbox", caption = "Show bug icons for this team", state = true, tooltip = scope }
  )
  b.add { type = "label", name = "count" }
  b.add { type = "label", name = "update" }
  b.update.style.single_line = false
  b.add { type = "label", name = "reasons" }.style.single_line = false
  add(b, "config", { type = "button", caption = "Sharing rules" })
  if not storage.quick_help[p.index] then
    local hint =
      b.add { type = "label", caption = "Hiding icons keeps discovery and refresh running." }
    hint.style.single_line = false
    hint.style.maximal_width = 265
    storage.quick_help[p.index] = true
  end
  b.add { type = "line", name = "filters_line" }
  b.add { type = "label", name = "source_label", caption = "Source team" }
  add(b, "source", { type = "drop-down", items = {} })
  b.add { type = "label", name = "alias_label", caption = "Map name (optional)" }
  b.add {
    type = "textfield",
    name = "alias_field",
    text = "",
    tooltip = "Name shown before the count for this source on your team's map. "
      .. "Leave blank to use the source team name.",
  }
  add(b, "apply_alias", { type = "button", caption = "Apply name" })
  add(b, "include", {
    type = "checkbox",
    caption = "Show icons from selected source",
    state = true,
    tooltip = scope,
  })
  add(b, "nests", {
    type = "checkbox",
    caption = "Show tracked nests",
    state = true,
    tooltip = "Display tracked spawners for this team. Nest tracking is configured in sharing rules.",
  })
  b.add { type = "label", name = "preset_label", caption = "Team display preset" }
  add(b, "preset", { type = "drop-down", items = Display.names })
  b.add { type = "label", name = "settings" }
  b.add { type = "line" }
  add(b, "group_list", { type = "drop-down", items = {} })
  add(b, "locate", {
    type = "button",
    caption = "Locate group",
    tooltip = "Centre remote view on a displayed group on your current surface.",
  })
  fit(p, frame)
  refresh(p, frame)
  p.opened = frame
  frame.force_auto_center()
end

function Panel.closed(event)
  local el = event.element
  if el and el.valid and el.name == window and el.get_mod() == script.mod_name then el.destroy() end
end

function Panel.toggle(p)
  if not p.admin then return end
  local frame = p.gui.screen[window]
  if frame then
    frame.destroy()
  else
    open(p)
  end
end

local function sync_map_button(p)
  local top = p.gui.top
  local frame = top.mod_gui_top_frame
  local flow = top.mod_gui_button_flow or (frame and frame.mod_gui_inner_frame)
  local button = flow and flow[map_button]
  if p.controller_type ~= defines.controllers.remote then
    if button then button.destroy() end
    return
  end
  if not button then
    flow = mod_gui.get_button_flow(p)
    button = flow.add {
      type = "sprite-button",
      name = map_button,
      style = mod_gui.button_style,
      sprite = "entity/small-biter",
      tags = { fbm_quick = "map_visibility" },
    }
  end
  local shown = not storage.hidden_details[p.index]
  local indicator = shown and 1 or 0
  if button.number ~= indicator then
    button.number = indicator
    button.toggled = shown
    button.tooltip = (shown and "Hide my bug details" or "Show my bug details")
      .. "\nOnly changes your map. Terrain discovery and normal map blips are independent."
  end
end

local function display_changed(force)
  Tracker.display_changed(force)
  local teams = panel_views(force.connected_players)
  for _, mate in pairs(force.connected_players) do
    sync_map_button(mate)
    local panel = mate.gui.screen[window]
    if panel then refresh(mate, panel, teams) end
  end
end

function Panel.sync(p)
  p.set_shortcut_available("fbm-bug-tracker", p.admin)
  sync_map_button(p)
  local frame = p.gui.screen[window]
  if frame then
    fit(p, frame)
    refresh(p, frame)
  end
end

function Panel.init(replace_old_panels)
  storage.displays = storage.displays or {}
  storage.quick_help = storage.quick_help or {}
  for _, p in pairs(game.players) do
    -- Older releases used Factorio's shared mod toolbar. Leave its other buttons alone.
    local top = p.gui.top
    local old_map = top[map_button]
    if old_map and old_map.get_mod() == script.mod_name then old_map.destroy() end
    local toolbar = top.mod_gui_top_frame
    local flow = top.mod_gui_button_flow or (toolbar and toolbar.mod_gui_inner_frame)
    local old_button = flow and flow.fbm_quick_button
    if old_button and old_button.get_mod() == script.mod_name then old_button.destroy() end
    local frame = p.gui.screen[window]
    if frame and (replace_old_panels or not frame.body or not frame.body.reasons) then
      frame.destroy()
    end
    Panel.sync(p)
  end
end

function Panel.reset(p)
  Panel.sync(p)
  local frame = p.gui.screen[window]
  if frame then
    frame.force_auto_center()
  else
    open(p)
  end
end

function Panel.refresh_open()
  local teams = panel_views(game.connected_players)
  for _, p in pairs(game.connected_players) do
    sync_map_button(p)
    local frame = p.gui.screen[window]
    if frame then refresh(p, frame, teams) end
  end
end

function Panel.event(event)
  local el = event.element
  if not el.valid then return end
  local action = el.tags.fbm_quick
  if not action or el.get_mod() ~= script.mod_name then return end
  local p = game.get_player(event.player_index)
  if action == "map_visibility" then
    if
      event.name == defines.events.on_gui_click
      and p.controller_type == defines.controllers.remote
    then
      storage.hidden_details[p.index] = not storage.hidden_details[p.index] or nil
      Markers.refresh_audience(p.force)
      sync_map_button(p)
    end
    return true
  end
  local frame = p.gui.screen[window]
  local ev = defines.events
  if not frame then return true end
  if frame.tags.force ~= p.force.index then
    refresh(p, frame)
    return true
  end
  if event.name == ev.on_gui_click then
    if action == "close" then
      frame.destroy()
    elseif action == "config" and p.admin then
      frame.destroy()
      RuleEditor.list(p)
    elseif action == "apply_alias" and p.admin then
      local b = frame.body
      local field = b.alias_field
      local source = selected(b.source)
      local draft = field.tags
      if not source or source == "" or draft.force ~= p.force.index or draft.source ~= source then
        return true
      end
      local pref = Display.preferences(p.force)
      if draft.saved ~= (pref.aliases[source] or "") then
        field.tags = {}
        refresh(p, frame)
        p.print("Another admin changed this map name. The current name is shown.")
        return true
      end
      local name = field.text:match("^%s*(.-)%s*$")
      local _, length = name:gsub("[^\128-\191]", "")
      if length > 64 or name:find("[%c%[%]]") then
        p.print("Use up to 64 characters without square brackets or control characters.")
        return true
      end
      if name ~= draft.saved then
        pref.aliases[source] = name ~= "" and name or nil
        field.text = name
        field.tags = { force = p.force.index, source = source, saved = name }
        display_changed(p.force)
      else
        field.text = name
      end
    elseif action == "locate" then
      local rec = storage.tags[selected(frame.body.group_list)]
      if may_locate(p, rec) then
        p.set_controller {
          type = defines.controllers.remote,
          surface = rec.marker.surface,
          position = rec.position,
        }
        frame.destroy()
      else
        refresh(p, frame)
      end
    end
    return true
  end
  local pref = Display.preferences(p.force)
  if action == "source" or action == "group_list" or not p.admin then
    refresh(p, frame)
    return true
  end
  if event.name == ev.on_gui_checked_state_changed then
    if action == "show" then
      pref.show = el.state
    elseif action == "nests" then
      pref.nests = el.state
    elseif action == "include" then
      local source = selected(frame.body.source)
      if not source or source == "" then return true end
      pref.excluded[source] = not el.state or nil
    else
      return true
    end
  elseif event.name == ev.on_gui_selection_state_changed and action == "preset" then
    pref.preset = Display.names[el.selected_index] or "Server settings"
  else
    return true
  end
  display_changed(p.force)
  return true
end

return Panel
