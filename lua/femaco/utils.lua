local M = {}

M.any = function(func, items)
  for _, item in ipairs(items) do
    if func(item) then
      return true
    end
  end
  return false
end

M.clip_val = function(min, val, max)
  if val < min then
    val = min
  end
  if val > max then
    val = max
  end
  return val
end

return M
