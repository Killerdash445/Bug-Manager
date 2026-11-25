for order, row in ipairs(require("options")) do
  local kind = type(row[2])
  local p = {
    type = ({ boolean = "bool-setting", string = "string-setting", number = "int-setting" })[kind],
    name = "fbm-" .. row[1],
    setting_type = "runtime-global",
    default_value = row[2],
    order = string.format("%02d", order),
  }
  if kind == "number" then
    p.minimum_value, p.maximum_value = row[3], row[4]
  elseif kind == "string" then
    p.allowed_values = row[3]
  end
  data:extend { p }
end
