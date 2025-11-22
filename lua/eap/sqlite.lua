local array = require("eap.array")

local M = {}

--- @class SqliteConfig
--- @field filename string | nil Name of the database file
--- @field pragma_lines string[] | nil Pragma lines to add before execution of any sql code.

--- Simple function to encode Lua values to SQL strings suitable for injection
--- into a SQL query.
---@param value nil | string | boolean | integer
local function encode(value)
  local value_type = type(value)
  if value_type == "nil" then
    return "NULL"
  elseif value_type == "boolean" then
    if value then
      return "1"
    else
      return "0"
    end
  elseif value_type == "number" then
    return tostring(value)
  elseif value_type == "string" then
    return string.format("'%s'", value)
  end
  error("Unsupported value type: " .. value_type)
end

local function quote(value)
  return vim.fn.join({ '"', value, '"' })
end

--- Replaces all the named params in the given sql string with the values in the
--- params table.
---@param sql string
---@param params {[string]: any}
local function inject_params(sql, params)
  local result = sql
  for k, v in pairs(params) do
    local pattern = ":" .. k
    local repl = encode(v)
    result = string.gsub(result, pattern, repl)
  end
  return result
end

---@param dbfile string
---@param cmd string
---@param sql string
---@param params? {[string]: any}
---@param pragmas? string[]
---@return string | nil, string | nil
local function execute_sql_with_cmd(dbfile, cmd, sql, params, pragmas)
  pragmas = pragmas or { "PRAGMA foreign_keys = ON;", "PRAGMA journal_mode = WAL;" }
  if params then
    sql = inject_params(sql, params)
  end
  local sql_split = vim.fn.split(sql, "\n")
  local sql_and_pragmas = array.concat(pragmas, sql_split)
  local temp = vim.fn.tempname()
  vim.fn.writefile(sql_and_pragmas, temp)
  local full_cmd = vim.fn.join({ "cat", temp, "|", cmd, quote(dbfile) }, " ")
  local sqlite_output = vim.fn.system(full_cmd)
  vim.fn.delete(temp)
  if vim.v.shell_error ~= 0 then
    return nil, string.format("An error occured excuting the SQL.\n\n %s", sqlite_output)
  else
    if sqlite_output == "" then
      return nil, "No output"
    end
    return sqlite_output, nil
  end
end

---@param dbfile string Use empty string for temporary database or pass the file name
---@param sql string Array of sql expressions to evaluate.
---@param params? {[string]: any}
---@return any, string | nil # A table of row objects from the execution of
---provided SQL statement.
function M.execute_sql(dbfile, sql, params)
  local result, error = execute_sql_with_cmd(dbfile, "sqlite3 -json", sql, params, {})
  if result ~= nil then
    return vim.json.decode(result), nil
  end
  return nil, error
end

---@param dbfile string Use empty string for temporary database or pass the file name
---@param sql string Array of sql expressions to evaluate.
---@param params? {[string]: any}
---@return string | nil, string | nil # A markdown representation of the query
---and an error string.
function M.execute_sql_md(dbfile, sql, params)
  return execute_sql_with_cmd(dbfile, "sqlite3 -markdown", sql, params, {})
end

function M.table_exists(dbfile, tblname)
  local sql = string.format("pragma table_info(%s);", tblname)
  local _, error = M.execute_sql(dbfile, sql)
  return error == nil
end

--- @param config SqliteConfig
local function execute_current_file(config)
  local tmpfile = vim.fn.tempname()
  local bufid = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufid, 0, -1, false)
  local combined = array.concat(config.pragma_lines, lines)
  vim.fn.writefile(combined, tmpfile)
  local cmd = string.format("cat %s | sqlite3 %s", tmpfile, config.filename)
  vim.fn.system(cmd)
  vim.fn.delete(tmpfile)
end

---@param config SqliteConfig
function M.setup(config)
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "sql" },
    group = vim.api.nvim_create_augroup("eap-filetype-sql", {}),
    desc = "Configure the current buffer with SQLite specific commands.",
    callback = function()
      local bufid = vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_create_user_command(bufid, "SqlExecuteFile", function()
        execute_current_file(config)
      end, {
        desc = "Execute the current file against the configured SQLite database.",
      })
    end,
  })
end

-- M.setup({
--   filename = "dbfile.db",
--   pragma_lines = {
--     "PRAGMA foreign_keys = ON;",
--     "PRAGMA journal_mode = WAL;",
--   },
-- })

return M
