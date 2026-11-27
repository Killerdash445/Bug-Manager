local Text = require("ui-text")
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

function Markers.set_label(rec, icon, label, identity)
  local prefix, colour = identity and identity.prefix, identity and identity.colour
  if rec.icon == icon and rec.prefix == prefix and rec.colour == colour and Text.same(rec.label, label) then return end
  local text = "[img=entity/" .. icon .. "]"
  if label ~= "" then
    local detail = prefix and { "", prefix, " · ", label } or label
    if colour then detail = { "", "[color=" .. colour .. "]", detail, "[/color]" } end
    text = { "", text, " ", detail }
  end
  rec.marker.text = text
  rec.icon, rec.label, rec.prefix, rec.colour = icon, label, prefix, colour
end

function Markers.update(key, m, force, entity, label, identity)
  local rec = storage.tags[key]
  local pos = m.pos
  if rec and rec.marker.valid then
    rec.count = m.count
    if pos.x ~= rec.position.x or pos.y ~= rec.position.y then
      rec.marker.target = pos
      rec.position = pos
    end
  else
    local audience = storage.marker_audiences[force.index] or Markers.audience(force)
    storage.marker_audiences[force.index] = audience
    local marker = rendering.draw_text {
      surface = entity.surface,
      target = pos,
      text = "",
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
  rec.species, rec.representative = m.species, m.representative
  Markers.set_label(rec, entity.name, label, identity)
end

return Markers
