require("eap.logging").setup()
require("eap.project").setup()
require("eap.telescope").setup()
require("eap.lsp").setup()
require("eap.sqlite").setup({})
require("eap.telescope").setup()

local util = require("eap.util")

-- User Commands
vim.api.nvim_create_user_command("Scratch", function()
  local buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_win_set_buf(0, buf)
end, {
  desc = "Create a scratch buffer.",
})

vim.api.nvim_create_user_command("FileDelete", function()
  vim.cmd([[
    call delete(expand('%'))
    bd!
  ]])
end, {
  desc = "Delete the current file and buffer.",
})

local cwd_stack = {}

vim.api.nvim_create_user_command("ChangeCwdToFileDir", function()
  local cwd = vim.fn.getcwd()
  local filename = vim.api.nvim_buf_get_name(0)
  if filename then
    local dir_path = vim.fn.fnamemodify(filename, ":h")
    table.insert(cwd_stack, cwd)
    vim.cmd("cd " .. dir_path)
    vim.notify("Changed CWD to: " .. dir_path, vim.log.levels.INFO)
  else
    vim.notify("Could not determine current file path.", vim.log.levels.ERROR)
  end
end, {
  desc = "Change CWD to the current file's directory",
})

vim.api.nvim_create_user_command("ChangeCwdBack", function()
  if #cwd_stack > 0 then
    local previous_dir = table.remove(cwd_stack, #cwd_stack)
    vim.cmd("cd " .. previous_dir)
    vim.notify("Changed CWD back to: " .. previous_dir, vim.log.levels.INFO)
  else
    vim.notify("CWD stack is empty.", vim.log.levels.WARN)
  end
end, {
  desc = "Go back to the previous CWD",
})

vim.api.nvim_create_user_command("BufferCloseOthers", function()
  util.wipe_other_buffers()
end, {
  desc = "Close all buffers minus current",
})

vim.api.nvim_create_user_command("YankCurrentLine", function()
  vim.cmd([[
    let @@=expand('%:~:.') .. ":" .. line(".") .. ":" .. col(".")
  ]])
end, { desc = "Yanks the current relative file path, line and col numer int the defautl register." })

vim.keymap.set("n", "<leader>yy", ":YankCurrentLine<CR>", {
  desc = "Yanks the current relative file path, line and col numer int the defautl register.",
})

local function GotoFileLineCol()
  local loc = vim.fn.expand("<cWORD>")
  local _, line, col = unpack(vim.fn.split(loc, ":"))
  vim.cmd([[normal! gf]])
  if line ~= nil and col ~= nil then
    vim.api.nvim_win_set_cursor(0, { tonumber(line), tonumber(col) })
  end
end

vim.keymap.set("n", "<leader>gf", GotoFileLineCol, {
  desc = "Go to file location under cursor.",
})

-- Auto Commands
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "lua" },
  desc = "Setup keymaps and other config specifically for lua files",
  group = vim.api.nvim_create_augroup("eap-ft-lua", { clear = true }),
  callback = function(ev)
    vim.bo.expandtab = true
    vim.bo.shiftwidth = 2
    vim.bo.tabstop = 2

    vim.keymap.set("n", "<leader>e", function()
      vim.cmd([[
        write
        luafile %
      ]])
    end, {
      buffer = ev.buf,
      desc = "Save the current file and execute via luafile",
    })
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "json" },
  desc = "Setup keymaps and other config specifically for json files",
  group = vim.api.nvim_create_augroup("eap-ft-json", { clear = true }),
  callback = function()
    vim.bo.expandtab = true
    vim.bo.shiftwidth = 2
    vim.bo.tabstop = 2
  end,
})
