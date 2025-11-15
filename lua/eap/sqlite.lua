--- @class SqliteConfig
--- @field filename string | nil Name of the database file
--- @field pragma_lines string[] | nil Pragma lines to add before execution of any sql code.

local array = require("eap.array")

local M = {}

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

---@param dbfile string Use empty string for temporary database or pass the file name
---@param sql string Array of sql expressions to evaluate.
---@param params? {[string]: any}
---@return any, string | nil # A table row objects from the execution of SQL
local function execute_sql(dbfile, sql, params)
  if params then
    sql = inject_params(sql, params)
  end
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

function M.execute_sql_md(dbfile, sql)
  local sql_split = vim.fn.split(sql, "\n")
  local temp = vim.fn.tempname()
  vim.fn.writefile(sql_split, temp)
  local cmd = string.format("cat %s | sqlite3 -markdown '%s'", temp, dbfile)
  local sqlite_output = vim.fn.system(cmd)
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
