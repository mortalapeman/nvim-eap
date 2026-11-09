---@module 'mini.test'

local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

if vim.fn.executable("rg") == 0 then
  MiniTest.skip("Needs `rg` executable")
end

local child = MiniTest.new_child_neovim()

local T = new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
      child.lua([[vim.g.mapleader = ' ']])
      child.lua([[M = require('eap.rg')]])
      child.lua([[M.setup()]])
      child.lua([[
        local dir = vim.fn.tempname()
        vim.fn.mkdir(dir)
        vim.cmd.cd(vim.fn.escape(dir, ' '))
        vim.fn.writefile({ 'local foo = 1', 'print(foo)', 'local bar = foo' }, 'target.lua')
        vim.fn.writefile({ 'foo also here' }, 'other.txt')
        vim.cmd.edit('target.lua')
      ]])
    end,
    post_once = function()
      child.lua([[vim.fn.delete(vim.fn.getcwd(), 'rf')]])
      child.stop()
    end,
  },
})

T["rg.search()"] = new_set()

T["rg.search()"]["populates location list with pattern matches"] = function()
  child.lua([[M.search({ args = 'foo' })]])
  local loc = child.lua([[return vim.fn.getloclist(0, { id = 0, title = 1, items = 1 })]])
  eq("Rg foo", loc.title)
  eq(4, #loc.items)
end

T["rg.search()"]["filters by extension argument"] = function()
  child.lua([[M.search({ args = 'foo lua' })]])
  local exts = child.lua([[
    local items = vim.fn.getloclist(0, { id = 0, items = 1 }).items
    local result = {}
    for _, item in ipairs(items) do
      table.insert(result, vim.fn.fnamemodify(vim.api.nvim_buf_get_name(item.bufnr), ':e'))
    end
    return result
  ]])
  eq(3, #exts)
  for _, ext in ipairs(exts) do
    eq("lua", ext)
  end
end

T["rg.search()"]["accepts pattern and extensions directly"] = function()
  child.lua([[M.search({ pattern = 'print(foo)', extensions = { 'lua' } })]])
  local loc = child.lua([[return vim.fn.getloclist(0, { id = 0, title = 1, items = 1 })]])
  eq("Rg print(foo)", loc.title)
  eq(1, #loc.items)
end

T["rg.search()"]["does nothing with empty pattern"] = function()
  child.lua([[M.search({ args = '' })]])
  local loc = child.lua([[return vim.fn.getloclist(0, { id = 0, title = 1, items = 1 })]])
  eq(0, #(loc.items or {}))
end

T["rg.operator()"] = new_set()

T["rg.operator()"]["searches region between marks with filetype extension"] = function()
  child.lua([[
    vim.fn.setpos("'[", { 0, 1, 7, 0 })
    vim.fn.setpos("']", { 0, 1, 9, 0 })
    M.operator()
  ]])
  local loc = child.lua([[return vim.fn.getloclist(0, { id = 0, title = 1, items = 1 })]])
  eq("Rg foo", loc.title)
  eq(3, #loc.items)
end

T["rg.operator()"]["captures multi-word region trimmed"] = function()
  child.lua([[
    vim.fn.setpos("'[", { 0, 3, 1, 0 })
    vim.fn.setpos("']", { 0, 3, 9, 0 })
    M.operator()
  ]])
  local loc = child.lua([[return vim.fn.getloclist(0, { id = 0, title = 1, items = 1 })]])
  eq("Rg local bar", loc.title)
  eq(1, #loc.items)
end

T["rg.keymap"] = new_set()

T["rg.keymap"]["<leader>r sets up operator-pending search"] = function()
  child.lua([[vim.api.nvim_win_set_cursor(0, { 1, 6 })]])
  child.lua([[
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<leader>re', true, false, true), 'mtx', false)
    vim.wait(3000, function() return vim.fn.getloclist(0, { id = 0, title = 1 }).title == 'Rg foo' end)
  ]])
  local loc = child.lua([[return vim.fn.getloclist(0, { id = 0, title = 1, items = 1 })]])
  eq("Rg foo", loc.title)
  eq(3, #loc.items)
end

T["rg.keymap"]["works with text object motions"] = function()
  child.lua([[vim.api.nvim_win_set_cursor(0, { 2, 6 })]])
  child.lua([[
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<leader>raw', true, false, true), 'mtx', false)
    vim.wait(3000, function() return vim.fn.getloclist(0, { id = 0, title = 1 }).title == 'Rg foo' end)
  ]])
  local loc = child.lua([[return vim.fn.getloclist(0, { id = 0, title = 1, items = 1 })]])
  eq("Rg foo", loc.title)
  eq(3, #loc.items)
end

T["rg.navigation"] = new_set()

T["rg.navigation"]["next and previous move through items"] = function()
  child.lua([[M.search({ args = 'foo lua' })]])
  child.lua([[M.next()]])
  eq(2, child.lua([[return vim.fn.line('.')]]))
  child.lua([[M.previous()]])
  eq(1, child.lua([[return vim.fn.line('.')]]))
end

return T
