local M = {}

local debug = require("eap.debug")

local namespace = vim.api.nvim_create_namespace("test")
local scratch_buffer_name = "PlaygroundScratch"

local function scratch_buffer()
  local buf_num = vim.fn.bufadd(scratch_buffer_name)
  local opt = vim.bo[buf_num]
  opt.bufhidden = "hide"
  opt.swapfile = false
  opt.buftype = "nofile"
  return buf_num
end

local function clear()
  local buf_num = scratch_buffer()
  local index = vim.api.nvim_buf_line_count(buf_num)
  vim.api.nvim_buf_set_lines(buf_num, 0, index, false, {})
end

---@param text string Text to write to the scratch buffer
local function write_to_buffer(text)
  local buf_num = scratch_buffer()
  local lines = vim.fn.split(text, "\r\n\\|\n")
  local index = vim.api.nvim_buf_line_count(buf_num)
  vim.api.nvim_buf_set_lines(buf_num, index, index, false, lines)
end

local function bprint(text)
  clear()
  write_to_buffer(text)
  local buf_num = scratch_buffer()
  local windows = vim.fn.win_findbuf(buf_num)
  if next(windows) == nil then
    vim.cmd("vsplit " .. scratch_buffer_name)
  end
end

local function test_mark()
  local buf_num = scratch_buffer()
  vim.api.nvim_buf_clear_namespace(buf_num, namespace, 0, -1)
  vim.api.nvim_buf_set_extmark(buf_num, namespace, 1, 5, {
    virt_text_pos = "inline",
    virt_text = { { " asdf", "BlinkCmpGhostText" } },
  })
end

-- print([[
-- local function print(text)
--   write_to_buffer(text)
--   local buf_num = scratch_buffer()
--   local windows = vim.fn.win_findbuf(buf_num)
--   if next(windows) == nil then
--     vim.cmd("vsplit " .. scratch_buffer_name)
--   end
-- end
-- ]])
--
-- test_mark()
--
--

return M
