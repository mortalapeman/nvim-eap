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
---@type string
local _name = ""

---@class WorkerTerminal
---@field buf_id integer
---@field win_id integer|nil
---@field extmark_id integer|nil
---@field augroup integer|nil
---@field name string
---@type table<integer, WorkerTerminal>
local _workers = {}
local _worker_counter = 0

local function setup_highlights()
  vim.api.nvim_set_hl(0, "EapTermNormal", { bg = "#5e81ac", fg = "#eceff4", bold = true })
  vim.api.nvim_set_hl(0, "EapTermTerminal", { bg = "#a3be8c", fg = "#eceff4", bold = true })
  vim.api.nvim_set_hl(0, "EapTermName", { bg = "#3b4252", fg = "#d8dee9", bold = true })
end

---@param buf_id integer
---@param extmark_id integer|nil
---@param name string
---@param mode string
local function render_extmark(buf_id, extmark_id, name, mode)
  if not buf_id or not vim.api.nvim_buf_is_valid(buf_id) then
    return extmark_id
  end
  local mode_text = mode == "t" and " T " or " N "
  local mode_hl = mode == "t" and "EapTermTerminal" or "EapTermNormal"
  local virt_text = { { mode_text, mode_hl } }
  if name ~= "" then
    table.insert(virt_text, { " " .. name .. " ", "EapTermName" })
  end
  local line_count = vim.api.nvim_buf_line_count(buf_id)
  local line = line_count - 1
  if extmark_id then
    local ok = pcall(vim.api.nvim_buf_set_extmark, buf_id, ns_id, line, 0, {
      id = extmark_id,
      virt_text = virt_text,
      virt_text_pos = "eol",
    })
    if not ok then
      extmark_id = nil
    end
  end
  if not extmark_id then
    extmark_id = vim.api.nvim_buf_set_extmark(buf_id, ns_id, line, 0, {
      virt_text = virt_text,
      virt_text_pos = "eol",
    })
  end
  return extmark_id
end

---@param mode string
local function update_mode_extmark(mode)
  _extmark_id = render_extmark(_buf_id, _extmark_id, _name, mode)
end

---@param worker WorkerTerminal
---@param mode string
local function update_worker_extmark(worker, mode)
  worker.extmark_id = render_extmark(worker.buf_id, worker.extmark_id, worker.name, mode)
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
        update_worker_extmark(worker, "t")
      end)
    end,
  })
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = worker.augroup,
    pattern = "[tT]*:n*",
    callback = function()
      vim.schedule(function()
        update_worker_extmark(worker, "n")
      end)
    end,
  })
  update_worker_extmark(worker, "t")
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
  if _win_id and vim.api.nvim_win_is_valid(_win_id) then
    vim.api.nvim_win_close(_win_id, true)
  end
  if _buf_id and vim.api.nvim_buf_is_valid(_buf_id) then
    vim.api.nvim_buf_clear_namespace(_buf_id, ns_id, 0, -1)
  end
  _win_id = nil
  _extmark_id = nil
end

local function close()
  close_window()
  _buf_id = nil
end

---@param worker WorkerTerminal
local function close_worker_window(worker)
  stop_worker_mode_tracking(worker)
  if worker.win_id and vim.api.nvim_win_is_valid(worker.win_id) then
    vim.api.nvim_win_close(worker.win_id, true)
  end
  if worker.buf_id and vim.api.nvim_buf_is_valid(worker.buf_id) then
    vim.api.nvim_buf_clear_namespace(worker.buf_id, ns_id, 0, -1)
  end
  worker.win_id = nil
  worker.extmark_id = nil
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

function M.as_worker()
  if not is_open() then
    vim.notify("No terminal is open", vim.log.levels.WARN)
    return
  end

  if _name == "" then
    vim.notify("Terminal must have a name before becoming a worker", vim.log.levels.WARN)
    return
  end

  if find_worker_by_name(_name) then
    vim.notify("A worker named '" .. _name .. "' already exists", vim.log.levels.WARN)
    return
  end

  local worker = {
    buf_id = _buf_id,
    win_id = nil,
    extmark_id = nil,
    augroup = nil,
    name = _name,
  }

  stop_mode_tracking()
  if _win_id and vim.api.nvim_win_is_valid(_win_id) then
    vim.api.nvim_win_close(_win_id, true)
  end
  if _buf_id and vim.api.nvim_buf_is_valid(_buf_id) then
    vim.api.nvim_buf_clear_namespace(_buf_id, ns_id, 0, -1)
  end
  _win_id = nil
  _extmark_id = nil

  _worker_counter = _worker_counter + 1
  _workers[_worker_counter] = worker

  _buf_id = nil
  _name = ""

  vim.notify("Terminal '" .. worker.name .. "' moved to worker", vim.log.levels.INFO)
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
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
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

  start_worker_mode_tracking(worker)
  vim.cmd("startinsert")
end

function M._state()
  return { win_id = _win_id, buf_id = _buf_id, extmark_id = _extmark_id, name = _name }
end

function M._workers()
  local result = {}
  for id, worker in pairs(_workers) do
    table.insert(result, { id = id, name = worker.name, buf_id = worker.buf_id, win_id = worker.win_id })
  end
  return result
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
  local parts = {}
  for _, segment in ipairs(result[3].virt_text) do
    table.insert(parts, segment[1])
  end
  return table.concat(parts)
end

function M.rename(name)
  _name = name or ""
  if is_open() then
    local mode = vim.fn.mode() == "t" and "t" or "n"
    update_mode_extmark(mode)
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
