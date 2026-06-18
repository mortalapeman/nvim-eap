require("eap.logging").setup()
require("eap.project").setup()
require("eap.telescope").setup()
require("eap.lsp").setup()
require("eap.sqlite").setup({})
require("eap.telescope").setup()

local util = require("eap.util")
local cwd = require("eap.cwd")

-- User Commands
vim.api.nvim_create_user_command("Scratch", util.scratch_buffer, {
  desc = "Create a scratch buffer.",
})

vim.api.nvim_create_user_command("FileDelete", util.delete_current_file, {
  desc = "Delete the current file and buffer.",
})

vim.api.nvim_create_user_command("CwdToFileDir", cwd.cwd_to_file_dir, {
  desc = "Change CWD to the current file's directory",
})

vim.api.nvim_create_user_command("CwdBack", cwd.cwd_back, {
  desc = "Go back to the previous CWD",
})

vim.api.nvim_create_user_command("BufferCloseOthers", util.wipe_other_buffers, {
  desc = "Close all buffers minus current",
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

-- Keymaps
vim.keymap.set("n", "<leader>yy", require("eap.loc").yank_current_line_as_loc, {
  desc = "Yanks the current relative file path, line and col numer int the defautl register.",
})

vim.keymap.set("n", "<leader>gf", require("eap.loc").go_to_file_loc, {
  desc = "Go to file location under cursor.",
})
