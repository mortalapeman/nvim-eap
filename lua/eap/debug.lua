local M = {}

local scratch_buffer_name = "LuaDebugScratch"

local function scratch_buffer()
  local buf_nums = vim.api.nvim_list_bufs() or {}
  local scratch_buf_num = nil
  for _, buf_num in pairs(buf_nums) do
    local name = vim.api.nvim_buf_get_name(buf_num)
    if string.find(scratch_buffer_name, name) ~= nil then
      scratch_buf_num = buf_num
      break
    end
  end
  if scratch_buf_num == nil then
    scratch_buf_num = scratch_buf_num or vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("bufhidden", "hide", { buf = scratch_buf_num })
    vim.api.nvim_buf_set_name(scratch_buf_num, scratch_buffer_name)
    return scratch_buf_num
  end

  return scratch_buf_num
end

---@param text string Text to write to the scratch buffer
local function write_to_buffer(text)
  local buf_num = scratch_buffer()
  local lines = vim.fn.split(text, "\r\n\\|\n")
  local index = vim.api.nvim_buf_line_count(buf_num)
  vim.api.nvim_buf_set_lines(buf_num, index, index, false, lines)
end

---@param item any And value to render to text with vim.inspect
function M.print(item)
  write_to_buffer(">>")
  write_to_buffer(vim.inspect(item))
  local buf_num = scratch_buffer()
  local windows = vim.fn.win_findbuf(buf_num)
  if next(windows) == nil then
    vim.cmd("vsplit " .. scratch_buffer_name)
  end
end

local debug_state = {}

function M.set(name, item)
  if debug_state[name] == nil then
    debug_state[name] = {}
  end
  local store = debug_state[name]
  table.insert(store, item)
end

function M.clear()
  for k, _ in pairs(debug_state) do
    debug_state[k] = nil
  end
  local buf_num = scratch_buffer()
  local index = vim.api.nvim_buf_line_count(buf_num)
  vim.api.nvim_buf_set_lines(buf_num, 0, index, false, {})
end

function M.get(name)
  local store = debug_state[name]
  if store == nil then
    return nil
  end
  return store[#store]
end

return M
