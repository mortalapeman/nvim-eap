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

local function copy_lsp_docs_to_register()
  local params = vim.lsp.util.make_position_params(0, "utf-8")
  -- Request hover information from the LSP
  local results, err = vim.lsp.buf_request_sync(0, "textDocument/hover", params, 1000)
  if err or not results or vim.tbl_isempty(results) then
    print("No LSP documentation found.")
    return
  end

  local lines = {}
  for _, response in pairs(results) do
    if response.result and response.result.contents then
      local contents = response.result.contents
      -- LSP contents can be a string, a table of strings, or a MarkupContent object
      if type(contents) == "string" then
        table.insert(lines, contents)
      elseif contents.kind == "markdown" or contents.kind == "plaintext" then
        table.insert(lines, contents.value)
      elseif type(contents) == "table" then
        -- Handle cases where contents is an array of strings/objects
        for _, item in ipairs(contents) do
          if type(item) == "string" then
            table.insert(lines, item)
          else
            table.insert(lines, item.value)
          end
        end
      end
    end
  end

  if #lines > 0 then
    local content_str = table.concat(lines, "\n")
    -- Set the unnamed register (default) to the documentation content
    vim.fn.setreg('"', content_str)
    print("LSP documentation copied to default register.")
  else
    print("LSP documentation is empty.")
  end
end

-- Keymap example: <leader>ly to "LSP Yank"
vim.keymap.set("n", "<leader>ly", copy_lsp_docs_to_register, { desc = "Copy LSP docs to register" })
