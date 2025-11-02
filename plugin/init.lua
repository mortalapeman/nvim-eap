vim.api.nvim_create_user_command("DeleteFile", function()
  vim.cmd([[
    call delete(expand('%'))
    bd!
  ]])
end, {})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "lua" },
  desc = "Keymaps and other config specifically for files",
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
