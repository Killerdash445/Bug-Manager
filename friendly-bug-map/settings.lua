for order, row in ipairs(require("options")) do
  local kind = type(row[2])
  local p = {
    type = ({ boolean = "bool-setting", string = "string-setting", number = "int-setting" })[kind],
    name = "fbm-" .. row[1],
    setting_type = "runtime-global",
    default_value = row[2],
    localised_name = row[3],
    localised_description = row[4],
    order = string.format("%02d", order),
  }
  if kind == "number" then
    p.minimum_value, p.maximum_value = row[5], row[6]
  elseif kind == "string" then
    p.allowed_values = row[5]
  end
  data:extend { p }
end
