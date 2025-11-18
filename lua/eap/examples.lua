local function go_to_function_def_from_treesitter()
  local query = vim.treesitter.query.parse(
    "lua",
    [[
      ; query
      (function_declaration name: [
        (identifier) @func
        (method_index_expression 
          table: (identifier) 
          method: (identifier)) @method
        (dot_index_expression 
              table: (identifier) 
              field: (identifier)) @class-func
      ])
    ]]
  )
  local tree = vim.treesitter.get_parser():parse()[1]
  for id, node, metadata, match in query:iter_captures(tree:root(), 0) do
    -- Print the node name and source text.
    vim.print({ node:type(), vim.treesitter.get_node_text(node, vim.api.nvim_get_current_buf()) })
    local name = query.captures[id]
    if name == "method" then
      local row, col = node:range()
      vim.api.nvim_win_set_cursor(0, { row + 1, col })
      return
    end
  end
end
