local mod = script.mod_name
local sections = {
  [mod] = { "overview", "first_steps" },
  map_controls = { "personal", "locate", "chart" },
  sharing = { "create_rule", "direction", "display" },
  surfaces = { "select_surfaces", "future", "entities" },
  troubleshooting = { "missing", "cap", "updates" },
}

remote.add_interface(mod, {
  informatron_menu = function()
    return { map_controls = 1, sharing = 1, surfaces = 1, troubleshooting = 1 }
  end,
  informatron_page_content = function(data)
    local page = sections[data.page_name]
    if not page then return end
    for _, section in ipairs(page) do
      data.element.add {
        type = "label",
        style = "heading_2_label",
        caption = {
          mod .. ".heading_" .. section,
        },
      }
      data.element.add { type = "label", caption = { mod .. ".text_" .. section } }
    end
  end,
})
