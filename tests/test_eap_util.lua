---@module 'mini.test'

local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality
local util = require("eap.util")
local pack, table_find_key = util.pack, util.table_find_key

local T = new_set()

T["util.pack()"] = new_set()

T["util.pack()"]["works"] = function()
  local packed = pack(1, 2, 3)
  eq({ 1, 2, 3 }, packed)
end

T["util.table_find_key()"] = new_set()

T["util.table_find_key()"]["works"] = function()
  local tbl = { asdf = 1, foobar = 2 }
  local result = table_find_key(tbl, 2)
  eq("foobar", result)
end

return T
