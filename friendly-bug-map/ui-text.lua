local Text = {}

function Text.get(key, ...)
  return { "bug-manager." .. key, ... }
end

function Text.same(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
  for i = 1, #a do
    if not Text.same(a[i], b[i]) then return false end
  end
  return true
end

function Text.join(items, separator)
  if #items == 0 then return "" end
  if #items == 1 then return items[1] end
  if #items > 9 then
    local parts = {}
    for i = 1, #items, 9 do
      local chunk = {}
      for j = i, math.min(i + 8, #items) do
        chunk[#chunk + 1] = items[j]
      end
      parts[#parts + 1] = Text.join(chunk, separator)
    end
    return Text.join(parts, separator)
  end
  local result = { "", items[1] }
  for i = 2, #items do
    result[#result + 1] = separator
    result[#result + 1] = items[i]
  end
  return result
end

return Text
