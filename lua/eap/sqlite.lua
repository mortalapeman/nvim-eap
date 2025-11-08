--- @class SqliteConfig
--- @field filename string Name of the database file

local debug = require("eap.debug")
local array = require("eap.array")

local M = {}

local function buf_get_current_number()
  return vim.fn.bufadd(vim.fn.expand("%"))
end

--- @return string[] Lines of the current buffer
local function buf_get_current_lines()
  local buf_num = buf_get_current_number()
  local count = vim.api.nvim_buf_line_count(buf_num)
  local lines = vim.api.nvim_buf_get_lines(buf_num, 0, count, false)
  return lines
end

---@param dbfile string File path to the database file.
local function execute_current_file(dbfile)
  local tmpfile = vim.fn.tempname()
  local pragma_lines = {
    "PRAGMA foreign_keys = ON;",
    "PRAGMA journal_mode = WAL;",
  }
  local lines = buf_get_current_lines()
  local combined = array.concat(pragma_lines, lines)
  vim.fn.writefile(combined, tmpfile)
  local cmd = string.format("cat %s | sqlite3 %s", tmpfile, dbfile)
  local result = vim.fn.system(cmd)
  vim.fn.delete(tmpfile)
  debug.set("result", result)
end

---@param config SqliteConfig
M.setup = function(config)
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "sql" },
    group = vim.api.nvim_create_augroup("eap-filetype-sql", {}),
    desc = "Configure the current buffer with SQLite specific commands.",
    callback = function()
      local current_buffer = buf_get_current_number()
      vim.api.nvim_buf_create_user_command(current_buffer, "SqlExecuteFile", function()
        execute_current_file(config.filename)
      end, {
        desc = "Execute the current file against the configured SQLite database.",
      })
    end,
  })
end

M.setup({ filename = "dbfile.db" })

return M
