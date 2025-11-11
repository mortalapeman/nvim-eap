local sqlite = require("eap.sqlite")

local M = {}

--- @enum log_level
local LOG_LEVEL = {
  ERROR = 1,
  WARN = 2,
  INFO = 3,
  DEBUG = 4,
  TRACE = 5,
}
--- @type string[]
local LOG_LEVEL_NAME = {
  "ERROR",
  "WARN ",
  "INFO ",
  "DEBUG",
  "TRACE",
}

--- @class LogEntry
--- @field log_entry_id integer ID of the log entry
--- @field created_at string Timestamp of when log entry was created
--- @field level log_level Log level as an integer value.
--- @field namespace string Log entry qualifier.
--- @field message string Log message.

--- @class LogWriter
--- @field write fun(level: log_level, namespace: string, message: string): nil Write log entry to store.

---@param dbfile string Path to database file
---@param name string Identifier for the writer.
---@return LogWriter # Log writer that will write to a sqlite database.
function M.new_db_writer(dbfile, name)
  if not sqlite.table_exists(dbfile, "log_entry") then
    local sql = [[
      create table log_entry (
        log_entry_id integer primary key autoincrement
        , level integer
        , created_at text default CURRENT_TIMESTAMP
        , namespace text
        , message text
      );
    ]]
    local _, error = sqlite.execute_sql(dbfile, sql)
    if error ~= "No output" then
      print(string.format("ERROR new_db_writer: %s", error))
    end
  end
  return {
    _type = "LogWriter",
    name = name,
    write = function(level, namespace, message)
      local sql = "insert into log_entry (level, namespace, message) values (%s, '%s', '%s')"
      local sql_with_params = string.format(sql, level, namespace, message)
      sqlite.execute_sql(dbfile, sql_with_params)
    end,
  }
end

local logging_group = vim.api.nvim_create_augroup("Logging", { clear = true })

---@return LogWriter # Writer that writes to a buffer named EapLogs.
function M.new_buf_writer()
  local function get_buf()
    local buf_num = vim.fn.bufadd("EapLogs")
    local opt = vim.bo[buf_num]
    opt.bufhidden = "hide"
    opt.swapfile = false
    opt.buftype = "nofile"
    return buf_num
  end
  return {
    _type = "LogWriter",
    write = function(level, namespace, message)
      local buf = get_buf()
      local text = string.format("%s [%s] %s - %s", os.date("%H:%M:%S"), LOG_LEVEL_NAME[level], namespace, message)
      local lines = vim.fn.split(text, "\n")
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
      vim.cmd("doautocmd Logging User LogWrite")
    end,
  }
end

--- Show the current EapLogs buffer in a vertical split.
function M.show_buf_logs()
  local buf = vim.fn.bufadd("EapLogs")
  local windows = vim.fn.win_findbuf(buf)
  if next(windows) == nil then
    vim.cmd("vsplit " .. "EapLogs")
    vim.api.nvim_create_autocmd("User", {
      pattern = "LogWrite",
      group = logging_group,
      callback = function()
        windows = vim.fn.win_findbuf(buf)
        local window = windows[1]
        if window then
          vim.api.nvim_win_call(window, function()
            vim.cmd("norm! G")
          end)
        end
      end,
    })
  end
end
--- @class ScopedLogger
--- @field error fun(message: string)
--- @field warn fun(message: string)
--- @field info fun(message: string)
--- @field debug fun(message: string)
--- @field trace fun(message: string)

--- @class Logger
--- @field error fun(message: string)
--- @field warn fun(message: string)
--- @field info fun(message: string)
--- @field debug fun(message: string)
--- @field trace fun(message: string)
--- @field scope fun(scope: string, cb: fun(logger: ScopedLogger): any)

--- @class State
--- @field writers LogWriter[] Array of registered logging writers.
--- @field loggers {[string]: Logger} Registry of existing loggers.

--- @type State
local state = {
  writers = {},
  loggers = {},
}

--- @param namespace string Namespace for the returned logger.
--- @return Logger # Logger for the provided namespace.
function M.get_logger(namespace)
  local cached_logger = state.loggers[namespace]
  if cached_logger ~= nil then
    return cached_logger
  end

  local with_log_level = function(level, ns)
    return function(message)
      for _, writer in pairs(state.writers) do
        writer.write(level, ns, message)
      end
    end
  end

  local function pack(...)
    local t = { ... }
    return t
  end

  local logger = {
    _type = "Logger",
    _namespace = namespace,
    error = with_log_level(LOG_LEVEL.ERROR, namespace),
    warn = with_log_level(LOG_LEVEL.WARN, namespace),
    info = with_log_level(LOG_LEVEL.INFO, namespace),
    debug = with_log_level(LOG_LEVEL.DEBUG, namespace),
    trace = with_log_level(LOG_LEVEL.TRACE, namespace),
    ---@param scope string
    ---@param cb fun(logger: ScopedLogger): any
    scope = function(scope, cb)
      local scoped = {
        error = with_log_level(LOG_LEVEL.ERROR, namespace .. "." .. scope),
        warn = with_log_level(LOG_LEVEL.WARN, namespace .. "." .. scope),
        info = with_log_level(LOG_LEVEL.INFO, namespace .. "." .. scope),
        debug = with_log_level(LOG_LEVEL.DEBUG, namespace .. "." .. scope),
        trace = with_log_level(LOG_LEVEL.TRACE, namespace .. "." .. scope),
      }
      scoped.debug("BEGIN")
      local result = pack(cb(scoped))
      scoped.debug("END")
      return unpack(result)
    end,
  }
  return logger
end

function M.writer_add(writer)
  table.insert(state.writers, writer)
end

function M.writer_all_clear()
  state.writers = {}
end
function M.logger_all_clear()
  state.loggers = {}
end

function M.setup()
  M.logger_all_clear()
  M.writer_all_clear()
  M.writer_add(M.new_buf_writer())
  vim.api.nvim_create_user_command("ShowLogs", function()
    M.show_buf_logs()
  end, {
    desc = "Show internal plugin log buffer in vertical split.",
  })
end

return M
