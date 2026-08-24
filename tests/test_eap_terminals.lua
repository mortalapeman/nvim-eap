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

T["terminals.status()"] = new_set()

T["terminals.status()"]["shows T in terminal mode"] = function()
  child.lua([[M.toggle()]])
  local text = child.lua("return M._get_status_text()")
  eq(" T ", text)
end

T["terminals.status()"]["shows N in normal mode"] = function()
  child.lua([[M.toggle()]])
  child.lua("vim.cmd('stopinsert')")
  local text = child.lua("return M._get_status_text()")
  eq(" N ", text)
end

T["terminals.status()"]["updates when switching modes"] = function()
  child.lua([[M.toggle()]])
  eq(" T ", child.lua("return M._get_status_text()"))
  child.lua("vim.cmd('stopinsert')")
  eq(" N ", child.lua("return M._get_status_text()"))
  child.lua("vim.cmd('startinsert')")
  eq(" T ", child.lua("return M._get_status_text()"))
end

T["terminals.status()"]["status window exists"] = function()
  child.lua([[M.toggle()]])
  local has_status = child.lua([[
    local state = M._state()
    return state.win_id ~= nil
  ]])
  eq(true, has_status)
end

T["terminals.rename()"] = new_set()

T["terminals.rename()"]["sets name in state"] = function()
  child.lua([[M.rename("dev")]])
  local name = child.lua("return M._state().name")
  eq("dev", name)
end

T["terminals.rename()"]["shows name with T in terminal mode"] = function()
  child.lua([[M.toggle()]])
  child.lua([[M.rename("dev")]])
  local text = child.lua("return M._get_status_text()")
  eq(" dev  T ", text)
end

T["terminals.rename()"]["shows name with N in normal mode"] = function()
  child.lua([[M.toggle()]])
  child.lua([[M.rename("dev")]])
  child.lua("vim.cmd('stopinsert')")
  local text = child.lua("return M._get_status_text()")
  eq(" dev  N ", text)
end

T["terminals.rename()"]["name persists across toggle"] = function()
  child.lua([[M.toggle()]])
  child.lua([[M.rename("prod")]])
  child.lua([[M.toggle()]])
  child.lua([[M.toggle()]])
  local text = child.lua("return M._get_status_text()")
  eq(" prod  T ", text)
end

T["terminals.rename()"]["clears name with empty string"] = function()
  child.lua([[M.toggle()]])
  child.lua([[M.rename("dev")]])
  child.lua([[M.rename("")]])
  local text = child.lua("return M._get_status_text()")
  eq(" T ", text)
end

T["terminals.as_worker()"] = new_set()

T["terminals.as_worker()"]["fails without open terminal"] = function()
  child.lua([[M.as_worker()]])
  local workers = child.lua("return M._workers()")
  eq(0, #workers)
end

T["terminals.as_worker()"]["fails without name"] = function()
  child.lua([[M.toggle()]])
  child.lua([[M.as_worker()]])
  local workers = child.lua("return M._workers()")
  eq(0, #workers)
  local state = child.lua("return M._state()")
  eq("number", type(state.buf_id))
end

T["terminals.as_worker()"]["moves terminal to workers"] = function()
  child.lua([[M.toggle()]])
  child.lua([[M.rename("dev")]])
  child.lua([[M.as_worker()]])
  local workers = child.lua("return M._workers()")
  eq(1, #workers)
  eq("dev", workers[1].name)
  local state = child.lua("return M._state()")
  eq(nil, state.buf_id)
end

T["terminals.as_worker()"]["clears current terminal state"] = function()
  child.lua([[M.toggle()]])
  child.lua([[M.rename("dev")]])
  child.lua([[M.as_worker()]])
  local state = child.lua("return M._state()")
  eq(nil, state.win_id)
  eq(nil, state.buf_id)
  eq("", state.name)
end

T["terminals.as_worker()"]["creates new current terminal after moving"] = function()
  child.lua([[M.toggle()]])
  child.lua([[M.rename("dev")]])
  child.lua([[M.as_worker()]])
  child.lua([[M.toggle()]])
  local state = child.lua("return M._state()")
  eq("number", type(state.buf_id))
  eq("", state.name)
end

T["terminals.as_worker()"]["fails with duplicate name"] = function()
  child.lua([[M.toggle()]])
  child.lua([[M.rename("dev")]])
  child.lua([[M.as_worker()]])
  child.lua([[M.toggle()]])
  child.lua([[M.rename("dev")]])
  child.lua([[M.as_worker()]])
  local workers = child.lua("return M._workers()")
  eq(1, #workers)
end

T["terminals.as_worker()"]["multiple workers with different names"] = function()
  child.lua([[M.toggle()]])
  child.lua([[M.rename("dev")]])
  child.lua([[M.as_worker()]])
  child.lua([[M.toggle()]])
  child.lua([[M.rename("prod")]])
  child.lua([[M.as_worker()]])
  local workers = child.lua("return M._workers()")
  eq(2, #workers)
end

T["terminals.toggle_worker()"] = new_set()

T["terminals.toggle_worker()"]["opens worker window"] = function()
  child.lua([[M.toggle()]])
  child.lua([[M.rename("dev")]])
  child.lua([[M.as_worker()]])
  local workers = child.lua("return M._workers()")
  child.lua(string.format("M.toggle_worker(%d)", workers[1].id))
  local worker_state = child.lua(string.format([[
    local w = M._workers()[1]
    return { win_id = w.win_id }
  ]]))
  eq("number", type(worker_state.win_id))
end

T["terminals.toggle_worker()"]["closes worker window"] = function()
  child.lua([[M.toggle()]])
  child.lua([[M.rename("dev")]])
  child.lua([[M.as_worker()]])
  local workers = child.lua("return M._workers()")
  child.lua(string.format("M.toggle_worker(%d)", workers[1].id))
  child.lua(string.format("M.toggle_worker(%d)", workers[1].id))
  local worker_state = child.lua(string.format([[
    local w = M._workers()[1]
    return { win_id = w.win_id }
  ]]))
  eq(nil, worker_state.win_id)
end

T["terminals.toggle_worker()"]["no duplicate status windows after toggle cycle"] = function()
  child.lua([[M.toggle()]])
  child.lua([[M.rename("dev")]])
  child.lua([[M.as_worker()]])
  child.lua(string.format("M.toggle_worker(%d)", 1))
  child.lua(string.format("M.toggle_worker(%d)", 1))
  child.lua(string.format("M.toggle_worker(%d)", 1))
  local ws = child.lua("return M._worker_state(1)")
  eq(true, ws.status_win_id ~= nil)
  eq(true, ws.status_buf_id ~= nil)
end

T["terminals.toggle_worker()"]["esc keymap exists on worker"] = function()
  child.lua([[M.toggle()]])
  child.lua([[M.rename("dev")]])
  child.lua([[M.as_worker()]])
  child.lua(string.format("M.toggle_worker(%d)", 1))
  local has_keymap = child.lua([[
    local buf_id = M._workers()[1].buf_id
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf_id, 't')) do
      if m.lhs == '<Esc>' then return true end
    end
    return false
  ]])
  eq(true, has_keymap)
end

T["terminals.toggle_worker()"]["worker status shows name and mode"] = function()
  child.lua([[M.toggle()]])
  child.lua([[M.rename("dev")]])
  child.lua([[M.as_worker()]])
  child.lua(string.format("M.toggle_worker(%d)", 1))
  local text = child.lua("return M._get_worker_status_text(1)")
  eq(" dev  T ", text)
end

T["terminals.pickers()"] = new_set()

T["terminals.pickers()"]["returns early with no workers"] = function()
  child.lua([[M.pickers()]])
  local workers = child.lua("return M._workers()")
  eq(0, #workers)
end

T["terminals.pickers()"]["picker can be invoked with workers"] = function()
  child.lua([[M.toggle()]])
  child.lua([[M.rename("dev")]])
  child.lua([[M.as_worker()]])
  child.lua([[M.pickers()]])
  local workers = child.lua("return M._workers()")
  eq(1, #workers)
end

T["terminals.pickers()"]["picker function exists"] = function()
  local exists = child.lua("return type(M.pickers) == 'function'")
  eq(true, exists)
end

return T
