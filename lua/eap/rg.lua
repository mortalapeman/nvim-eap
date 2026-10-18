local M = {}

local function navigate_from_loclist()
  local info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
  if not info or info.loclist ~= 1 then
    return
  end

  local source_win = vim.b.eap_rg_source_win
  if not source_win or not vim.api.nvim_win_is_valid(source_win) then
    return
  end

  local item = vim.fn.getloclist(0)[vim.fn.line(".")]
  if not item or item.valid ~= 1 or not vim.api.nvim_buf_is_valid(item.bufnr) then
    return
  end

  if vim.bo[item.bufnr].filetype == "" then
    local filetype = vim.filetype.match({ filename = vim.api.nvim_buf_get_name(item.bufnr) })
    if filetype then
      vim.bo[item.bufnr].filetype = filetype
    end
  end

  vim.api.nvim_win_set_buf(source_win, item.bufnr)
  vim.api.nvim_win_set_cursor(source_win, { item.lnum, math.max(item.col - 1, 0) })
end

local dbg = require("eap.debug")

local function parse_args(args)
  local result = {}
  local index = 1

  while index <= #args do
    while index <= #args and args:sub(index, index):match("%s") do
      index = index + 1
    end
    if index > #args then
      break
    end

    local quote = args:sub(index, index)
    if quote == '"' or quote == "'" then
      index = index + 1
      local start = index
      while index <= #args and args:sub(index, index) ~= quote do
        index = index + 1
      end
      table.insert(result, args:sub(start, index - 1))
      index = index + 1
    else
      local start = index
      while index <= #args and not args:sub(index, index):match("%s") do
        index = index + 1
      end
      table.insert(result, args:sub(start, index - 1))
    end
  end

  return result
end

function M.search(opts)
  local args = parse_args(opts.args)
  local pattern = args[1] or ""

  if pattern == "" then
    vim.notify("Rg requires a search pattern", vim.log.levels.ERROR)
    return
  end

  local command = { "rg", "--vimgrep", "--fixed-strings" }
  for i = 2, #args do
    local extension = args[i]:gsub("^%.", "")
    if extension ~= "" then
      table.insert(command, "--glob")
      table.insert(command, "*." .. extension)
    end
  end
  table.insert(command, "--")
  table.insert(command, pattern)

  local result = vim.system(command, { text = true }):wait()
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
    local source_win = vim.api.nvim_get_current_win()
    vim.cmd.lopen()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local info = vim.fn.getwininfo(win)[1]
      if info and info.loclist == 1 then
        vim.api.nvim_buf_set_var(vim.api.nvim_win_get_buf(win), "eap_rg_source_win", source_win)
        break
      end
    end
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
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "qf",
    callback = function(args)
      vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = args.buf,
        callback = navigate_from_loclist,
      })
    end,
  })

  vim.api.nvim_create_user_command("Rg", M.search, {
    nargs = "+",
    desc = "Search with ripgrep and populate the location list (pattern [extensions...])",
  })

  vim.keymap.set("n", "<leader>ll", M.next, { desc = "Go to next location list item" })
  vim.keymap.set("n", "<leader>lh", M.previous, { desc = "Go to previous location list item" })
  vim.keymap.set("n", "<leader>lt", M.toggle, { desc = "Toggle location list" })
end

return M
