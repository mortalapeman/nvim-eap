local M = {}

--- Packs the inputs to the function into a table
---@param ... any
---@return table
function M.pack(...)
  local t = { ... }
  return t
end

function M.table_find_key(tbl, value)
  for k, v in pairs(tbl) do
    if value == v then
      return k, nil
    end
  end
  return nil, "Key not found"
end

--- Closes all other buffers that are not the currently open buffer.
function M.wipe_other_buffers()
  local current_buf_num = vim.api.nvim_get_current_buf()
  local buffer_list = vim.api.nvim_list_bufs()
  local current_key = M.table_find_key(buffer_list, current_buf_num)
  table.remove(buffer_list, current_key)

  for _, v in pairs(buffer_list) do
    local is_loaded = vim.fn.bufloaded(v)
    if is_loaded then
      vim.cmd(string.format("bwipe %s", v))
    end
  end
end

--- Creates a buffer named Scratch using neovim's builtin scratch
--- buffer settings.
function M.scratch_buffer()
  local bufs = vim.api.nvim_list_bufs()
  for _, buf in ipairs(bufs) do
    local name = vim.api.nvim_buf_get_name(buf)
    -- check only the file name as buf_get_name returns the full name of the file
    if vim.fn.fnamemodify(name, ":t") == "Scratch" then
      vim.api.nvim_win_set_buf(0, buf)
      return buf
    end
  end
  local buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_name(buf, "Scratch")
  vim.api.nvim_win_set_buf(0, buf)
  return buf
end

return M
