local M = {}

function M.yank_current_line_as_loc()
  local bufname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":~")
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local loc = vim.fn.join({ bufname, row, col }, ":")
  vim.fn.setreg("@", loc)
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

function M.go_to_file_loc()
  local loc = vim.fn.expand("<cWORD>")
  local _, line, col = unpack(vim.fn.split(loc, ":"))
  vim.cmd([[normal! gf]])
  if line ~= nil and col ~= nil then
    vim.api.nvim_win_set_cursor(0, { tonumber(line), tonumber(col) })
  end
end

-- local function run(opts)
--   local pickers = require("telescope.pickers")
--   local finders = require("telescope.finders")
--   local sorters = require("telescope.sorters")
--   local actions = require("telescope.actions")
--   local action_state = require("telescope.actions.state")
--   opts = opts or {}
--   pickers
--     .new(opts, {
--       prompt_title = "colors",
--       finder = finders.new_table({
--         results = { "A", "B", "C" },
--       }),
--       sorter = sorters.get_generic_fuzzy_sorter(opts),
--       attach_mappings = function(prompt_bufnr, map)
--         actions.select_default:replace(function()
--           actions.close(prompt_bufnr)
--           local selection = action_state.get_selected_entry()
--           vim.api.nvim_put({ selection[1] }, "", false, true)
--         end)
--         return true
--       end,
--     })
--     :find()
-- end
--
-- run()

-- asdf/ere:1:2
-- debug.print(M.find_locs())

return M
