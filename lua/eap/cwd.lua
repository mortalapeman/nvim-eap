local M = {}

local cwd_stack = {}

function M.cwd_to_file_dir()
  local cwd = vim.fn.getcwd()
  local filename = vim.api.nvim_buf_get_name(0)
  if filename then
    local dir_path = vim.fn.fnamemodify(filename, ":h")
    table.insert(cwd_stack, cwd)
    vim.cmd("cd " .. dir_path)
    vim.notify("Changed CWD to: " .. dir_path, vim.log.levels.INFO)
  else
    vim.notify("Could not determine current file path.", vim.log.levels.ERROR)
  end
end

function M.cwd_back()
  if #cwd_stack > 0 then
    local previous_dir = table.remove(cwd_stack, #cwd_stack)
    vim.cmd("cd " .. previous_dir)
    vim.notify("Changed CWD back to: " .. previous_dir, vim.log.levels.INFO)
  else
    vim.notify("CWD stack is empty.", vim.log.levels.WARN)
  end
end

return M
