local debug = require("eap.debug")

local M = {}

function M.yank_current_line_as_loc()
  local bufname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":~")
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local loc = vim.fn.join({ bufname, row, col }, ":")
  vim.fn.setreg("", loc)
end

function M.find_locs()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local matches = {}
  for _, l in ipairs(lines) do
    local match = string.match(l, "[%w/][%s%w/]+:%d+:%d+")
    if match then
      table.insert(matches, match)
    end
  end

  return matches
end

-- asdf/ere:1:2
-- debug.print(M.find_locs())

return M
