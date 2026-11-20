-- Each pass samples a finite population in registry order. The grid indexes
-- anchors, not members. Anchors in a partition are at least D tiles apart.
local Rules = require("rules")
local Display = require("display")

local Groups = {}

local function distance(a, b)
  local x, y = a.x - b.x, a.y - b.y
  return x * x + y * y
end

local function bin(part, x, y)
  return part .. "/" .. x .. "/" .. y
end

function Groups.begin(p)
  p.groups, p.grid, p.members, p.membership, p.heaps = {}, {}, {}, {}, {}
  p.centres = {}
  p.candidates, p.grouped_bugs, p.selected = 0, 0, 0
  p.radius = Rules.option("cell")
  p.styles = {}
  p.hidden_groups, p.hidden_individuals = 0, 0
  p.hidden_by_bucket = {}
end

local function nearest(p, part, e, pos, old)
  local r = p.radius
  -- A small release margin retains membership through jitter at the edge.
  if old and p.groups[old] and distance(pos, p.groups[old].anchor) <= (r * 1.125) ^ 2 then
    return old
  end
  local bx, by = math.floor(pos.x / r), math.floor(pos.y / r)
  local best, score
  for x = bx - 1, bx + 1 do
    for y = by - 1, by + 1 do
      local anchors = p.grid[bin(part, x, y)]
      if anchors then
        for _, key in ipairs(anchors) do
          local d = distance(pos, p.groups[key].anchor)
          if d <= r * r and (not best or d < score or (d == score and key < best)) then
            best, score = key, d
          end
        end
      end
    end
  end
  if best then return best end
  local key = old
  local previous = key and storage.group_centres and storage.group_centres[key]
  local reuse = previous and not p.groups[key] and distance(pos, previous) <= (r * 1.125) ^ 2
  if previous and not reuse and not p.groups[key] then
    local record = storage.tags[key]
    local node = record and storage.nodes[record.representative]
    local representative = node and node.entity
    reuse = representative
      and representative.valid
      and representative.surface == e.surface
      and representative.force == e.force
      and distance(pos, representative.position) <= r * r
  end
  if not reuse then
    storage.group_serial = (storage.group_serial or 0) + 1
    key = part .. "/g" .. storage.group_serial
  end
  local cell = bin(part, bx, by)
  p.grid[cell] = p.grid[cell] or {}
  table.insert(p.grid[cell], key)
  return key
end

function Groups.sample(p, e, f)
  local pos = e.position
  if not f.is_chunk_charted(e.surface, { math.floor(pos.x / 32), math.floor(pos.y / 32) }) then
    return
  end
  local bucket = f.index .. "/" .. e.surface.index
  local kind = e.type == "unit" and "bug" or e.type == "unit-spawner" and "nest" or "turret"
  local part = table.concat({ bucket, e.force.index, kind }, "/")
  local id = e.unit_number
  local member = part .. "/" .. id
  local key = member
  local style = p.styles[f.index]
  if not style then
    style = Display.style(f)
    p.styles[f.index] = style
  end
  if style.group then
    key = nearest(p, part, e, pos, storage.membership and storage.membership[member])
    p.membership[member] = key
    if kind == "bug" then p.grouped_bugs = p.grouped_bugs + 1 end
  end
  local m = p.groups[key]
  if not m then
    m = {
      key = key,
      bucket = bucket,
      anchor = pos,
      sum_x = 0,
      sum_y = 0,
      count = 0,
      priority = id,
      force = f.index,
      surface = e.surface.index,
      source = e.force.name,
      kind = kind,
      species = e.name,
      group = style.group,
      style = style,
    }
    p.groups[key] = m
    p.candidates = p.candidates + 1
  end
  m.sum_x, m.sum_y = m.sum_x + pos.x, m.sum_y + pos.y
  m.count = m.count + 1
  m.priority = math.min(m.priority, id)
  if m.species ~= e.name then m.species = "Mixed" end
  p.members[#p.members + 1] = { group = m, entity = e, pos = pos, id = id }
end

-- Worst selected group at the heap root. Maintain the top cap incrementally.
local function worse(a, b)
  return a.count < b.count or (a.count == b.count and a.priority > b.priority)
end

function Groups.rank(p, m)
  if m.group then p.centres[m.key] = { x = m.sum_x / m.count, y = m.sum_y / m.count } end
  local heap = p.heaps[m.bucket]
  if not heap then
    heap = {}
    p.heaps[m.bucket] = heap
  end
  if #heap < m.style.cap then
    local i = #heap + 1
    while i > 1 do
      local parent = math.floor(i / 2)
      if not worse(m, heap[parent]) then break end
      heap[i] = heap[parent]
      i = parent
    end
    heap[i] = m
    p.selected = p.selected + 1
  else
    if m.group then
      p.hidden_groups = p.hidden_groups + 1
    else
      p.hidden_individuals = p.hidden_individuals + 1
    end
    p.hidden_by_bucket[m.bucket] = (p.hidden_by_bucket[m.bucket] or 0) + 1
    if not worse(heap[1], m) then return end
    p.wanted[heap[1].key] = nil
    local i = 1
    while 2 * i <= #heap do
      local child = 2 * i
      if child < #heap and worse(heap[child + 1], heap[child]) then child = child + 1 end
      if not worse(heap[child], m) then break end
      heap[i] = heap[child]
      i = child
    end
    heap[i] = m
  end
  p.wanted[m.key] = m
end

function Groups.represent(p, v)
  local m = v.group
  if not p.wanted[m.key] or not v.entity.valid then return end
  local delta_x = v.pos.x - m.sum_x / m.count
  local delta_y = v.pos.y - m.sum_y / m.count
  local score = delta_x ^ 2 + delta_y ^ 2
  local old = storage.tags[m.key]
  if old and old.representative == v.id then score = math.max(0, math.sqrt(score) - 2) ^ 2 end
  if not m.entity or score < m.score or (score == m.score and v.id < m.representative) then
    if not m.entity then table.insert(p.order, m.key) end
    m.entity, m.pos, m.score, m.representative = v.entity, v.pos, score, v.id
  end
end

function Groups.label(m, source_name)
  local noun = m.kind .. (m.count == 1 and "" or "s")
  local parts = {}
  if m.style.count then
    parts[#parts + 1] = m.count .. " " .. noun
  elseif m.kind ~= "bug" then
    parts[#parts + 1] = m.kind
  end
  if m.style.kind then parts[#parts + 1] = m.species end
  local detail = table.concat(parts, " · ")
  if m.style.team then return source_name .. (detail ~= "" and ": " .. detail or "") end
  return detail
end

return Groups
