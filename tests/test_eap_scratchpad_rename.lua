---@module 'mini.test'

local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
      child.lua([[M = require('eap.scratchpad')]])
      child.lua([[M._state():reset()]])
      child.lua([[M._state():init()]])
      child.lua([[M.setup()]])
    end,
    post_once = child.stop,
  },
})

T["ScratchpadRename"] = new_set()

T["ScratchpadRename"]["renames active scratchpad"] = function()
  child.lua([[vim.ui.input = function(_, on_confirm) on_confirm("notes") end]])
  child.lua([[vim.cmd("ScratchpadCreate")]])
  child.lua([[
    local pad = M._state():find_by_name("notes")
    M._state():activate(pad.scratchpad_id)
  ]])
  child.lua([[vim.cmd("ScratchpadRename work")]])
  local name = child.lua([[
    local active = M._state():active()
    return active and active.name or nil
  ]])
  eq("work", name)
end

T["ScratchpadRename"]["renames file on disk"] = function()
  child.lua([[vim.ui.input = function(_, on_confirm) on_confirm("notes") end]])
  child.lua([[vim.cmd("ScratchpadCreate")]])
  child.lua([[
    local pad = M._state():find_by_name("notes")
    M._state():activate(pad.scratchpad_id)
  ]])
  child.lua([[vim.cmd("ScratchpadRename work")]])
  local result = child.lua([[
    local state = M._state()
    local active = state:active()
    if not active then return nil end
    local stat = vim.uv.fs_stat(active.filename)
    return stat ~= nil
  ]])
  eq(true, result)
end

T["ScratchpadRename"]["old file no longer exists"] = function()
  child.lua([[vim.ui.input = function(_, on_confirm) on_confirm("notes") end]])
  child.lua([[vim.cmd("ScratchpadCreate")]])
  child.lua([[
    local pad = M._state():find_by_name("notes")
    M._state():activate(pad.scratchpad_id)
  ]])
  local old_path = child.lua([[
    local active = M._state():active()
    return active and active.filename or nil
  ]])
  child.lua([[vim.cmd("ScratchpadRename work")]])
  local old_exists = child.lua(string.format("return vim.uv.fs_stat(%q) ~= nil", old_path))
  eq(false, old_exists)
end

T["ScratchpadRename"]["fails with empty name"] = function()
  child.lua([[vim.ui.input = function(_, on_confirm) on_confirm("notes") end]])
  child.lua([[vim.cmd("ScratchpadCreate")]])
  child.lua([[
    local pad = M._state():find_by_name("notes")
    M._state():activate(pad.scratchpad_id)
  ]])
  child.lua([[vim.cmd("ScratchpadRename")]])
  local name = child.lua([[
    local active = M._state():active()
    return active and active.name or nil
  ]])
  eq("notes", name)
end

T["ScratchpadRename"]["fails with duplicate name"] = function()
  child.lua([[vim.ui.input = function(_, on_confirm) on_confirm("notes") end]])
  child.lua([[vim.cmd("ScratchpadCreate")]])
  child.lua([[vim.ui.input = function(_, on_confirm) on_confirm("work") end]])
  child.lua([[vim.cmd("ScratchpadCreate")]])
  child.lua([[
    local pad = M._state():find_by_name("notes")
    M._state():activate(pad.scratchpad_id)
  ]])
  child.lua([[vim.cmd("ScratchpadRename work")]])
  local pads = child.lua([[
    local all = M._state():all()
    local names = {}
    for _, p in ipairs(all) do table.insert(names, p.name) end
    return names
  ]])
  eq(2, #pads)
end

T["ScratchpadRename"]["fails with no scratchpads"] = function()
  child.lua([[vim.cmd("ScratchpadRename work")]])
  local pads = child.lua([[
    local all = M._state():all()
    return all and #all or 0
  ]])
  eq(0, pads)
end

T["ScratchpadRename"]["renames non-active scratchpad via select"] = function()
  child.lua([[vim.ui.input = function(_, on_confirm) on_confirm("notes") end]])
  child.lua([[vim.cmd("ScratchpadCreate")]])
  child.lua([[vim.ui.input = function(_, on_confirm) on_confirm("work") end]])
  child.lua([[vim.cmd("ScratchpadCreate")]])
  child.lua([[vim.ui.select = function(items, _, on_confirm)
    for _, item in ipairs(items) do
      if item.name == "notes" then on_confirm(item) return end
    end
    on_confirm(nil)
  end]])
  child.lua([[vim.cmd("ScratchpadRename personal")]])
  local pads = child.lua([[
    local all = M._state():all()
    local names = {}
    for _, p in ipairs(all) do table.insert(names, p.name) end
    return names
  ]])
  eq(true, vim.tbl_contains(pads, "personal"))
  eq(true, vim.tbl_contains(pads, "work"))
end

T["ScratchpadRename"]["renamed scratchpad stays active"] = function()
  child.lua([[vim.ui.input = function(_, on_confirm) on_confirm("notes") end]])
  child.lua([[vim.cmd("ScratchpadCreate")]])
  child.lua([[
    local pad = M._state():find_by_name("notes")
    M._state():activate(pad.scratchpad_id)
  ]])
  child.lua([[vim.cmd("ScratchpadRename work")]])
  local active = child.lua([[
    local a = M._state():active()
    return a and a.name or nil
  ]])
  eq("work", active)
end

return T
