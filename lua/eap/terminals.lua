local M = {}

local ns_id = vim.api.nvim_create_namespace("eap.terminals")

---@type integer|nil
local _win_id = nil
---@type integer|nil
local _buf_id = nil
---@type integer|nil
local _augroup = nil
---@type integer|nil
local _status_win = nil
---@type integer|nil
local _status_buf = nil
---@type string
local _name = ""
---@type integer|nil
local _active_worker_id = nil

---@class WorkerTerminal
---@field buf_id integer
---@field win_id integer|nil
---@field status_win_id integer|nil
---@field status_buf_id integer|nil
---@field augroup integer|nil
---@field name string
---@type table<integer, WorkerTerminal>
local _workers = {}
local _worker_counter = 0

local function setup_highlights()
  vim.api.nvim_set_hl(0, "EapTermNormal", { bg = "#5e81ac", fg = "#eceff4", bold = true })
  vim.api.nvim_set_hl(0, "EapTermTerminal", { bg = "#a3be8c", fg = "#eceff4", bold = true })
  vim.api.nvim_set_hl(0, "EapTermName", { bg = "#3b4252", fg = "#d8dee9", bold = true })
  vim.api.nvim_set_hl(0, "EapTermStatus", { bg = "#3b4252", fg = "#d8dee9" })
end

---@param status_buf integer
---@param name string
---@param mode string
local function render_status(status_buf, name, mode)
  if not status_buf or not vim.api.nvim_buf_is_valid(status_buf) then
    return
  end
  local mode_text = mode == "t" and " T " or " N "
  local mode_hl = mode == "t" and "EapTermTerminal" or "EapTermNormal"
  local virt_text = {}
  table.insert(virt_text, { mode_text, mode_hl })
  if name ~= "" then
    table.insert(virt_text, { " " .. name .. " ", "EapTermName" })
  end
  vim.api.nvim_buf_set_lines(status_buf, 0, -1, false, { "" })
  vim.api.nvim_buf_clear_namespace(status_buf, ns_id, 0, -1)
  vim.api.nvim_buf_set_extmark(status_buf, ns_id, 0, 0, {
    virt_text = virt_text,
    virt_text_pos = "eol",
  })
end

---@param win_id integer
---@return integer|nil status_win_id, integer|nil status_buf_id
local function create_status_bar(win_id)
  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    return nil, nil
  end
  local config = vim.api.nvim_win_get_config(win_id)
  local row = config.row + config.height + 1
  local col = config.col

  local status_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[status_buf].buftype = "nofile"
  vim.bo[status_buf].bufhidden = "wipe"
  vim.bo[status_buf].swapfile = false

  local status_win = vim.api.nvim_open_win(status_buf, false, {
    relative = "editor",
    width = config.width,
    height = 1,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    focusable = false,
    zindex = 50,
  })

  return status_win, status_buf
end

---@param status_win integer|nil
local function close_status_bar(status_win)
  if status_win and vim.api.nvim_win_is_valid(status_win) then
    vim.api.nvim_win_close(status_win, true)
  end
end

---@param mode string
local function update_mode_status(mode)
  if _status_buf then
    render_status(_status_buf, _name, mode)
  end
end

---@param worker WorkerTerminal
---@param mode string
local function update_worker_status(worker, mode)
  render_status(worker.status_buf_id, worker.name, mode)
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
        update_mode_status("t")
      end)
    end,
  })
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = _augroup,
    pattern = "[tT]*:n*",
    callback = function()
      vim.schedule(function()
        update_mode_status("n")
      end)
    end,
  })
  update_mode_status("t")
end

local function stop_mode_tracking()
  if _augroup then
    vim.api.nvim_del_augroup_by_id(_augroup)
    _augroup = nil
  end
end

---@param worker WorkerTerminal
local function start_worker_mode_tracking(worker)
  if worker.augroup then
    vim.api.nvim_del_augroup_by_id(worker.augroup)
  end
  worker.augroup = vim.api.nvim_create_augroup("eap_term_worker_" .. worker.name, { clear = true })
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = worker.augroup,
    pattern = "*:[tT]",
    callback = function()
      vim.schedule(function()
        update_worker_status(worker, "t")
      end)
    end,
  })
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = worker.augroup,
    pattern = "[tT]*:n*",
    callback = function()
      vim.schedule(function()
        update_worker_status(worker, "n")
      end)
    end,
  })
  update_worker_status(worker, "t")
end

---@param worker WorkerTerminal
local function stop_worker_mode_tracking(worker)
  if worker.augroup then
    vim.api.nvim_del_augroup_by_id(worker.augroup)
    worker.augroup = nil
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
  close_status_bar(_status_win)
  if _win_id and vim.api.nvim_win_is_valid(_win_id) then
    vim.api.nvim_win_close(_win_id, true)
  end
  _win_id = nil
  _status_win = nil
  _status_buf = nil
end

---@param worker WorkerTerminal
local function close_worker_window(worker)
  stop_worker_mode_tracking(worker)
  close_status_bar(worker.status_win_id)
  if worker.win_id and vim.api.nvim_win_is_valid(worker.win_id) then
    vim.api.nvim_win_close(worker.win_id, true)
  end
  worker.win_id = nil
  worker.status_win_id = nil
  worker.status_buf_id = nil
  if _active_worker_id then
    _active_worker_id = nil
    _name = ""
    _status_win = nil
    _status_buf = nil
  end
end

---@return WorkerTerminal|nil
local function find_worker_by_name(name)
  for _, worker in pairs(_workers) do
    if worker.name == name then
      return worker
    end
  end
  return nil
end

function M.toggle()
  if is_open() then
    close_window()
    return
  end

  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8) - 1
  local row = math.floor((vim.o.lines - height - 1) / 2)
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
    _status_win, _status_buf = create_status_bar(_win_id)
    start_mode_tracking()
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

  _status_win, _status_buf = create_status_bar(_win_id)

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
  vim.schedule(function()
    local mode = vim.fn.mode() == "t" and "t" or "n"
    update_mode_status(mode)
  end)
end

local function do_as_worker()
  if find_worker_by_name(_name) then
    vim.notify("A worker named '" .. _name .. "' already exists", vim.log.levels.WARN)
    return
  end

  local worker = {
    buf_id = _buf_id,
    win_id = nil,
    status_win_id = nil,
    status_buf_id = nil,
    augroup = nil,
    name = _name,
  }

  stop_mode_tracking()
  close_status_bar(_status_win)
  if _win_id and vim.api.nvim_win_is_valid(_win_id) then
    vim.api.nvim_win_close(_win_id, true)
  end
  _win_id = nil
  _status_win = nil
  _status_buf = nil

  _worker_counter = _worker_counter + 1
  _workers[_worker_counter] = worker

  _buf_id = nil
  _name = ""

  vim.notify("Terminal '" .. worker.name .. "' moved to worker", vim.log.levels.INFO)
end

function M.as_worker()
  if not is_open() then
    vim.notify("No terminal is open", vim.log.levels.WARN)
    return
  end

  if _name ~= "" then
    do_as_worker()
    return
  end

  vim.ui.input({ prompt = "Worker name: " }, function(name)
    if not name or name == "" then
      return
    end
    _name = name
    do_as_worker()
  end)
end

---@param worker_id integer
function M.toggle_worker(worker_id)
  local worker = _workers[worker_id]
  if not worker then
    return
  end

  if worker.win_id and vim.api.nvim_win_is_valid(worker.win_id) then
    close_worker_window(worker)
    return
  end

  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8) - 1
  local row = math.floor((vim.o.lines - height - 1) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  if not worker.buf_id or not vim.api.nvim_buf_is_valid(worker.buf_id) then
    worker.buf_id = vim.api.nvim_create_buf(false, true)
    vim.fn.jobstart(vim.o.shell, {
      term = true,
      on_exit = function()
        vim.schedule(function()
          close_worker_window(worker)
        end)
      end,
    })
  end

  vim.keymap.set("t", "<Esc>", function()
    close_worker_window(worker)
    vim.cmd("stopinsert")
  end, { buffer = worker.buf_id, silent = true })

  worker.win_id = vim.api.nvim_open_win(worker.buf_id, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " " .. worker.name .. " ",
    title_pos = "center",
  })

  worker.status_win_id, worker.status_buf_id = create_status_bar(worker.win_id)
  _active_worker_id = worker_id
  _name = worker.name
  _status_win = worker.status_win_id
  _status_buf = worker.status_buf_id
  start_worker_mode_tracking(worker)
  vim.cmd("startinsert")
  vim.schedule(function()
    local mode = vim.fn.mode() == "t" and "t" or "n"
    update_worker_status(worker, mode)
  end)
end

-- Used in our tests to get module local information
function M._state()
  return { win_id = _win_id, buf_id = _buf_id, name = _name, status_buf_id = _status_buf }
end

function M._workers()
  local result = {}
  for id, worker in pairs(_workers) do
    table.insert(result, { id = id, name = worker.name, buf_id = worker.buf_id, win_id = worker.win_id })
  end
  return result
end

---@param worker_id integer
---@return table|nil
function M._worker_state(worker_id)
  local worker = _workers[worker_id]
  if not worker then
    return nil
  end
  return {
    id = worker_id,
    name = worker.name,
    buf_id = worker.buf_id,
    win_id = worker.win_id,
    status_win_id = worker.status_win_id,
    status_buf_id = worker.status_buf_id,
  }
end

function M._get_status_text()
  if not _status_buf or not vim.api.nvim_buf_is_valid(_status_buf) then
    return nil
  end
  local marks = vim.api.nvim_buf_get_extmarks(_status_buf, ns_id, 0, -1, { details = true })
  if #marks == 0 or not marks[1][4] or not marks[1][4].virt_text then
    return nil
  end
  local parts = {}
  for _, segment in ipairs(marks[1][4].virt_text) do
    table.insert(parts, segment[1])
  end
  return table.concat(parts)
end

function M._get_worker_status_text(worker_id)
  local worker = _workers[worker_id]
  if not worker or not worker.status_buf_id or not vim.api.nvim_buf_is_valid(worker.status_buf_id) then
    return nil
  end
  local marks = vim.api.nvim_buf_get_extmarks(worker.status_buf_id, ns_id, 0, -1, { details = true })
  if #marks == 0 or not marks[1][4] or not marks[1][4].virt_text then
    return nil
  end
  local parts = {}
  for _, segment in ipairs(marks[1][4].virt_text) do
    table.insert(parts, segment[1])
  end
  return table.concat(parts)
end

function M.rename(name)
  _name = name or ""
  if _active_worker_id and _workers[_active_worker_id] then
    _workers[_active_worker_id].name = _name
  end
  if is_open() then
    local mode = vim.fn.mode() == "t" and "t" or "n"
    update_mode_status(mode)
  elseif _active_worker_id and _workers[_active_worker_id] then
    local mode = vim.fn.mode() == "t" and "t" or "n"
    update_worker_status(_workers[_active_worker_id], mode)
  end
end

function M.pickers()
  local ok, _ = pcall(require, "telescope.config")
  if not ok then
    vim.notify("Telescope is not installed", vim.log.levels.ERROR)
    return
  end
  local finders = require("telescope.finders")
  local pickers = require("telescope.pickers")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")
  local conf = require("telescope.config").values

  local workers = M._workers()
  if #workers == 0 then
    vim.notify("No worker terminals", vim.log.levels.INFO)
    return
  end

  local buffer_previewer = previewers.new_buffer_previewer({
    define_preview = function(self, entry)
      local worker = entry.value
      if worker.buf_id and vim.api.nvim_buf_is_valid(worker.buf_id) then
        local lines = vim.api.nvim_buf_get_lines(worker.buf_id, 0, -1, false)
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      else
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { "(empty terminal)" })
      end
    end,
  })

  pickers
    .new({}, {
      prompt_title = "Worker Terminals",
      finder = finders.new_table({
        results = workers,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry.name,
            ordinal = entry.name,
          }
        end,
      }),
      previewer = buffer_previewer,
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            M.toggle_worker(selection.value.id)
          end
        end)
        return true
      end,
    })
    :find()
end

function M.setup()
  setup_highlights()
  vim.keymap.set("n", "<leader>to", M.toggle, { desc = "Toggle floating terminal" })
  vim.keymap.set("n", "<leader>tx", M.as_worker, { desc = "Move terminal to worker" })
  vim.keymap.set("n", "<leader>tr", function()
    vim.ui.input({ prompt = "Terminal name: " }, function(name)
      if name then
        M.rename(name)
      end
    end)
  end, { desc = "Rename floating terminal" })
  vim.keymap.set("n", "<leader>st", M.pickers, { desc = "Search worker terminals" })

  vim.api.nvim_create_user_command("TerminalRename", function(opts)
    M.rename(opts.args)
  end, {
    nargs = "?",
    desc = "Rename the floating terminal",
  })

  vim.api.nvim_create_user_command("TerminalAsWorker", function()
    M.as_worker()
  end, {
    desc = "Move current terminal to a worker",
  })
end

return M
