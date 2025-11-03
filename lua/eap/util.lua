local M = {}

M.table_find_key = function(tbl, value)
  for k, v in pairs(tbl) do
    if value == v then
      return k, nil
    end
  end
  return nil, "Key not found"
end

M.wipe_other_buffers = function()
  local current_buf_num = vim.fn.bufadd(vim.fn.expand("%"))
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

return M
