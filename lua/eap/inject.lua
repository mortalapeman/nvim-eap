local M = {}

M.vim_fn_system = vim.fn.system
M.vim_uv_fs_stat = vim.uv.fs_stat

function M.vim_v_shell_error()
  return vim.v.shell_error
end

return M
