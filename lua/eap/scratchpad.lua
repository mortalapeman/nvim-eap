local sqlite = require("eap.sqlite")
local logging = require("eap.logging")

local M = {}

local logger = logging.get_logger("eap.scratchpad")

---@type integer|nil
local _output_win = nil

---@class ScratchpadState
---@field _dbfile string
---@field _scratch_dir string
---@field _win_id integer|nil
---@field _buf_id integer|nil
local ScratchpadState = {}

---@param dbfile string
---@param scratch_dir string
---@return ScratchpadState
function ScratchpadState.new(dbfile, scratch_dir)
  local self = {
    _dbfile = dbfile,
    _scratch_dir = scratch_dir,
    _win_id = nil,
    _buf_id = nil,
  }
  setmetatable(self, { __index = ScratchpadState })
  return self
end

function ScratchpadState:init()
  if not vim.uv.fs_stat(self._scratch_dir) then
    vim.fn.mkdir(self._scratch_dir, "p")
  end
  if not vim.uv.fs_stat(self._dbfile) or not sqlite.table_exists(self._dbfile, "scratchpad") then
    local sql = [[
      create table scratchpad (
        scratchpad_id integer primary key autoincrement
        , name text
        , filename text
        , active integer default 0
      );
    ]]
    local _, error = sqlite.execute_sql(self._dbfile, sql)
    if error and error ~= "No output" then
      logger.error(error)
    end
  end
end

function ScratchpadState:reset()
  if vim.uv.fs_stat(self._dbfile) then
    vim.fn.delete(self._dbfile)
  end
end

---@param name string
---@return string
function ScratchpadState:_filepath(name)
  return vim.fs.joinpath(self._scratch_dir, name .. ".md")
end

---@param name string
function ScratchpadState:create(name)
  local sql = [[
    insert into scratchpad (name, filename, active)
    values ('%s', '%s', 0);
  ]]
  local filepath = self:_filepath(name)
  local sql_with_params = string.format(sql, name, filepath)
  local _, error = sqlite.execute_sql(self._dbfile, sql_with_params)
  if error and error ~= "No output" then
    logger.error(error)
    return
  end
  local fd = vim.fn.writefile({
    "# " .. name,
    "",
    "```lua",
    "-- cwd: " .. vim.fn.getcwd(),
    "",
    "```",
    "",
    "```python",
    "# cwd: " .. vim.fn.getcwd(),
    "",
    "```",
    "",
    "```bash",
    "# cwd: " .. vim.fn.getcwd(),
    "",
    "```",
  }, filepath)
  if fd ~= 0 then
    logger.error("Failed to create scratchpad file: " .. filepath)
  end
end

---@class Scratchpad
---@field scratchpad_id integer
---@field name string
---@field filename string
---@field active integer

---@return Scratchpad[]|nil
function ScratchpadState:all()
  local sql = "select scratchpad_id, name, filename, active from scratchpad order by name;"
  local result, error = sqlite.execute_sql(self._dbfile, sql)
  if error and error ~= "No output" then
    logger.error(error)
    return nil
  end
  return result
end

---@param name string
---@return Scratchpad|nil
function ScratchpadState:find_by_name(name)
  local result, error = sqlite.execute_sql(
    self._dbfile,
    "select scratchpad_id, name, filename, active from scratchpad where name = :name",
    { name = name }
  )
  if error and error ~= "No output" then
    logger.error(error)
    return nil
  end
  if result and #result > 0 then
    return result[1]
  end
  return nil
end

function ScratchpadState:deactivate_all()
  sqlite.execute_sql(self._dbfile, "update scratchpad set active = 0")
end

---@param scratchpad_id integer
function ScratchpadState:activate(scratchpad_id)
  self:deactivate_all()
  sqlite.execute_sql(
    self._dbfile,
    string.format("update scratchpad set active = 1 where scratchpad_id = %d", scratchpad_id)
  )
end

---@return Scratchpad|nil
function ScratchpadState:active()
  local result, error =
    sqlite.execute_sql(self._dbfile, "select scratchpad_id, name, filename, active from scratchpad where active = 1")
  if error and error ~= "No output" then
    logger.error(error)
    return nil
  end
  if result and #result > 0 then
    return result[1]
  end
  return nil
end

function ScratchpadState:show_info()
  local result, _ = sqlite.execute_sql_md(self._dbfile, "select * from scratchpad;")
  print(self._dbfile)
  print(result or "No scratchpads")
end

---@return integer|nil, integer|nil # win_id, buf_id of the scratchpad window
function ScratchpadState:is_open()
  if self._win_id and vim.api.nvim_win_is_valid(self._win_id) then
    return self._win_id, self._buf_id
  end
  return nil, nil
end

---@param filepath string
function ScratchpadState:_open_in_split(filepath)
  vim.cmd("botright split")
  vim.cmd("e " .. filepath)
  self._win_id = vim.api.nvim_get_current_win()
  self._buf_id = vim.api.nvim_get_current_buf()
  vim.bo[self._buf_id].buftype = ""
  vim.bo[self._buf_id].filetype = "markdown"
  vim.api.nvim_win_set_height(self._win_id, 15)
end

function ScratchpadState:toggle()
  local win_id, _ = self:is_open()
  if win_id then
    vim.api.nvim_win_close(win_id, false)
    self._win_id = nil
    self._buf_id = nil
    return
  end

  local active = self:active()
  if active then
    self:_open_in_split(active.filename)
    return
  end

  local pads = self:all()
  if pads == nil or #pads == 0 then
    vim.ui.input({ prompt = "New scratchpad name: " }, function(name)
      if name and #name > 0 then
        self:create(name)
        local pad = self:find_by_name(name)
        if pad then
          self:activate(pad.scratchpad_id)
          self:_open_in_split(pad.filename)
        end
      end
    end)
    return
  end

  vim.ui.select(pads, {
    prompt = "Select a scratchpad (or type new name below)",
    format_item = function(item)
      if item.active ~= 0 then
        return string.format("%s (ACTIVE)", item.name)
      end
      return item.name
    end,
  }, function(choice)
    if choice then
      self:activate(choice.scratchpad_id)
      self:_open_in_split(choice.filename)
    end
  end)
end

function ScratchpadState:select()
  local pads = self:all()
  if pads == nil or #pads == 0 then
    vim.ui.input({ prompt = "No scratchpads. Create new: " }, function(name)
      if name and #name > 0 then
        self:create(name)
        local pad = self:find_by_name(name)
        if pad then
          self:activate(pad.scratchpad_id)
          self:toggle()
        end
      end
    end)
    return
  end

  vim.ui.select(pads, {
    prompt = "Select a scratchpad",
    format_item = function(item)
      if item.active ~= 0 then
        return string.format("%s (ACTIVE)", item.name)
      end
      return item.name
    end,
  }, function(choice)
    if choice then
      self:activate(choice.scratchpad_id)
      local win_id, _ = self:is_open()
      if win_id then
        vim.api.nvim_win_set_buf(win_id, vim.fn.bufadd(choice.filename))
      else
        self:toggle()
      end
    end
  end)
end

---Parse a cwd directive from the first line of code.
---Supported formats: `-- cwd: <path>` or `# cwd: <path>`
---@param lines string[]
---@return string|nil cwd, string[] remaining_lines
local function parse_cwd_directive(lines)
  if #lines == 0 then
    return nil, lines
  end
  local first = lines[1]
  local cwd = first:match("^%-%-%s*cwd:%s*(.+)$") or first:match("^#%s*cwd:%s*(.+)$")
  if cwd then
    local remaining = {}
    for i = 2, #lines do
      table.insert(remaining, lines[i])
    end
    return cwd, remaining
  end
  return nil, lines
end

---@param lines string[]
---@param cwd string|nil
---@return string
local function execute_lua(lines, cwd)
  local code = table.concat(lines, "\n")
  local func, err = loadstring(code)
  if not func then
    return "Lua load error: " .. (err or "unknown")
  end
  local results = {}
  if cwd then
    local expanded = vim.fn.fnamemodify(cwd, ":p")
    local prev_cwd = vim.fn.getcwd()
    vim.fn.chdir(expanded)
    local ok, chunks = pcall(func)
    vim.fn.chdir(prev_cwd)
    if not ok then
      return "Lua error: " .. tostring(chunks)
    end
    for _, v in ipairs(chunks or {}) do
      table.insert(results, tostring(v))
    end
  else
    local chunks = { func() }
    for _, v in ipairs(chunks) do
      table.insert(results, tostring(v))
    end
  end
  if #results == 0 then
    return "(no output)"
  end
  return table.concat(results, "\n")
end

---@param lines string[]
---@param cwd string|nil
---@return string
local function execute_python(lines, cwd)
  local code = table.concat(lines, "\n")
  local tmpfile = vim.fn.tempname() .. ".py"
  vim.fn.writefile(vim.split(code, "\n"), tmpfile)
  local cmd = "python3 " .. tmpfile
  local output
  if cwd then
    local expanded = vim.fn.fnamemodify(cwd, ":p")
    output = vim.fn.system("cd " .. vim.fn.shellescape(expanded) .. " && " .. cmd)
  else
    output = vim.fn.system(cmd)
  end
  vim.fn.delete(tmpfile)
  if vim.v.shell_error ~= 0 then
    return "Python error:\n" .. output
  end
  if output == "" then
    return "(no output)"
  end
  return output
end

---@param lines string[]
---@param cwd string|nil
---@return string
local function execute_bash(lines, cwd)
  local code = table.concat(lines, "\n")
  local tmpfile = vim.fn.tempname() .. ".sh"
  vim.fn.writefile(vim.split(code, "\n"), tmpfile)
  local cmd = "bash " .. tmpfile
  local output
  if cwd then
    local expanded = vim.fn.fnamemodify(cwd, ":p")
    output = vim.fn.system("cd " .. vim.fn.shellescape(expanded) .. " && " .. cmd)
  else
    output = vim.fn.system(cmd)
  end
  vim.fn.delete(tmpfile)
  if vim.v.shell_error ~= 0 then
    return "Bash error:\n" .. output
  end
  if output == "" then
    return "(no output)"
  end
  return output
end

---@param lang string
---@param lines string[]
---@param cwd string|nil
---@return string
local function run_code(lang, lines, cwd)
  local executors = {
    lua = execute_lua,
    python = execute_python,
    sh = execute_bash,
    bash = execute_bash,
  }
  local executor = executors[lang]
  if not executor then
    return "Unsupported language: " .. lang .. "\nSupported: lua, python, sh/bash"
  end
  return executor(lines, cwd)
end

---@param content string
---@return integer, integer, integer, integer, string # start_line, end_line, lang, code_lines
local function find_code_block_at_cursor(lines, cursor_line)
  local fence_start = nil
  local fence_lang = nil
  for i = cursor_line, 1, -1 do
    local lang = lines[i]:match("^```(%w+)$")
    if lang then
      fence_start = i
      fence_lang = lang
      break
    end
  end
  if not fence_start then
    return nil, nil, nil, nil, nil
  end
  for i = fence_start + 1, #lines do
    if lines[i]:match("^```$") then
      local code_lines = {}
      for j = fence_start + 1, i - 1 do
        table.insert(code_lines, lines[j])
      end
      return fence_start, i, fence_lang, code_lines
    end
  end
  return nil, nil, nil, nil, nil
end

---@param result string
local function show_output(result)
  local lines = vim.split(result, "\n")
  local width = 0
  for _, line in ipairs(lines) do
    if #line > width then
      width = #line
    end
  end
  width = math.min(math.max(width + 4, 40), math.floor(vim.o.columns * 0.8))
  local height = math.min(math.max(#lines, 5), math.floor(vim.o.lines * 0.6))
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  if _output_win and vim.api.nvim_win_is_valid(_output_win) then
    local win_buf = vim.api.nvim_win_get_buf(_output_win)
    vim.api.nvim_buf_set_lines(win_buf, 0, -1, false, lines)
    vim.api.nvim_win_set_config(_output_win, {
      relative = "editor",
      width = width,
      height = height,
      row = row,
      col = col,
    })
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Output ",
    title_pos = "center",
  })
  local function close_win()
    _output_win = nil
    vim.api.nvim_clear_autocmds({ group = "eap_scratchpad_output" })
    pcall(vim.keymap.del, "n", "q")
    pcall(vim.keymap.del, "n", "<Esc>")
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  vim.keymap.set("n", "q", close_win, { silent = true, buffer = buf })
  vim.keymap.set("n", "<Esc>", close_win, { silent = true })
  local augroup = vim.api.nvim_create_augroup("eap_scratchpad_output", { clear = true })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    pattern = tostring(win),
    callback = close_win,
  })
  _output_win = win
end

function ScratchpadState:execute_at_cursor()
  local win_id, buf_id = self:is_open()
  if not win_id then
    vim.notify("No scratchpad is open", vim.log.levels.WARN)
    return
  end
  local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
  local cursor = vim.api.nvim_win_get_cursor(win_id)
  local cursor_line = cursor[1]
  local fence_start, fence_end, lang, code_lines = find_code_block_at_cursor(lines, cursor_line)
  if not fence_start then
    vim.notify("Cursor is not inside a code block", vim.log.levels.WARN)
    return
  end
  if cursor_line <= fence_start or cursor_line >= fence_end then
    vim.notify("Cursor must be inside the code block (between fences)", vim.log.levels.WARN)
    return
  end
  local cwd, remaining_lines = parse_cwd_directive(code_lines)
  local result = run_code(lang, remaining_lines, cwd)
  show_output(result)
end

function M.setup()
  local data_dir = vim.fn.stdpath("data")
  local fullpath = vim.fs.joinpath(data_dir, "eap-scratchpads.db")
  local scratch_dir = vim.fs.joinpath(data_dir, "eap-scratchpads")
  local state = ScratchpadState.new(fullpath, scratch_dir)
  state:init()

  vim.api.nvim_create_user_command("ScratchpadCreate", function()
    vim.ui.input({ prompt = "Scratchpad name: " }, function(name)
      if name and #name > 0 then
        state:create(name)
        logger.info("Created scratchpad: " .. name)
      end
    end)
  end, {
    desc = "Create a new named scratchpad.",
  })

  vim.api.nvim_create_user_command("ScratchpadSelect", function()
    state:select()
  end, {
    desc = "Select a scratchpad from the list.",
  })

  vim.api.nvim_create_user_command("ScratchpadToggle", function()
    state:toggle()
  end, {
    desc = "Toggle the scratchpad window.",
  })

  vim.api.nvim_create_user_command("ScratchpadExecute", function()
    state:execute_at_cursor()
  end, {
    desc = "Execute the code block under the cursor.",
  })

  vim.api.nvim_create_user_command("ScratchpadInfo", function()
    state:show_info()
  end, {
    desc = "Show scratchpad database info.",
  })

  vim.api.nvim_create_user_command("ScratchpadReset", function()
    state:reset()
    state:init()
  end, {
    desc = "Reset scratchpad database.",
  })

  vim.keymap.set("n", "<leader>jt", function()
    state:toggle()
  end, { desc = "Toggle scratchpad" })

  vim.keymap.set("n", "<leader>je", function()
    state:execute_at_cursor()
  end, { desc = "Execute code block in scratchpad" })

  vim.keymap.set("n", "<leader>js", function()
    state:select()
  end, { desc = "Select scratchpad" })
end

return M
