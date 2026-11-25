local Text = require("ui-text")
local L = Text.get
local Display = require("display")
local Rules = require("rules")
local Tracker = require("tracker")
local RuleEditor = require("gui")
local Markers = require("markers")
local mod_gui = require("__core__/lualib/mod-gui")

local Panel = {}
local window = "fbm_quick_panel"
local map_button = "fbm_map_visibility"
local scope = L("team-scope")

local function add(parent, action, spec)
  spec.name = action
  spec.tags = { fbm_quick = action }
  return parent.add(spec)
end

-- Keep an open drop-down and its selection intact while tags move.
local function choices(menu, keys, labels, signatures)
  signatures = signatures or labels
  local saved = menu.tags
  local previous = saved.keys or {}
  if Text.same(keys, previous) and Text.same(signatures, saved.signatures) then return end
  local selected = previous[menu.selected_index]
  local index = 1
  for i, k in ipairs(keys) do
    if k == selected then index = i end
  end
  menu.items = labels
  menu.selected_index = index
  menu.tags = { fbm_quick = saved.fbm_quick, keys = keys, signatures = signatures }
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
  local pos = rec.position
  return p.force.is_chunk_charted(p.surface, { math.floor(pos.x / 32), math.floor(pos.y / 32) })
end

local function refresh_locate(p, body)
  local permissions = p.permission_group or game.permissions.get_group(0)
  local allowed = permissions.allows_action(defines.input_action.remote_view_surface)
  body.group_search.visible = allowed
  body.search_label.visible = allowed
  body.group_list.visible = allowed
  body.locate.visible = allowed
  local record = storage.tags[selected(body.group_list)]
  body.locate.enabled = allowed and may_locate(p, record)
  if body.locate.enabled then return record end
end

local function group_choices(query, keys, aliases)
  local result = { keys = { "" }, labels = { L("choose-group") }, signatures = { "choose" } }
  local duplicates = {}
  for _, key in ipairs(keys) do
    local rec = storage.tags[key]
    if rec and rec.marker.valid then
      local source = rec.source or ""
      local alias = aliases[source] or source
      if
        query == ""
        or source:lower():find(query, 1, true)
        or alias:lower():find(query, 1, true)
      then
        local kind = rec.kind or "bug"
        local sig = alias .. "\0" .. kind .. "\0" .. tostring(rec.count)
        local size = rec.count and L("count-" .. kind, rec.count) or L("pending-count")
        local index = #result.keys + 1
        result.keys[index] = key
        result.labels[index] = L("group-entry", alias, size)
        result.signatures[index] = sig
        duplicates[sig] = (duplicates[sig] or 0) + 1
      end
    end
  end
  for i = 2, #result.keys do
    local sig = result.signatures[i]
    if duplicates[sig] > 1 then
      local id = storage.tags[result.keys[i]].marker.id
      result.labels[i] = L("group-number", result.labels[i], id)
      result.signatures[i] = sig .. "#" .. id
    end
  end
  if #result.keys == 1 and query ~= "" then
    result.labels[1] = L("no-matches")
    result.signatures[1] = "empty"
  end
  return result
end

local function show_groups(p, body, keys, cache)
  local query = body.group_search.text:lower():match("^%s*(.-)%s*$")
  local items = cache and cache[query]
  if not items then
    items = group_choices(query, keys, Display.preferences(p.force).aliases)
    if cache then cache[query] = items end
  end
  choices(body.group_list, items.keys, items.labels, items.signatures)
  body.group_list.enabled = #items.keys > 1
  refresh_locate(p, body)
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
  for _, team in pairs(teams) do
    table.sort(team.sources)
    for _, view in pairs(team.surfaces) do
      table.sort(view.rows, function(a, b)
        local ac, bc = a.record.count or 0, b.record.count or 0
        if ac ~= bc then return ac > bc end
        return a.key < b.key
      end)
      view.keys, view.searches = {}, {}
      for i, row in ipairs(view.rows) do
        view.keys[i] = row.key
      end
    end
  end
  return teams
end

local function refresh(p, frame, teams)
  local b = frame.body
  local team = (teams or panel_views({ p }))[p.force.index]
  local pref = Display.preferences(p.force)
  frame.header.heading.caption = p.admin and L("config-title") or L("title")
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
  b.team.caption = L("receiving-team", p.force.name)
  b.team.tooltip = p.force.name
  b.show.state = pref.show
  b.show.enabled = p.admin
  b.nests.state = pref.nests
  b.nests.enabled = p.admin
  b.config.caption = #storage.rules == 0 and L("first-rule") or L("sharing-rules")
  b.preset.enabled = p.admin
  for i, name in ipairs(Display.names) do
    if name == pref.preset then
      if b.preset.selected_index ~= i then b.preset.selected_index = i end
      break
    end
  end
  local style = Display.style(p.force)
  local labels = {}
  if style.team then labels[#labels + 1] = L("label-source") end
  if style.count then labels[#labels + 1] = L("label-count") end
  if style.kind then labels[#labels + 1] = L("label-type") end
  b.settings.caption = L(
    "display-settings",
    style.group and L("grouped") or L("individual"),
    style.cap,
    #labels > 0 and Text.join(labels, " + ") or L("no-labels")
  )
  local state = "icons-on"
  if not storage.enabled then
    state = "paused"
  elseif not Rules.option("show") then
    state = "master-off"
  elseif not pref.show then
    state = "team-off"
  end
  local pass = storage.pass
  if not storage.enabled then
    b.update.caption = L("updates-paused")
  elseif
    pass
    and (
      game.tick > storage.next_chart or (Rules.option("show") and game.tick > storage.next_marker)
    )
  then
    b.update.caption = L("update-delayed", L("phase-" .. pass.phase))
  elseif pass then
    b.update.caption = L("updating", L("phase-" .. pass.phase))
  else
    b.update.caption = ""
  end
  if storage.enabled then
    local age = storage.last_update
        and L("update-age", math.floor((game.tick - storage.last_update) / 60))
      or L("waiting")
    b.update.caption = pass and L("pair", b.update.caption, age) or age
  end
  local sources = team.sources
  if #sources == 0 and state == "icons-on" then state = "no-incoming" end
  if state == "icons-on" and storage.hidden_details[p.index] then state = "personal-off" end
  b.visibility.caption = L(state)
  if #sources == 0 then
    choices(b.source, { "" }, { L("no-active-sources") })
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
  if #filtered > 0 then reasons[1] = L("filtered-sources", table.concat(filtered, ", ")) end
  local stats = storage.marker_stats
  local hidden = stats
    and stats.hidden_by_bucket
    and stats.hidden_by_bucket[p.force.index .. "/" .. p.surface.index]
  if hidden then
    reasons[#reasons + 1] =
      L(style.group and "hidden-groups" or "hidden-markers", hidden, p.surface.name)
  end
  b.reasons.caption = Text.join(reasons, "\n")
  b.reasons.visible = #reasons > 0
  b.count.caption = L("team-count", team.groups, team.total)
  local view = team.surfaces[p.surface.index]
  local search = b.group_search
  if not Text.same(search.tags.keys, view.keys) then
    search.tags = { fbm_quick = "group_search", keys = view.keys }
  end
  show_groups(p, b, view.keys, view.searches)
end

local function fit(p, frame)
  local size = p.display_resolution
  frame.body.style.maximal_height = math.max(100, math.floor(size.height / p.display_scale) - 110)
  local width = math.min(360, math.max(180, math.floor(size.width / p.display_scale) - 76))
  frame.body.team.style.maximal_width = width
  frame.body.source.style.maximal_width = width
  frame.body.group_search.style.maximal_width = width
  frame.body.group_list.style.maximal_width = width
  frame.body.reasons.style.maximal_width = width
  frame.body.update.style.maximal_width = width
end

local function open(p)
  local frame = p.gui.screen.add { type = "frame", name = window, direction = "vertical" }
  local title = frame.add { type = "flow", name = "header" }
  title.drag_target = frame
  title.add { type = "label", name = "heading", caption = L("title"), style = "frame_title" }.drag_target =
    frame
  local spacer = title.add { type = "empty-widget", style = "draggable_space_header" }
  spacer.style.horizontally_stretchable = true
  spacer.drag_target = frame
  add(title, "close", {
    type = "sprite-button",
    sprite = "utility/close",
    style = "frame_action_button",
    tooltip = L("close"),
  })
  local b = frame.add {
    type = "scroll-pane",
    name = "body",
    direction = "vertical",
    horizontal_scroll_policy = "never",
  }
  b.add { type = "label", name = "team", style = "heading_2_label" }
  b.add { type = "label", name = "visibility" }
  add(b, "show", { type = "checkbox", caption = L("team-icons"), state = true, tooltip = scope })
  b.add { type = "label", name = "count" }
  b.add { type = "label", name = "update" }
  b.update.style.single_line = false
  b.add { type = "label", name = "reasons" }.style.single_line = false
  add(b, "config", { type = "button", caption = L("sharing-rules") })
  if not storage.quick_help[p.index] then
    local hint = b.add { type = "label", caption = L("personal-hint") }
    hint.style.single_line = false
    hint.style.maximal_width = 265
    storage.quick_help[p.index] = true
  end
  b.add { type = "label", name = "search_label", caption = L("search-groups") }
  add(b, "group_search", { type = "textfield", text = "", tooltip = L("search-help") })
  add(b, "group_list", { type = "drop-down", items = {} })
  add(b, "locate", {
    type = "button",
    caption = L("locate"),
    tooltip = L("locate-help"),
  })
  b.add { type = "line", name = "filters_line" }
  b.add { type = "label", name = "source_label", caption = L("source-team") }
  add(b, "source", { type = "drop-down", items = {} })
  b.add { type = "label", name = "alias_label", caption = L("alias") }
  b.add {
    type = "textfield",
    name = "alias_field",
    text = "",
    tooltip = L("alias-hint"),
  }
  add(b, "apply_alias", { type = "button", caption = L("apply-name") })
  add(b, "include", {
    type = "checkbox",
    caption = L("include-source"),
    state = true,
    tooltip = scope,
  })
  add(b, "nests", {
    type = "checkbox",
    caption = L("show-nests"),
    state = true,
    tooltip = L("nests-hint"),
  })
  b.add { type = "label", name = "preset_label", caption = L("preset") }
  add(b, "preset", {
    type = "drop-down",
    items = {
      L("preset-server"),
      L("preset-minimal"),
      L("preset-balanced"),
      L("preset-detailed"),
    },
  })
  b.add { type = "label", name = "settings" }
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
  if button.number ~= indicator or type(button.tooltip) ~= "table" then
    button.number = indicator
    button.toggled = shown
    button.tooltip = shown and L("hide-details") or L("show-details")
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
    if frame and (replace_old_panels or not frame.body or not frame.body.group_search) then
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
  if action == "group_search" and event.name == ev.on_gui_text_changed then
    show_groups(p, frame.body, el.tags.keys or {})
    return true
  end
  if event.name == ev.on_gui_click then
    if action == "close" then
      frame.destroy()
    elseif action == "config" and p.admin then
      frame.destroy()
      if #storage.rules == 0 then
        RuleEditor.add(p)
      else
        RuleEditor.list(p)
      end
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
        p.print(L("alias-changed"))
        return true
      end
      local name = field.text:match("^%s*(.-)%s*$")
      local _, length = name:gsub("[^\128-\191]", "")
      if length > 64 or name:find("[%c%[%]]") then
        p.print(L("alias-error"))
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
      local rec = refresh_locate(p, frame.body)
      if rec then
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
  if action == "group_list" and event.name == ev.on_gui_selection_state_changed then
    refresh_locate(p, frame.body)
    return true
  end
  if action == "source" or not p.admin then
    refresh(p, frame)
    return true
  end
  local pref = Display.preferences(p.force)
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
