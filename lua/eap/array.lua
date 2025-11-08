local debug = require("eap.debug")

local M = {
  ---@param a1 any[] First array.
  ---@param a2 any[] Second array.
  ---@return any[] # First array concated with second array.
  concat = function(a1, a2)
    local result = { unpack(a1) }
    local n = #a1
    for i = 1, #a2 do
      result[n + i] = a2[i]
    end
    return result
  end,
}

debug.print(M.concat({ 1, 2, 3 }, { 1, 2, 3 }))

return M
