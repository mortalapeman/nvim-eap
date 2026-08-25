# Run all test files
test: deps/mini.nvim deps/telescope.nvim deps/plenary.nvim
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"


# Run test from file at `$FILE` environment variable
test_file: deps/mini.nvim deps/telescope.nvim deps/plenary.nvim
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run_file('$(FILE)')"


# Download 'mini.nvim' to use its 'mini.test' testing module
deps/mini.nvim:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/nvim-mini/mini.nvim $@

# Download 'telescope.nvim' for picker tests
deps/telescope.nvim:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/nvim-telescope/telescope.nvim $@

# Download 'plenary.nvim' (telescope dependency)
deps/plenary.nvim:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/nvim-lua/plenary.nvim $@

# Format lua files with stylua
format:
	stylua lua/ tests/
