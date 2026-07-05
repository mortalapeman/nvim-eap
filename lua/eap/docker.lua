local M = {}

local DOCKER_SOCKET = "/var/run/docker.sock"

local function run()
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local col = (vim.o.columns - width) / 2
  local row = (vim.o.lines - height) / 2
  local buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    height = height,
    width = width,
    border = "rounded",
    style = "minimal",
  })

  local ps_out = vim.fn.system([[docker ps --format="{{json .}}"]])

  if ps_out == nil then
    return
  end

  local split = vim.fn.split(ps_out, "\n", false)
  local concat = "[" .. table.concat(split, ",") .. "]"
  local containers = vim.json.decode(concat)

  local names = {}
  for _, item in ipairs(containers) do
    table.insert(names, item.Names)
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, names)
end

---Check whether the Docker daemon is reachable through the configured unix socket.
---@param socket_path? string Path to the Docker unix socket (defaults to `DOCKER_SOCKET`)
---@return boolean ok `true` if Docker is running, otherwise `false`
---@return string? err Error message when Docker is not reachable
local function docker_is_running(socket_path)
  socket_path = socket_path or DOCKER_SOCKET

  -- Verify the Docker unix socket exists
  local stat = vim.uv.fs_stat(socket_path)
  if not stat or stat.type ~= "socket" then
    return false, "Docker socket not found at " .. socket_path .. " — is Docker Desktop running?"
  end

  -- Try a lightweight ping to confirm something is listening
  local ping = vim.fn.system({
    "curl",
    "-s",
    "--max-time",
    "2",
    "--unix-socket",
    socket_path,
    "http://localhost/_ping",
  })

  if vim.v.shell_error ~= 0 or ping == "" then
    return false, "Cannot connect to Docker at " .. socket_path .. " — is Docker Desktop running?"
  end

  return true
end

local function get_running_containers()
  -- Precheck: ensure Docker Desktop is running before issuing the real request
  local ok, err = docker_is_running()
  if not ok then
    vim.notify(err or "", vim.log.levels.ERROR)
    return
  end

  -- Docker API endpoint for listing containers (returns JSON)
  local url = "http://localhost/v1.41/containers/json"

  -- Build the curl command
  local cmd = {
    "curl",
    "-s", -- Silent mode (hides progress bar)
    "--unix-socket",
    DOCKER_SOCKET,
    url,
  }

  -- Execute asynchronously via vim.system
  vim.system(cmd, { text = true }, function(obj)
    -- Handle system-level errors (e.g., curl not found)
    if obj.code ~= 0 then
      vim.schedule(function()
        vim.notify(
          string.format("Docker request failed (code %d): %s", obj.code, obj.stderr or ""),
          vim.log.levels.ERROR
        )
      end)
      return
    end

    -- Process the JSON response
    vim.schedule(function()
      local success, containers = pcall(vim.json.decode, obj.stdout)

      if not success or not containers then
        vim.notify("Failed to parse Docker response", vim.log.levels.ERROR)
        return
      end

      if #containers == 0 then
        print(vim.inspect(containers))
        print("No containers are currently running.")
        return
      end

      -- Iterate and print out the containers nicely
      print("--- Running Docker Containers ---")
      for _, container in ipairs(containers) do
        -- Names usually come with a leading slash, e.g., "/my_nginx"
        local name = container.Names[1]:sub(2)
        local id = container.Id:sub(1, 12) -- Short ID
        local status = container.Status

        print(string.format("ID: %s | Name: %s | Status: %s", id, name, status))
      end
    end)
  end)
end

-- Run the function
-- get_running_containers()
docker_is_running()

M.docker_is_running = docker_is_running

return M
