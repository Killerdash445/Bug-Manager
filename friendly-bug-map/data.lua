data:extend {
  {
    type = "custom-input",
    name = "fbm-open-config",
    key_sequence = "",
    localised_name = "Open Bug Manager configuration",
  },
}

local biter_icon = "__base__/graphics/icons/small-biter.png"
data:extend {
  {
    type = "shortcut",
    name = "fbm-bug-tracker",
    action = "lua",
    localised_name = "Bug Manager",
    localised_description = "Open Bug Manager configuration and sharing rules (admins).",
    icon = biter_icon,
    icon_size = 64,
    small_icon = biter_icon,
    small_icon_size = 64,
  },
}
