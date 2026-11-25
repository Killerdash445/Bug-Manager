local mod = script.mod_name
local sections = {
  [mod] = { "overview", "first_steps", "admin_start" },
  map_controls = { "personal", "locate", "chart" },
  sharing = { "create_rule", "example", "direction" },
  team_display = { "display", "presets", "source" },
  surfaces = { "select_surfaces", "future", "entities" },
  troubleshooting = { "missing", "cap", "updates" },
}

remote.add_interface(mod, {
  informatron_menu = function()
    return { map_controls = 1, sharing = 1, team_display = 1, surfaces = 1, troubleshooting = 1 }
  end,
  informatron_page_content = function(data)
    local page = sections[data.page_name]
    if not page then return end
    for i, section in ipairs(page) do
      local heading = data.element.add {
        type = "label",
        style = "heading_2_label",
        caption = { mod .. ".heading_" .. section },
      }
      if i > 1 then heading.style.top_margin = 8 end
      data.element.add { type = "label", caption = { mod .. ".text_" .. section } }
    end
  end,
})
