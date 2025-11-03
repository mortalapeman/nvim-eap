local M = {}

local scratch_buffer_name = "LuaDebugScratch"

local function scratch_buffer()
  local buf_num = vim.fn.bufadd(scratch_buffer_name)
  local opt = vim.bo[buf_num]
  opt.bufhidden = "hide"
  opt.swapfile = false
  opt.buftype = "nofile"
  return buf_num
end

---@param text string Text to write to the scratch buffer
local function write_to_buffer(text)
  local buf_num = scratch_buffer()
  local lines = vim.fn.split(text, "\r\n\\|\n")
  local index = vim.api.nvim_buf_line_count(buf_num)
  vim.api.nvim_buf_set_lines(buf_num, index, index, false, lines)
end

---@param item any And value to render to text with vim.inspect
M.print = function(item)
  write_to_buffer(">>")
  write_to_buffer(vim.inspect(item))
  local buf_num = scratch_buffer()
  local windows = vim.fn.win_findbuf(buf_num)
  if next(windows) == nil then
    vim.cmd("vsplit " .. scratch_buffer_name)
  end
end

local debug_state = {}

M.set = function(name, item)
  if debug_state[name] == nil then
    debug_state[name] = {}
  end
  local store = debug_state[name]
  table.insert(store, item)
end

M.clear = function()
  for k, _ in pairs(debug_state) do
    debug_state[k] = nil
  end
  local buf_num = scratch_buffer()
  local index = vim.api.nvim_buf_line_count(buf_num)
  vim.api.nvim_buf_set_lines(buf_num, 0, index, false, {})
end

M.get = function(name)
  local store = debug_state[name]
  if store == nil then
    return nil
  end
  return store[#store]
end

return M
