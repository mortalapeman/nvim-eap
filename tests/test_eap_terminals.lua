---@module 'mini.test'

local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
      child.lua([[M = require('eap.terminals')]])
      child.lua([[M.setup()]])
    end,
    post_once = child.stop,
  },
})

T["terminals.toggle()"] = new_set()

T["terminals.toggle()"]["opens without error"] = function()
  child.lua([[M.toggle()]])
  local buf_id = child.lua("return M._state().buf_id")
  eq("number", type(buf_id))
end

T["terminals.toggle()"]["creates a valid buffer"] = function()
  child.lua([[M.toggle()]])
  local valid = child.lua("return vim.api.nvim_buf_is_valid(M._state().buf_id)")
  eq(true, valid)
end

T["terminals.toggle()"]["sets up esc keymap on buffer"] = function()
  child.lua([[M.toggle()]])
  local has_keymap = child.lua([[
    local buf_id = M._state().buf_id
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf_id, 't')) do
      if m.lhs == '<Esc>' then return true end
    end
    return false
  ]])
  eq(true, has_keymap)
end

T["terminals.toggle()"]["creates floating window"] = function()
  child.lua([[M.toggle()]])
  local win_config = child.lua("return vim.api.nvim_win_get_config(M._state().win_id)")
  eq("editor", win_config.relative)
end

T["terminals.toggle()"]["singleton reuses buffer"] = function()
  child.lua([[M.toggle()]])
  local first_buf = child.lua("return M._state().buf_id")
  child.lua([[M.toggle()]])
  child.lua([[M.toggle()]])
  local second_buf = child.lua("return M._state().buf_id")
  eq(first_buf, second_buf)
end

T["terminals.mode()"] = new_set()

T["terminals.mode()"]["shows T in terminal mode"] = function()
  child.lua([[M.toggle()]])
  local text = child.lua("return M._get_extmark_text()")
  eq(" T ", text)
end

T["terminals.mode()"]["shows N in normal mode"] = function()
  child.lua([[M.toggle()]])
  child.lua("vim.cmd('stopinsert')")
  local text = child.lua("return M._get_extmark_text()")
  eq(" N ", text)
end

T["terminals.mode()"]["updates when switching modes"] = function()
  child.lua([[M.toggle()]])
  eq(" T ", child.lua("return M._get_extmark_text()"))
  child.lua("vim.cmd('stopinsert')")
  eq(" N ", child.lua("return M._get_extmark_text()"))
  child.lua("vim.cmd('startinsert')")
  eq(" T ", child.lua("return M._get_extmark_text()"))
end

return T
