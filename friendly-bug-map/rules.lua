local Rules = {}

function Rules.option(k)
  return settings.global["fbm-" .. k].value
end

local profiles = {
  ["Low load"] = { 300, 300, 18000, 8 },
  Balanced = { 120, 120, 7200, 32 },
  Detailed = { 60, 60, 3600, 64 },
}

function Rules.profile()
  return profiles[Rules.option("preset")]
    or {
      Rules.option("vision"),
      Rules.option("markers"),
      Rules.option("scan"),
      Rules.option("budget"),
    }
end

Rules.categories = { "biters", "spitters", "other", "nests", "worms" }

function Rules.new()
  return {
    name = "Friendly bugs",
    source = "",
    receiver = "",
    enabled = true,
    two = false,
    marker = true,
    discover = true,
    refresh = true,
    radius = 32,
    mode = "All",
    surfaces = "",
    include = "",
    exclude = "",
    entity_override = false,
    surface_override = false,
    biters = true,
    spitters = true,
    other = true,
    nests = false,
    worms = false,
    platform = false,
    sandbox = false,
  }
end

function Rules.status(r)
  local missing = {}
  for _, name in ipairs({ r.source, r.receiver }) do
    if not game.forces[name] then missing[#missing + 1] = name end
  end
  if #missing > 0 then return "Missing force: " .. table.concat(missing, ", ") end
  if not r.enabled then return "Disabled" end
  if not (r.discover or r.refresh or r.marker) then return "No output selected" end
  return "Active"
end

local function names(s)
  local out = {}
  for v in s:gmatch("[^,]+") do
    out[v:match("^%s*(.-)%s*$")] = true
  end
  return out
end

function Rules.description(r)
  local state = Rules.status(r)
  if r.entity_override then
    for _, field in ipairs({ "include", "exclude" }) do
      for name in pairs(names(r[field])) do
        if not prototypes.entity[name] then
          return state .. " (missing " .. field .. " prototype: " .. name .. ")"
        end
      end
    end
  end
  return state
end

function Rules.compile()
  local routes = {}
  for _, r in ipairs(storage.rules) do
    if Rules.status(r) == "Active" then
      local f = { include = {}, exclude = {}, surfaces = {}, mode = "All" }
      for _, k in ipairs(Rules.categories) do
        f[k] = Rules.option(k)
        if r.entity_override then f[k] = r[k] end
      end
      if r.entity_override then
        f.include, f.exclude = names(r.include), names(r.exclude)
      end
      f.platform, f.sandbox = Rules.option("platform"), Rules.option("sandbox")
      if r.surface_override then
        f.platform, f.sandbox = r.platform, r.sandbox
        f.mode, f.surfaces = r.mode, names(r.surfaces)
      end
      local function link(a, b)
        routes[a] = routes[a] or {}
        table.insert(routes[a], { target = b, filter = f, rule = r, marker = r.marker })
      end
      link(r.source, r.receiver)
      if r.two and r.source ~= r.receiver then link(r.receiver, r.source) end
    end
  end
  return routes
end

function Rules.surface(f, s)
  if f.platform and s.platform then return false end
  if f.sandbox and (s.name:match("^bpsb%-") or s.name:lower():find("sandbox", 1, true)) then
    return false
  end
  return f.mode == "All" or (f.mode == "Allowlist") == (f.surfaces[s.name] == true)
end

local category = {}
for _, size in ipairs({ "small", "medium", "big", "behemoth" }) do
  category[size .. "-biter"] = "biters"
  category[size .. "-spitter"] = "spitters"
  category[size .. "-worm-turret"] = "worms"
end

Rules.types = {
  "unit",
  "unit-spawner",
  "turret",
  "ammo-turret",
  "electric-turret",
  "fluid-turret",
  "artillery-turret",
}

local allowed = {}
for _, t in ipairs(Rules.types) do
  allowed[t] = true
end

function Rules.entity(f, e)
  if not allowed[e.type] or f.exclude[e.name] then return false end
  local cat = category[e.name] or ({ unit = "other", ["unit-spawner"] = "nests" })[e.type]
  return f.include[e.name] or f[cat]
end

return Rules
