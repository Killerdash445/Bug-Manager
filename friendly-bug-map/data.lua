data:extend {
  {
    type = "custom-input",
    name = "fbm-open-config",
    key_sequence = "",
  },
}

local biter_icon = "__base__/graphics/icons/small-biter.png"
data:extend {
  {
    type = "sprite",
    name = "fbm-map-details-hidden",
    layers = {
      { filename = biter_icon, size = 64, flags = { "gui-icon" } },
      {
        filename = "__friendly-bug-map__/graphics/hidden-slash.png",
        size = 64,
        flags = { "gui-icon" },
      },
    },
  },
  {
    type = "shortcut",
    name = "fbm-bug-tracker",
    action = "lua",
    localised_description = { "bug-manager.shortcut-help" },
    icon = biter_icon,
    icon_size = 64,
    small_icon = biter_icon,
    small_icon_size = 64,
  },
}
