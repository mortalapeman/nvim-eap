local conf = require("telescope.config").values
local finders = require("telescope.finders")
local make_entry = require("telescope.make_entry")
local pickers = require("telescope.pickers")

local M = {}

local live_grep_glob = function(opts)
  opts = opts or {}
  opts.cwd = opts.cwd or vim.uv.cwd()

  local finder = finders.new_job(function(prompt)
    if not prompt or prompt == "" then
      return nil
    end

    -- Split prompt: "term  *.py" -> piece[1] = "term", piece[2] = "*.py"
    local pieces = vim.split(prompt, "  ")

    local args = { "rg", "--column", "--line-number", "--no-heading", "--color=never", "--smart-case" }

    -- Add the search term
    table.insert(args, "-e")
    table.insert(args, pieces[1])

    -- If there is a second piece, treat it as a glob filter
    if pieces[2] then
      table.insert(args, "-g")
      table.insert(args, pieces[2])
    end

    return args
  end, make_entry.gen_from_vimgrep(opts), opts.max_results, opts.cwd)

  pickers
    .new(opts, {
      prompt_title = "Live Grep (with Glob)",
      finder = finder,
      previewer = conf.grep_previewer(opts),
      sorter = conf.generic_sorter(opts),
    })
    :find()
end

function M.setup()
  -- Create a keymap to call it
  vim.keymap.set("n", "<leader>fg", live_grep_glob, { desc = "Fuzzy Grep with Glob" })
end

return M
