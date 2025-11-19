---@module 'mini.test'

local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality
local concat = require("eap.array").concat

local T = new_set()

T["array.concat()"] = new_set()

T["array.concat()"]["works"] = function()
  local result = concat({ 1, 2 }, { 3, 4 })
  eq({ 1, 2, 3, 4 }, result)
end

return T
