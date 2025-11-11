require("eap.logging").setup()
require("eap.project").setup()

local util = require("eap.util")

-- User Commands
vim.api.nvim_create_user_command("FileDelete", function()
  vim.cmd([[
    call delete(expand('%'))
    bd!
  ]])
end, {
  desc = "Delete the current file and buffer.",
})

vim.api.nvim_create_user_command("BufferCloseOthers", function()
  util.wipe_other_buffers()
end, {
  desc = "Close all buffers minus current",
})

-- Auto Commands
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "lua" },
  desc = "Setup keymaps and other config specifically for files",
  group = vim.api.nvim_create_augroup("eap-lua-files", { clear = true }),
  callback = function()
    vim.bo.expandtab = true
    vim.bo.shiftwidth = 2
    vim.bo.tabstop = 2

    vim.keymap.set("n", "<leader>e", function()
      vim.cmd([[
        write
        luafile %
      ]])
    end, {
      buffer = true,
    })
  end,
})
