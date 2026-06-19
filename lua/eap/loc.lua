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
    local match = string.match(l, "%S+:%d+:%d+")
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

function M.open_locs_telescope()
  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    vim.notify("telescope.nvim is required for the code bookmark picker", vim.log.levels.ERROR)
    return
  end

  local finders = require("telescope.finders")
  local sorters = require("telescope.sorters")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")

  local locs = M.find_locs()
  if vim.tbl_isempty(locs) then
    vim.notify("No code bookmarks found in current buffer", vim.log.levels.INFO)
    return
  end

  local function parse_loc(loc)
    local parts = vim.fn.split(loc, ":")
    local path = parts[1]
    local line = tonumber(parts[2]) or 1
    local col = tonumber(parts[3]) or 0
    return path, line, col
  end

  local loc_previewer = previewers.new_buffer_previewer({
    title = "Bookmark Preview",
    define_preview = function(self, entry, status)
      local path, line, col = parse_loc(entry.value)
      local full_path = vim.fn.fnamemodify(path, ":p")
      local lines = vim.fn.readfile(full_path)
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      local ft = vim.filetype.match({ filename = full_path }) or ""
      vim.api.nvim_set_option_value("filetype", ft, { buf = self.state.bufnr })
      vim.schedule(function()
        vim.api.nvim_win_set_cursor(self.state.winid, { line, col })
        vim.api.nvim_set_option_value("cursorline", true, { win = self.state.winid })
      end)
    end,
  })

  pickers
    .new({}, {
      prompt_title = "Code Bookmarks",
      finder = finders.new_table({
        results = locs,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry,
            ordinal = entry,
          }
        end,
      }),
      sorter = sorters.get_generic_fuzzy_sorter(),
      previewer = loc_previewer,
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          local path, line, col = parse_loc(selection.value)
          vim.cmd("edit " .. vim.fn.fnameescape(path))
          vim.api.nvim_win_set_cursor(0, { line, col })
        end)
        return true
      end,
    })
    :find()
end

vim.keymap.set(
  "n",
  "<leader>bl",
  M.open_locs_telescope,
  { noremap = true, silent = true, desc = "Open code bookmark picker" }
)

-- debug.print(M.find_locs())

return M
