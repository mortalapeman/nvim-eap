--- @class SqliteConfig
--- @field filename string | nil Name of the database file
--- @field pragma_lines string[] | nil Pragma lines to add before execution of any sql code.

local debug = require("eap.debug")
local array = require("eap.array")

local M = {}

---@param dbfile string Use empty string for temporary database or pass the file name
---@param sql string Array of sql expressions to evaluate.
---@return any, string | nil # A table row objects from the execution of SQL
local function execute_sql(dbfile, sql)
  local sql_split = vim.fn.split(sql, "\n")
  local temp = vim.fn.tempname()
  vim.fn.writefile(sql_split, temp)
  local cmd = string.format("cat %s | sqlite3 -json '%s'", temp, dbfile)
  local sqlite_output = vim.fn.system(cmd)
  vim.fn.delete(temp)
  if vim.v.shell_error ~= 0 then
    return nil, string.format("An error occured excuting the SQL.\n\n %s", sqlite_output)
  else
    if sqlite_output == "" then
      return nil, "No output"
    end
    local lua_result = vim.json.decode(sqlite_output)
    return lua_result, nil
  end
end
M.execute_sql = execute_sql

local function table_exists(dbfile, tblname)
  local sql = string.format("pragma table_info(%s);", tblname)
  local _, error = execute_sql(dbfile, sql)
  return error == nil
end
M.table_exists = table_exists

--- @return string[] Lines of the current buffer
local function buf_get_current_lines()
  local buf_num = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf_num, 0, -1, false)
  return lines
end

--- @param config SqliteConfig
local function execute_current_file(config)
  local tmpfile = vim.fn.tempname()
  local lines = buf_get_current_lines()
  local combined = array.concat(config.pragma_lines, lines)
  vim.fn.writefile(combined, tmpfile)
  local cmd = string.format("cat %s | sqlite3 %s", tmpfile, config.filename)
  local result = vim.fn.system(cmd)
  vim.fn.delete(tmpfile)
end

---@param config SqliteConfig
M.setup = function(config)
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "sql" },
    group = vim.api.nvim_create_augroup("eap-filetype-sql", {}),
    desc = "Configure the current buffer with SQLite specific commands.",
    callback = function()
      local current_buffer = vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_create_user_command(current_buffer, "SqlExecuteFile", function()
        execute_current_file(config)
      end, {
        desc = "Execute the current file against the configured SQLite database.",
      })
    end,
  })
end

M.setup({
  filename = "dbfile.db",
  pragma_lines = {
    "PRAGMA foreign_keys = ON;",
    "PRAGMA journal_mode = WAL;",
  },
})

return M
