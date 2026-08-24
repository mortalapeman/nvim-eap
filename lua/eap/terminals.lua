local M = {}

---@type integer|nil
local _win_id = nil
---@type integer|nil
local _buf_id = nil

local function is_open()
  if _win_id and vim.api.nvim_win_is_valid(_win_id) then
    return true
  end
  return false
end

local function close()
  if _win_id and vim.api.nvim_win_is_valid(_win_id) then
    vim.api.nvim_win_close(_win_id, true)
  end
  _win_id = nil
  _buf_id = nil
end

function M.toggle()
  if is_open() then
    close()
    return
  end

  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  if _buf_id and vim.api.nvim_buf_is_valid(_buf_id) then
    _win_id = vim.api.nvim_open_win(_buf_id, true, {
      relative = "editor",
      width = width,
      height = height,
      row = row,
      col = col,
      style = "minimal",
      border = "rounded",
      title = " Terminal ",
      title_pos = "center",
    })
    vim.cmd("startinsert")
    return
  end

  _buf_id = vim.api.nvim_create_buf(false, true)
  _win_id = vim.api.nvim_open_win(_buf_id, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Terminal ",
    title_pos = "center",
  })

  vim.fn.jobstart(vim.o.shell, {
    term = true,
    on_exit = function()
      vim.schedule(function()
        close()
      end)
    end,
  })

  vim.keymap.set("t", "<Esc>", function()
    close()
    vim.cmd("stopinsert")
  end, { buffer = _buf_id, silent = true })

  vim.cmd("startinsert")
end

function M.setup()
  vim.keymap.set("n", "<leader>lc", M.toggle, { desc = "Toggle floating terminal" })
end

return M
