---@module 'mini.test'

local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality
local sqlite = require("eap.sqlite")

local T = new_set()

T["sqlite.execute_sql()"] = new_set()

T["sqlite.execute_sql()"]["works"] = function()
  local result, _ = sqlite.execute_sql("", "select 42 as value")
  eq(1, #result)
  eq(42, result[1].value)
end

T["sqlite.execute_sql()"]["encodes integer params"] = function()
  local result, _ = sqlite.execute_sql("", "select :value as value", { value = 24 })
  eq(24, result[1].value)
end

T["sqlite.execute_sql()"]["encodes string params"] = function()
  local result, _ = sqlite.execute_sql("", "select :value as value", { value = "24" })
  eq("24", result[1].value)
end

T["sqlite.execute_sql()"]["encodes false params 0"] = function()
  local result, _ = sqlite.execute_sql("", "select :value as value", { value = false })
  eq(0, result[1].value)
end

T["sqlite.execute_sql()"]["encodes true params as 1"] = function()
  local result, _ = sqlite.execute_sql("", "select :value as value", { value = true })
  eq(1, result[1].value)
end

T["sqlite.table_exists()"] = new_set()

T["sqlite.table_exists()"]["returns true if a table exists"] = function()
  local filename = vim.fn.tempname()
  MiniTest.finally(function()
    vim.fn.delete(filename)
  end)
  sqlite.execute_sql(filename, "create table foobar (id integer, value text);")
  eq(true, sqlite.table_exists(filename, "foobar"))
end

T["sqlite.table_exists()"]["returns false if a table does not exist"] = function()
  local filename = vim.fn.tempname()
  MiniTest.finally(function()
    vim.fn.delete(filename)
  end)
  sqlite.execute_sql(filename, "create table foobar (id integer, value text);")
  eq(false, sqlite.table_exists(filename, "blergs"))
end

return T
