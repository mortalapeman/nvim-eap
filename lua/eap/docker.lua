local M = {}

local IMAGE = "build-test:latest"
local CONTAINER_NAME = "build-test"

--- Returns true if the given filename looks like a Dockerfile.
local function is_dockerfile(filename)
  return filename == "Dockerfile" or filename:match("^Dockerfile%.") ~= nil
end

--- Build the Dockerfile in the current buffer and run it interactively.
function M.run_build()
  local buf = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(buf)
  local filename = vim.fn.fnamemodify(path, ":t")

  if not is_dockerfile(filename) then
    vim.notify("DockerRunBuild can only be used from a Dockerfile buffer", vim.log.levels.ERROR)
    return
  end

  -- Save the buffer before building.
  vim.cmd("write")

  local context_dir = vim.fn.fnamemodify(path, ":h")

  local cmd = "docker build -t %s -f %s %s"
  local build_cmd = string.format(cmd, IMAGE, vim.fn.shellescape(path), vim.fn.shellescape(context_dir))

  -- Open a horizontal split and run the build in a terminal.
  vim.cmd("split")

  vim.fn.jobstart({ "sh", "-c", build_cmd }, {
    term = true,
    on_exit = vim.schedule_wrap(function(_, exit_code, _)
      if exit_code ~= 0 then
        vim.notify("Docker build failed, not running container", vim.log.levels.ERROR)
        return
      end

      -- After a successful build, open a vertical split and run the container.
      local run_cmd = "terminal docker run -it --rm --name %s %s /bin/bash"
      vim.cmd("split")
      vim.cmd(string.format(run_cmd, CONTAINER_NAME, IMAGE))
    end),
  })
end

function M.setup()
  vim.api.nvim_create_user_command("DockerRunBuild", M.run_build, {
    desc = "Build the current Dockerfile and run it interactively in a container",
  })
end

return M
