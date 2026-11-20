-- A single chart rendering represents one capped group or individual. Factorio
-- interprets an empty player filter as everyone, so hide an empty audience.
local Markers = {}

function Markers.audience(force)
  local allowed, restricted = {}, false
  for _, p in pairs(force.players) do
    if storage.hidden_details[p.index] then
      restricted = true
    else
      allowed[#allowed + 1] = p.index
    end
  end
  return { players = restricted and allowed or {}, visible = not restricted or #allowed > 0 }
end

function Markers.refresh_audience(force)
  local audience = Markers.audience(force)
  storage.marker_audiences[force.index] = audience
  for _, rec in pairs(storage.tags or {}) do
    if rec.force == force and rec.marker.valid then
      rec.marker.visible = audience.visible
      rec.marker.players = audience.players
    end
  end
end

function Markers.init()
  storage.hidden_details = storage.hidden_details or {}
  storage.marker_audiences = {}
  for key, rec in pairs(storage.tags or {}) do
    if rec.tag then
      -- Only the native chart tags owned by earlier Bug Manager versions.
      if rec.tag.valid then rec.tag.destroy() end
      storage.tags[key] = nil
    end
  end
  for _, f in pairs(game.forces) do
    Markers.refresh_audience(f)
  end
end

function Markers.update(key, m, force, entity, label)
  local rec = storage.tags[key]
  local pos = m.pos
  if rec and rec.marker.valid then
    rec.count = m.count
    if pos.x ~= rec.position.x or pos.y ~= rec.position.y then
      rec.marker.target = pos
      rec.position = pos
    end
    if rec.icon == entity.name and rec.label == label then
      rec.representative = m.representative
      return
    end
  end
  local text = "[img=entity/" .. entity.name .. "]"
  if label ~= "" then text = text .. " " .. label end
  if rec and rec.marker.valid then
    rec.marker.text = text
  else
    local audience = storage.marker_audiences[force.index] or Markers.audience(force)
    storage.marker_audiences[force.index] = audience
    local marker = rendering.draw_text {
      surface = entity.surface,
      target = pos,
      text = text,
      render_mode = "chart",
      use_rich_text = true,
      scale_with_zoom = true,
      color = { 1, 1, 1 },
      forces = { force },
      players = audience.players,
      visible = audience.visible,
    }
    rec = {
      marker = marker,
      position = pos,
      force = force,
      source = m.source,
      kind = m.kind,
      group = m.group,
      count = m.count,
    }
    storage.tags[key] = rec
  end
  rec.icon, rec.label, rec.representative = entity.name, label, m.representative
end

return Markers
