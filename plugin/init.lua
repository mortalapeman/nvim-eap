require("eap.logging").setup()
require("eap.project").setup()

local util = require("eap.util")

vim.api.nvim_create_user_command("Scratch", function()
  local buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_win_set_buf(0, buf)
end, {
  desc = "Delete the current file and buffer.",
})

-- User Commands
vim.api.nvim_create_user_command("FileDelete", function()
  vim.cmd([[
    call delete(expand('%'))
    bd!
  ]])
end, {
  desc = "Delete the current file and buffer.",
})

vim.api.nvim_create_user_command("ChangeCwdToFileDir", function()
  local filename = vim.api.nvim_buf_get_name(0)
  if filename then
    local dir_path = vim.fn.fnamemodify(filename, ":h")
    vim.cmd("cd " .. dir_path)
    vim.notify("Changed CWD to: " .. dir_path, vim.log.levels.INFO)
  else
    vim.notify("Could not determine current file path.", vim.log.levels.ERROR)
  end
end, {
  desc = "Change CWD to the current file's directory",
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
