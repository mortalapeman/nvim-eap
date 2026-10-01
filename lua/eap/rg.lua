local M = {}

function M.search(opts)
  local pattern = opts.args
  local quote = pattern:sub(1, 1)
  if (quote == '"' or quote == "'") and pattern:sub(-1) == quote then
    pattern = pattern:sub(2, -2)
  end

  if pattern == "" then
    vim.notify("Rg requires a search pattern", vim.log.levels.ERROR)
    return
  end

  local result = vim.system({ "rg", "--vimgrep", "--fixed-strings", "--", pattern }, { text = true }):wait()
  local lines = vim.split(result.stdout or "", "\n", { trimempty = true })
  local items = vim.fn.getqflist({ efm = "%f:%l:%c:%m", lines = lines }).items

  vim.fn.setloclist(0, {}, " ", {
    items = items,
    title = "Rg " .. pattern,
  })

  if result.code > 1 then
    vim.notify(vim.trim(result.stderr or "rg failed"), vim.log.levels.ERROR)
  elseif #items == 0 then
    vim.notify("No matches for " .. pattern, vim.log.levels.INFO)
  else
    vim.cmd.lopen()
  end
end

function M.next()
  vim.cmd.lnext()
end

function M.previous()
  vim.cmd.lprevious()
end

function M.toggle()
  local info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
  if info and info.loclist == 1 then
    vim.cmd.lclose()
  else
    vim.cmd.lopen()
  end
end

function M.setup()
  vim.api.nvim_create_user_command("Rg", M.search, {
    nargs = "+",
    desc = "Search with ripgrep and populate the location list",
  })

  vim.keymap.set("n", "<leader>ll", M.next, { desc = "Go to next location list item" })
  vim.keymap.set("n", "<leader>lh", M.previous, { desc = "Go to previous location list item" })
  vim.keymap.set("n", "<leader>lt", M.toggle, { desc = "Toggle location list" })
end

return M
