local Rules = require("rules")
local Markers = require("markers")
local Groups = require("groups")
local Display = require("display")

local Tracker = {}

-- Active entities form an insertion-ordered linked list. Cursors and LuaObjects
-- are saved with the map, including a partly finished reconciliation sweep.
local function routes_for(entity)
  if entity and entity.valid and entity.unit_number then
    return storage.routes[entity.force.name]
  end
end

local function matches(route, entity)
  return Rules.surface(route.filter, entity.surface) and Rules.entity(route.filter, entity)
end

local function matches_any(routes, entity)
  for _, route in ipairs(routes) do
    if matches(route, entity) then return true end
  end
  return false
end

function Tracker.observe(e)
  if not storage.enabled then return end
  local routes = routes_for(e)
  if not routes then return end
  local id = e.unit_number
  if storage.nodes[id] or not matches_any(routes, e) then return end
  if storage.tail then
    storage.nodes[storage.tail].next = id
  else
    storage.head = id
  end
  storage.nodes[id] = { entity = e, prev = storage.tail }
  storage.tail = id
end

local function forget(id, n)
  if n.prev then
    storage.nodes[n.prev].next = n.next
  else
    storage.head = n.next
  end
  if n.next then
    storage.nodes[n.next].prev = n.prev
  else
    storage.tail = n.prev
  end
  storage.nodes[id] = nil
end

-- A displayed count can describe several species. Reuse it only when the
-- receiving team retains the old entity filter on this surface.
local function covers_filter(current, old)
  for _, category in ipairs(Rules.categories) do
    if old[category] and not current[category] then return false end
  end
  for name in pairs(old.include) do
    if not current.include[name] then return false end
  end
  for name in pairs(current.exclude) do
    if not old.exclude[name] then return false end
  end
  return true
end

local function permits_marker(routes, target, surface, filter)
  for _, route in ipairs(routes) do
    if
      route.target == target
      and route.rule.marker
      and Rules.surface(route.filter, surface)
      and (not filter or covers_filter(route.filter, filter))
    then
      return true
    end
  end
  return false
end

local function retain_marker(rec, previous, current)
  local tag = rec.marker
  if not tag.valid or not rec.force.valid or not rec.source then return false end
  local target, surface = rec.force.name, tag.surface
  local routes = current[rec.source] or {}
  if not permits_marker(routes, target, surface) then return false end
  for _, route in ipairs(previous[rec.source] or {}) do
    if
      route.target == target
      and route.marker ~= false
      and Rules.surface(route.filter, surface)
      and not permits_marker(routes, target, surface, route.filter)
    then
      return false
    end
  end
  return true
end

function Tracker.reset()
  if storage.marker_stats then storage.marker_stats.hidden_by_bucket = nil end
  if not Rules.option("show") then
    for _, rec in pairs(storage.tags) do
      if rec.marker.valid then rec.marker.destroy() end
    end
    storage.tags, storage.group_centres, storage.membership, storage.marker_stats = {}, {}, {}, nil
  end
  local previous = storage.routes or {}
  storage.routes = Rules.compile()
  for key, rec in pairs(storage.tags) do
    if not retain_marker(rec, previous, storage.routes) then
      if rec.marker.valid then rec.marker.destroy() end
      storage.tags[key] = nil
    end
  end
  storage.scan = nil
  storage.pass = nil
  storage.next_scan, storage.next_chart, storage.next_marker = 0, 0, 0
  storage.profile = Rules.profile()
end

function Tracker.stop()
  storage.enabled = false
  storage.group_centres, storage.membership, storage.marker_stats = {}, {}, nil
  for _, v in pairs(storage.tags) do
    if v.marker.valid then v.marker.destroy() end
  end
  storage.tags, storage.nodes = {}, {}
  storage.head, storage.tail = nil, nil
  Tracker.reset()
end

local function scan_tick(budget)
  if not storage.scan then
    if game.tick < storage.next_scan then return end
    local todo = {}
    for _, s in pairs(game.surfaces) do
      local forces = {}
      for name, routes in pairs(storage.routes) do
        for _, route in ipairs(routes) do
          if Rules.surface(route.filter, s) then
            forces[#forces + 1] = name
            break
          end
        end
      end
      if #forces > 0 then todo[#todo + 1] = { surface = s.index, forces = forces } end
    end
    storage.scan = { jobs = todo, index = 1 }
  end
  local scan = storage.scan
  for step = 1, budget do
    local job = scan.jobs[scan.index]
    if not job then
      storage.scan = nil
      storage.next_scan = game.tick + storage.profile[3]
      return
    end
    local s = game.surfaces[job.surface]
    if scan.results and scan.results[scan.cursor] then
      Tracker.observe(scan.results[scan.cursor])
      scan.cursor = scan.cursor + 1
    elseif s then
      scan.results = nil
      scan.iterator = scan.iterator or s.get_chunks()
      local chunk = scan.iterator()
      if chunk then
        scan.results =
          s.find_entities_filtered { area = chunk.area, force = job.forces, type = Rules.types }
        scan.cursor = 1
      else
        scan.index = scan.index + 1
        scan.iterator = nil
      end
    else
      scan.index = scan.index + 1
      scan.iterator = nil
      scan.results = nil
    end
  end
end

-- Chunk jobs accumulate by union for an entire pass. A matching rectangle and
-- action pair was already queued. The shortcut is local to this tick, so a
-- save/reload or phase change needs no new persistent state.
local function queue_chunks(p, recent, force, surface, pos, radius, discover, refresh)
  if radius < 0 then return end
  local left, right = math.floor((pos.x - radius) / 32), math.floor((pos.x + radius) / 32)
  local top, bottom = math.floor((pos.y - radius) / 32), math.floor((pos.y + radius) / 32)
  if
    recent.force == force
    and recent.surface == surface
    and recent.left == left
    and recent.right == right
    and recent.top == top
    and recent.bottom == bottom
    and recent.discover == discover
    and recent.refresh == refresh
  then
    return
  end
  recent.force, recent.surface, recent.left, recent.right = force, surface, left, right
  recent.top, recent.bottom, recent.discover, recent.refresh = top, bottom, discover, refresh
  for x = left, right do
    for y = top, bottom do
      local key = table.concat({ force, surface, x, y }, "/")
      local job = p.chunks[key]
      if not job then
        job = { force = force, surface = surface, x = x, y = y }
        p.chunks[key] = job
        p.jobs[#p.jobs + 1] = job
      end
      if discover then job.discover = true end
      if refresh then job.refresh = true end
    end
  end
end

local function sample(p, e, recent)
  local routes = routes_for(e)
  if not routes then return false end
  local output = {}
  for _, route in ipairs(routes) do
    if matches(route, e) then
      local r = route.rule
      local o = output[route.target] or { discover = -1, refresh = -1 }
      if r.discover then o.discover = math.max(o.discover, r.radius) end
      if r.refresh then o.refresh = math.max(o.refresh, r.radius) end
      o.marker = o.marker or r.marker
      output[route.target] = o
    end
  end
  for name, o in pairs(output) do
    local force = game.forces[name]
    if p.mark and o.marker then
      local kind = e.type == "unit-spawner" and "nest" or "other"
      if Display.allows(Display.preferences(force), e.force.name, kind) then
        Groups.sample(p, e, force)
      end
    end
    if p.chart then
      local fi, si, pos = force.index, e.surface.index, e.position
      if o.discover == o.refresh then
        queue_chunks(p, recent, fi, si, pos, o.discover, true, true)
      else
        queue_chunks(p, recent, fi, si, pos, o.discover, true, false)
        queue_chunks(p, recent, fi, si, pos, o.refresh, false, true)
      end
    end
  end
  return next(output) ~= nil
end

local function chart(job)
  local s, f = game.surfaces[job.surface], game.forces[job.force]
  if not s or not f then return end
  local cp = { job.x, job.y }
  local known = f.is_chunk_charted(s, cp)
  if known and not job.refresh or not known and not job.discover then return end
  if not s.is_chunk_generated(cp) and not (job.discover and Rules.option("generate")) then
    return
  end
  if f.is_chunk_requested_for_charting(s, cp) then return end
  local x, y = job.x * 32, job.y * 32
  f.chart(s, { { x + 0.5, y + 0.5 }, { x + 31.5, y + 31.5 } })
end

local function apply_marker(key, m)
  local e = m.entity
  local f = game.forces[m.force]
  local routes = routes_for(e)
  if
    not routes
    or e.force.name ~= m.source
    or e.surface.index ~= m.surface
    or not f
    or not matches_any(routes, e)
    or not f.is_chunk_charted(e.surface, { math.floor(m.pos.x / 32), math.floor(m.pos.y / 32) })
  then
    local old = storage.tags[key]
    if old and old.marker.valid then old.marker.destroy() end
    storage.tags[key] = nil
    return
  end
  local source_name = Display.preferences(f).aliases[m.source] or m.source
  Markers.update(key, m, f, e, Groups.label(m, source_name))
end

-- Restart marker sampling only. A chart pass already in progress must finish.
function Tracker.display_changed(force)
  local hidden = storage.marker_stats and storage.marker_stats.hidden_by_bucket
  if hidden then
    -- Cap counts are keyed by receiving force/surface. Other teams' completed counts still apply.
    for _, surface in pairs(game.surfaces) do
      hidden[force.index .. "/" .. surface.index] = nil
    end
  end
  local pref = Display.preferences(force)
  for key, rec in pairs(storage.tags) do
    if not rec.marker.valid then
      storage.tags[key] = nil
    elseif
      rec.force == force and (not rec.source or not Display.allows(pref, rec.source, rec.kind))
    then
      rec.marker.destroy()
      storage.tags[key] = nil
    end
  end
  local pass = storage.pass
  if pass and pass.mark then
    pass.mark = false
    if pass.phase ~= "sample" and pass.phase ~= "chart" then pass.phase = "done" end
  end
  storage.next_marker = 0
end

function Tracker.tick()
  if not storage.enabled then return end
  local budget = storage.profile[4]
  scan_tick(budget)
  local p = storage.pass
  if not p then
    local mark, vision =
      Rules.option("show") and game.tick >= storage.next_marker, game.tick >= storage.next_chart
    if not mark and not vision then return end
    p = {
      mark = mark,
      chart = vision,
      cursor = storage.head,
      last = storage.tail,
      phase = "sample",
      chunks = {},
      jobs = {},
      wanted = {},
      order = {},
      sampled = 0,
      ranked = 0,
      pruned = 0,
      index = 1,
    }
    if mark then Groups.begin(p) end
    storage.pass = p
    if mark then storage.next_marker = game.tick + storage.profile[2] end
    if vision then storage.next_chart = game.tick + storage.profile[1] end
  end
  local recent = p.chart and p.phase == "sample" and {}
  for step = 1, budget do
    if p.phase == "sample" and p.cursor then
      p.sampled = p.sampled + 1
      local id = p.cursor
      local n = storage.nodes[id]
      p.cursor = n.next
      if id == p.last then p.cursor = nil end
      if not sample(p, n.entity, recent) then forget(id, n) end
    elseif p.phase == "sample" then
      p.phase = "chart"
    elseif p.phase == "chart" and p.jobs[p.index] then
      chart(p.jobs[p.index])
      p.index = p.index + 1
    elseif p.phase == "chart" then
      p.phase = p.mark and "rank" or "done"
      p.index = 1
      if p.mark then p.group_key = next(p.groups) end
    elseif p.phase == "rank" and p.group_key then
      p.ranked = p.ranked + 1
      Groups.rank(p, p.groups[p.group_key])
      p.group_key = next(p.groups, p.group_key)
    elseif p.phase == "rank" then
      p.phase = "represent"
    elseif p.phase == "represent" and p.members[p.index] then
      Groups.represent(p, p.members[p.index])
      p.index = p.index + 1
    elseif p.phase == "represent" then
      p.phase, p.index, p.tag_key = "prune", 1, next(storage.tags)
    elseif p.phase == "prune" and p.tag_key then
      p.pruned = p.pruned + 1
      local k = p.tag_key
      p.tag_key = next(storage.tags, k)
      if not p.wanted[k] or not p.wanted[k].entity or not storage.tags[k].marker.valid then
        if storage.tags[k].marker.valid then storage.tags[k].marker.destroy() end
        storage.tags[k] = nil
      end
    elseif p.phase == "prune" then
      p.phase = "markers"
    elseif p.phase == "markers" and p.order[p.index] then
      local key = p.order[p.index]
      apply_marker(key, p.wanted[key])
      p.index = p.index + 1
    else
      if p.mark then
        storage.group_centres, storage.membership = p.centres, p.membership
        storage.marker_stats = {
          bugs = p.grouped_bugs,
          hidden = p.candidates - p.selected,
          hidden_groups = p.hidden_groups,
          hidden_individuals = p.hidden_individuals,
          tick = game.tick,
          hidden_by_bucket = p.hidden_by_bucket,
        }
      end
      storage.last_update = game.tick
      storage.pass = nil
      if Rules.option("debug") then log("Bug Manager completed pass at " .. game.tick) end
      return
    end
  end
end

return Tracker
