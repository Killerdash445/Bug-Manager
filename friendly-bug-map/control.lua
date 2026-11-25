local Text = require("ui-text")
local L = Text.get
local Rules = require("rules")
local Tracker = require("tracker")
local RuleEditor = require("gui")
local Panel = require("quick-panel")
local Display = require("display")
local Markers = require("markers")
local options = require("options")

local ev = defines.events

if script.active_mods.informatron then require("informatron-guide") end

local function remember_settings()
  storage.approved_settings = {}
  for _, option in ipairs(options) do
    storage.approved_settings["fbm-" .. option[1]] = Rules.option(option[1])
  end
end

script.on_init(function()
  Markers.init()
  Panel.init()
  remember_settings()
  storage.enabled = true
  storage.rules = {}
  storage.revision = 0
  storage.nodes, storage.tags, storage.editors = {}, {}, {}
  Tracker.reset()
end)

script.on_configuration_changed(function(event)
  local change = event.mod_changes and event.mod_changes["friendly-bug-map"]
  Markers.init()
  Panel.init(change and (change.old_version == "1.2.0" or change.old_version == "1.2.1"))
  if change and change.old_version == "1.0.0" then
    -- Factorio can adopt a new prototype default for values left at default.
    -- Recover the effective settings recorded in the old save first.
    local saved = storage.approved_settings or {}
    local cap, team = saved["fbm-cap"], saved["fbm-team"]
    if cap ~= nil then settings.global["fbm-cap"] = { value = cap } end
    if team ~= nil then settings.global["fbm-team"] = { value = team } end
  end
  remember_settings()
  if change and change.old_version ~= change.new_version then
    for _, p in pairs(game.players) do
      local frame = p.gui.screen.fbm_window
      if frame and frame.error and not frame.preview then RuleEditor.close(p) end
    end
  end
  RuleEditor.changed()
end)

script.on_event(ev.on_tick, Tracker.tick)
script.on_event({
  ev.on_entity_spawned,
  ev.on_biter_base_built,
  ev.on_built_entity,
  ev.on_robot_built_entity,
  ev.script_raised_built,
  ev.script_raised_revive,
  ev.script_raised_teleported,
}, function(e)
  Tracker.observe(e.entity)
end)
script.on_event(ev.on_entity_cloned, function(e)
  Tracker.observe(e.destination)
end)

script.on_event({
  ev.on_force_created,
  ev.on_surface_created,
  ev.on_surface_deleted,
  ev.on_surface_renamed,
  ev.on_surface_cleared,
}, RuleEditor.changed)
script.on_event(ev.on_forces_merging, function(e)
  -- Retire the source team's overlays before the force merge.
  for key, m in pairs(storage.tags) do
    if m.marker.valid and m.force == e.source then
      m.marker.destroy()
      storage.tags[key] = nil
    end
  end
end)

script.on_event(ev.on_forces_merged, function(e)
  storage.marker_audiences[e.source_index] = nil
  Markers.refresh_audience(e.destination)
  Display.merged(e)
  for _, r in ipairs(storage.rules) do
    if r.source == e.source_name then r.source = e.destination.name end
    if r.receiver == e.source_name then r.receiver = e.destination.name end
  end
  storage.notice = L("merged-force", e.source_name, e.destination.name)
  RuleEditor.changed()
end)

script.on_event(ev.on_runtime_mod_setting_changed, function(e)
  if storage.approved_settings[e.setting] == nil then return end
  local p = e.player_index and game.get_player(e.player_index)
  if p and not p.admin then
    settings.global[e.setting] = { value = storage.approved_settings[e.setting] }
    p.print(L("settings-admin"))
    return
  end
  storage.approved_settings[e.setting] = settings.global[e.setting].value
  RuleEditor.changed()
end)

local function status(send)
  local lines = {}
  local function reply(line)
    lines[#lines + 1] = line
  end
  reply(L(storage.enabled and "status-enabled" or "status-stopped"))
  if #storage.rules == 0 then reply(L("status-no-rules")) end
  for _, r in ipairs(storage.rules) do
    reply(
      L(
        "rule-summary",
        r.name,
        r.source,
        r.two and "↔" or "→",
        r.receiver,
        Rules.description(r)
      )
    )
  end
  if storage.notice then reply(storage.notice) end
  local counts = {}
  for _, n in pairs(storage.nodes) do
    local e = n.entity
    if e.valid then
      local key = e.force.name .. " / " .. e.surface.name
      counts[key] = (counts[key] or 0) + 1
    end
  end
  local total = 0
  for k, v in pairs(counts) do
    reply(L("indexed-team", k, v))
    total = total + v
  end
  local tags, groups = 0, 0
  for _, v in pairs(storage.tags) do
    if v.marker.valid then
      tags = tags + 1
      if v.group then groups = groups + 1 end
    end
  end
  reply(L("indexed", total, tags, groups))
  local stats = storage.marker_stats
  if stats then
    reply(
      L(
        "last-census",
        stats.tick,
        stats.bugs,
        stats.hidden_groups or 0,
        stats.hidden_individuals or 0
      )
    )
  else
    reply(L("no-census"))
  end
  local p = storage.pass
  reply(L("last-tick", storage.last_update or L("none"), L("phase-" .. (p and p.phase or "idle"))))
  if p then
    reply(L("pass-counts", p.sampled, #p.jobs, p.ranked, p.candidates or 0, p.pruned))
    local sizes = { chart = #p.jobs, represent = p.members and #p.members or 0, markers = #p.order }
    if sizes[p.phase] then reply(L("items-left", math.max(0, sizes[p.phase] - p.index + 1))) end
  end
  local s = storage.scan
  reply(s and L("scan-progress", s.index, #s.jobs) or L("scan-idle"))
  send(Text.join(lines, "\n"))
end

commands.add_command("bug-map", L("command-help"), function(e)
  local p = e.player_index and game.get_player(e.player_index)
  local function reply(msg)
    if p then
      p.print(msg)
    else
      rcon.print(msg)
      log(msg)
    end
  end
  local a = (e.parameter or "status"):match("^%s*(.-)%s*$")
  if a == "reset-ui" then
    if p then
      Panel.reset(p)
    else
      reply(L("reset-ingame"))
    end
    return
  end
  if p and not p.admin then
    reply(L("admin-required"))
    return
  end
  if a == "config" then
    if p then
      RuleEditor.list(p)
    else
      reply(L("config-ingame"))
    end
  elseif a == "status" then
    status(reply)
  elseif a == "off" or a == "clear" then
    Tracker.stop()
    RuleEditor.changed()
    reply(L("stopped"))
  elseif a == "on" then
    storage.enabled = true
    RuleEditor.changed()
    reply(L("started"))
  elseif a == "refresh" then
    if storage.enabled then
      Tracker.reset()
      reply(L("queued"))
    else
      reply(L("start-first"))
    end
  else
    reply(L("usage"))
  end
end)

script.on_event(ev.on_gui_click, function(e)
  if not Panel.event(e) then RuleEditor.click(e, status, Panel.reset) end
end)

script.on_event(ev.on_lua_shortcut, function(e)
  if e.prototype_name == "fbm-bug-tracker" then Panel.toggle(game.get_player(e.player_index)) end
end)

script.on_event({ ev.on_gui_checked_state_changed, ev.on_gui_selection_state_changed }, function(e)
  if not Panel.event(e) then RuleEditor.field_event(e) end
end)

script.on_event(ev.on_gui_text_changed, function(e)
  if not Panel.event(e) then RuleEditor.field_event(e) end
end)
script.on_nth_tick(60, Panel.refresh_open)
script.on_event({
  ev.on_player_created,
  ev.on_player_joined_game,
  ev.on_player_changed_force,
  ev.on_player_controller_changed,
  ev.on_player_promoted,
  ev.on_player_display_resolution_changed,
  ev.on_player_display_scale_changed,
}, function(e)
  local p = game.get_player(e.player_index)
  if e.name == ev.on_player_created or e.name == ev.on_player_changed_force then
    if e.force and e.force.valid then Markers.refresh_audience(e.force) end
    Markers.refresh_audience(p.force)
  end
  Panel.sync(p)
  RuleEditor.fit(p)
end)
script.on_event(ev.on_gui_closed, function(e)
  Panel.closed(e)
  RuleEditor.closed(e)
end)

script.on_event("fbm-open-config", function(e)
  local p = game.get_player(e.player_index)
  if p and p.admin then RuleEditor.list(p) end
end)

script.on_event({ ev.on_player_demoted, ev.on_player_left_game }, function(e)
  local p = game.get_player(e.player_index)
  RuleEditor.close(p)
  if e.name == ev.on_player_demoted then Panel.sync(p) end
end)

script.on_event(ev.on_player_removed, function(e)
  storage.editors[e.player_index] = nil
  storage.quick_help[e.player_index] = nil
  storage.hidden_details[e.player_index] = nil
  for _, f in pairs(game.forces) do
    Markers.refresh_audience(f)
  end
end)
