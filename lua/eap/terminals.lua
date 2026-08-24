local M = {}

local ns_id = vim.api.nvim_create_namespace("eap.terminals")

---@type integer|nil
local _win_id = nil
---@type integer|nil
local _buf_id = nil
---@type integer|nil
local _augroup = nil
---@type integer|nil
local _extmark_id = nil

local function setup_highlights()
  vim.api.nvim_set_hl(0, "EapTermNormal", { bg = "#5e81ac", fg = "#eceff4", bold = true })
  vim.api.nvim_set_hl(0, "EapTermTerminal", { bg = "#a3be8c", fg = "#eceff4", bold = true })
end

---@param mode string
local function update_mode_extmark(mode)
  if not _buf_id or not vim.api.nvim_buf_is_valid(_buf_id) then
    return
  end
  local text = mode == "t" and " T " or " N "
  local hl = mode == "t" and "EapTermTerminal" or "EapTermNormal"
  local line_count = vim.api.nvim_buf_line_count(_buf_id)
  local line = line_count - 1
  if _extmark_id then
    local ok = pcall(vim.api.nvim_buf_set_extmark, _buf_id, ns_id, line, 0, {
      id = _extmark_id,
      virt_text = { { text, hl } },
      virt_text_pos = "eol",
    })
    if not ok then
      _extmark_id = nil
    end
  end
  if not _extmark_id then
    _extmark_id = vim.api.nvim_buf_set_extmark(_buf_id, ns_id, line, 0, {
      virt_text = { { text, hl } },
      virt_text_pos = "eol",
    })
  end
end

local function start_mode_tracking()
  if _augroup then
    vim.api.nvim_del_augroup_by_id(_augroup)
  end
  _augroup = vim.api.nvim_create_augroup("eap_term_mode", { clear = true })
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = _augroup,
    pattern = "*:[tT]",
    callback = function()
      vim.schedule(function()
        update_mode_extmark("t")
      end)
    end,
  })
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = _augroup,
    pattern = "[tT]*:n*",
    callback = function()
      vim.schedule(function()
        update_mode_extmark("n")
      end)
    end,
  })
  update_mode_extmark("t")
end

local function stop_mode_tracking()
  if _augroup then
    vim.api.nvim_del_augroup_by_id(_augroup)
    _augroup = nil
  end
end

local function is_open()
  if _win_id and vim.api.nvim_win_is_valid(_win_id) then
    return true
  end
  return false
end

local function close_window()
  stop_mode_tracking()
  if _win_id and vim.api.nvim_win_is_valid(_win_id) then
    vim.api.nvim_win_close(_win_id, true)
  end
  _win_id = nil
  _extmark_id = nil
end

local function close()
  close_window()
  _buf_id = nil
end

function M.toggle()
  if is_open() then
    close_window()
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
    start_mode_tracking()
    vim.cmd("startinsert")
    return
  end

  _buf_id = vim.api.nvim_create_buf(false, true)
  _extmark_id = nil
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
        close_window()
      end)
    end,
  })

  vim.keymap.set("t", "<Esc>", function()
    close_window()
    vim.cmd("stopinsert")
  end, { buffer = _buf_id, silent = true })

  start_mode_tracking()
  vim.cmd("startinsert")
end

function M._state()
  return { win_id = _win_id, buf_id = _buf_id, extmark_id = _extmark_id }
end

function M._get_extmark_text()
  if not _buf_id or not vim.api.nvim_buf_is_valid(_buf_id) or not _extmark_id then
    return nil
  end
  local cur_ns = vim.api.nvim_create_namespace("eap.terminals")
  local ok, result = pcall(vim.api.nvim_buf_get_extmark_by_id, _buf_id, cur_ns, _extmark_id, { details = true })
  if not ok or not result or not result[3] or not result[3].virt_text then
    return nil
  end
  return result[3].virt_text[1][1]
end

function M.setup()
  setup_highlights()
  vim.keymap.set("n", "<leader>lc", M.toggle, { desc = "Toggle floating terminal" })
end

return M
