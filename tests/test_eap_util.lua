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
local child = MiniTest.new_child_neovim()

T["util.wipe_other_buffers()"] = new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
      child.lua([[M = require('eap.util')]])
    end,
    post_once = child.stop,
  },
})

T["util.wipe_other_buffers()"]["works"] = function()
  child.fn.bufadd("foo")
  child.fn.bufadd("bar")
  child.fn.bufadd("blergs")
  child.cmd([[b bar]])
  child.lua([[M.wipe_other_buffers()]])
  local bufs = child.api.nvim_list_bufs()
  eq(1, #bufs)
end

return T
