local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

local T = new_set()

T["docker.docker_is_running()"] = new_set()

T["docker.docker_is_running()"]["returns false when socket is missing"] = function()
  local docker = require("eap.docker")
  local ok, err = docker.docker_is_running("/definitely/not/a/docker.sock")

  eq(false, ok)
  eq("Docker socket not found at /definitely/not/a/docker.sock — is Docker Desktop running?", err)
end

return T
