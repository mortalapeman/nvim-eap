local M = {}

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

function M.setup()
  -- Keymap example: <leader>ly to "LSP Yank"
  vim.keymap.set("n", "<leader>ly", copy_lsp_docs_to_register, { desc = "Copy LSP docs to register" })
end

return M
