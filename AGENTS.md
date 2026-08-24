# AGENTS.md

## Project Overview

Neovim config and plugin suite by Eric Pritchett. Lua modules live in `lua/eap/`, tests in `tests/`, and plugin entry point in `plugin/init.lua`.

## Running Tests

Tests use [mini.test](https://github.com/nvim-mini/mini.nvim/blob/master/readmes/mini-test.md) from the mini.nvim ecosystem. The `deps/mini.nvim` dependency is auto-cloned on first run.

```sh
# Run all tests
make test

# Run a single test file
make test_file FILE=tests/test_eap_util.lua
```

The raw command (what `make test` runs):

```sh
nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"
```

### Test file conventions

- Files are named `test_eap_<module>.lua` in `tests/`.
- Each file returns a `MiniTest` test set (`T`).
- Use `MiniTest.new_set()` for groups, `MiniTest.expect.equality()` for assertions.
- `MiniTest.finally()` for cleanup. `MiniTest.new_child_neovim()` for tests that need a child Neovim process.

## Code Style

- Lua formatting: StyLua with 2-space indentation (`stylua.toml` at repo root).
- No comments in new code unless explicitly requested.

## Linting / Formatting

```sh
stylua lua/ tests/
```
