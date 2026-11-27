local mod = script.mod_name
local pages = {
  [mod] = { "intro", { "start", "player", "admin" }, { "map_reading" } },
  map_controls = { "personal", { "button", "shown", "hidden" }, { "locate" }, { "position" } },
  sharing = { "first_rule", { "direction" }, { "outputs", "markers", "discover", "refresh" }, { "apply" } },
  team_display = { "team_controls", { "presets", "minimal", "balanced", "detailed" }, { "source" }, { "example_name" } },
  marker_style = { "style", { "counts", "icon_min", "label_min", "nest_slots" }, { "identity" }, { "example_style" } },
  surfaces = { "filters", { "surfaces", "all", "allow", "block" }, { "future" }, { "creatures" } },
  troubleshooting = { "diagnose", { "labels" }, { "missing_group" }, { "late" } },
}

local function caption(key)
  return { mod .. "." .. key }
end

local function label(parent, key, style)
  local item = parent.add { type = "label", caption = caption(key), style = style }
  item.style.single_line = false
  item.style.horizontally_squashable = true
  item.style.horizontally_stretchable = true
  return item
end

local function page_content(data)
  local page = pages[data.page_name]
  if not page then return end
  local body = data.element.add { type = "flow", direction = "vertical" }
  body.style.horizontally_stretchable = true
  body.style.vertical_spacing = 6
  label(body, "intro_" .. page[1], "semibold_label")
  for index = 2, #page do
    local section = page[index]
    local line = body.add { type = "line" }
    line.style.horizontally_stretchable = true
    label(body, "heading_" .. section[1], "heading_2_label")
    if #section == 1 then
      label(body, "text_" .. section[1])
    else
      local grid = body.add { type = "table", column_count = 2 }
      grid.style.horizontally_stretchable = true
      grid.style.horizontal_spacing = 12
      grid.style.vertical_spacing = 4
      for row = 2, #section do
        local key = section[row]
        local term = label(grid, "term_" .. key, "semibold_label")
        term.style.horizontally_stretchable = false
        term.style.maximal_width = 132
        label(grid, "text_" .. key)
      end
    end
  end
end

remote.add_interface(mod, {
  informatron_menu = function()
    return { map_controls = 1, sharing = 1, team_display = 1, marker_style = 1, surfaces = 1, troubleshooting = 1 }
  end,
  informatron_page_content = page_content,
})
