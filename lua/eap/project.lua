local sqlite = require("eap.sqlite")
local logging = require("eap.logging")

local M = {}

local logger = logging.get_logger("eap.project")

local function find_git_root()
  return vim.fn.trim(vim.fn.system("git rev-parse --show-toplevel"))
end

---@class ProjectState
---@field _dbfile string
---@field new fun(dbfile: string): ProjectState
---@field init fun(self: ProjectState)
local ProjectState = {}

---@param dbfile string
---@return ProjectState
function ProjectState.new(dbfile)
  local self = {
    _dbfile = dbfile,
  }
  setmetatable(self, { __index = ProjectState })
  return self
end

function ProjectState:init()
  if not vim.uv.fs_stat(self._dbfile) or not sqlite.table_exists(self._dbfile, "project") then
    local sql = [[
      create table project (
        project_id integer primary key autoincrement
        , dir text
        , name text
        , active integer
      );
      create table buffer (
        buffer_id integer primary key autoincrement
        , name text
        , project_id integer 
        , active integer
        , row integer
        , col integer
        , foreign key (project_id) references project(project_id)
      );
    ]]
    local _, error = sqlite.execute_sql(self._dbfile, sql)
    if error and error ~= "No output" then
      logger.error(error)
    end
  end
end

function ProjectState:reset()
  if vim.uv.fs_stat(self._dbfile) then
    vim.fn.delete(self._dbfile)
  end
end

function ProjectState:show_info()
  local sql = "select * from project;"
  local result, _ = sqlite.execute_sql_md(self._dbfile, sql)
  print(self._dbfile)
  print(result or "No projects")
  sql = "select * from buffer;"
  result, _ = sqlite.execute_sql_md(self._dbfile, sql)
  print(result or "No buffers")
end

local function buf_current_git_root()
  local bufdir = vim.fn.expand("%:p:h")
  local old_cwd = vim.uv.cwd()
  vim.cmd("lcd " .. bufdir)
  local root = find_git_root()
  vim.cmd("lcd " .. old_cwd)
  return root
end

function ProjectState:create_project()
  logger.scope("create_project", function(logs)
    vim.ui.input(
      {
        prompt = "Project Name: ",
      },
      ---@param name string
      function(name)
        if name ~= nil then
          local git_root = buf_current_git_root()
          local sql = [[
          update project set active = 0;
          insert into project (dir, name, active)
          values ('%s', '%s', 1);
        ]]
          local sql_with_params = string.format(sql, git_root, name)
          local _, error = sqlite.execute_sql(self._dbfile, sql_with_params)
          if error and error ~= "No output" then
            logger.error(error)
          end
        else
          logs.debug("No project")
        end
      end
    )
  end)
end

---@class Project
---@field project_id integer
---@field dir string
---@field name string
---@field active 0 | 1

---@param dbfile string
---@return Project[] | nil
local function all_projects(dbfile)
  local sql = "select project_id, name, dir, active from project;"
  local result, error = sqlite.execute_sql(dbfile, sql)
  if error and error ~= "No output" then
    logger.error(error)
    return nil
  end
  return result
end

function ProjectState:open_project_bufs(project_id)
  local result, _ = sqlite.execute_sql(
    self._dbfile,
    [[
      select 
        name 
        , row
        , col
        , active
      from buffer 
      where project_id = :pid
      order by active
    ]],
    { pid = project_id }
  )
  for _, buf in pairs(result) do
    vim.defer_fn(function()
      vim.cmd("e " .. buf.name)
      if buf.active ~= 0 then
        vim.api.nvim_win_set_cursor(0, { buf.row, buf.col })
      end
    end, 0)
  end
end

function ProjectState:deactivate()
  sqlite.execute_sql(self._dbfile, "update project set active = 0")
end

function ProjectState:select_project()
  logger.scope("select_project", function(logs)
    local projects = all_projects(self._dbfile)
    if projects == nil then
      logs.warn("No projects found")
      return
    end

    vim.ui.select(projects, {
      prompt = "Select a project",
      format_item = function(item)
        if item.active ~= 0 then
          return string.format("Name: %s >> %s (ACTIVE)", item.name, item.dir)
        else
          return string.format("Name: %s >> %s", item.name, item.dir)
        end
      end,
      ---@param choice Project
    }, function(choice)
      if choice ~= nil then
        self:activate_project(choice.project_id)
        vim.cmd("cd " .. choice.dir)
        self:open_project_bufs(choice.project_id)
      end
    end)
  end)
end

---@return integer | nil # project_id matching the current buffer.
function ProjectState:buf_current_project()
  return logger.scope("buf_current_project", function(log)
    local root = buf_current_git_root()
    local sql = [[
      select project_id
      from project
      where dir = '%s'
    ]]
    local sql_with_params = string.format(sql, root)
    log.debug("\n" .. sql_with_params)
    local result_set, error = sqlite.execute_sql(self._dbfile, sql_with_params)
    if error and error ~= "No output" then
      log.error(error)
      return nil
    end
    if result_set == nil then
      return nil
    end

    local project_id = result_set[1].project_id
    log.debug(string.format("Project ID match; %s", project_id))
    return project_id
  end)
end

---@return integer | nil
function ProjectState:active_project_id()
  local sql = [[
      select
        project_id
      from project
      where active = 1;
    ]]
  local result, error = sqlite.execute_sql(self._dbfile, sql)
  if error and error ~= "No output" then
    logger.error(error)
    return nil
  else
    ---@class PartialProj1
    ---@field project_id integer
    local project = result[1]
    return project.project_id
  end
end

---@param project_id integer
function ProjectState:activate_project(project_id)
  logger.scope("activate_project", function(logs)
    local sql = [[
      update project set active = 0;
      update project set active = 1
      where project_id = %s;
      select
        dir
        , name
      from project
      where project_id = %s;
    ]]
    local sql_with_params = string.format(sql, project_id, project_id)
    local result, error = sqlite.execute_sql(self._dbfile, sql_with_params)
    if error and error ~= "No output" then
      logs.error(error)
    else
      ---@type Project
      local project = result[1]
      logs.info(string.format("Swapping to Project: %s", project.name))
      vim.cmd(string.format("cd %s", project.dir))
    end
  end)
end

---@param name string
function ProjectState:set_active_proj_buf(name)
  local match, _ = sqlite.execute_sql(self._dbfile, "select buffer_id from buffer where name = :name", { name = name })
  local pid = self:active_project_id()
  if match == nil then
    sqlite.execute_sql(
      self._dbfile,
      [[
        insert into buffer (name, project_id, active)
        values (:name, :project_id, 1);
      ]],
      { name = name, project_id = pid }
    )
  else
    sqlite.execute_sql(
      self._dbfile,
      [[
        update buffer set active = 0
        where project_id = :pid;
        update buffer set active = 1
        where name = :name;
      ]],
      { name = name, pid = pid }
    )
  end
end

---@param name string
function ProjectState:delete_project_buffer(name)
  sqlite.execute_sql(self._dbfile, "delete from buffer where name = :name", { name = name })
end

---@param name string
---@param row integer
---@param col integer
function ProjectState:save_last_cursor_pos(name, row, col)
  sqlite.execute_sql(
    self._dbfile,
    [[
    update buffer 
    set row = :row
        , col = :col 
    where name = :name;
  ]],
    { name = name, row = row, col = col }
  )
end

-- vim.api.nvim_buf_get_name()
-- vim.fn.getbufinfo()
-- TODO: implement this

function M.setup()
  local fullpath = vim.fs.joinpath(vim.fn.stdpath("data"), "eap-projects.db")
  local state = ProjectState.new(fullpath)
  state:init()

  vim.api.nvim_create_user_command("ProjectCreate", function()
    state:create_project()
  end, {
    desc = "Creates an entry in the projects database.",
  })

  vim.api.nvim_create_user_command("ProjectSelect", function()
    state:select_project()
  end, {
    desc = "Select a project from the projects database.",
  })

  vim.api.nvim_create_user_command("ProjectReset", function()
    state:reset()
    state:init()
  end, {
    desc = "Reset the database to a blank state.",
  })

  vim.api.nvim_create_user_command("ProjectInfo", function()
    state:show_info()
  end, {
    desc = "Show information about the current database state",
  })
  vim.api.nvim_create_user_command("ProjectDeactivate", function()
    state:deactivate()
  end, {
    desc = "Deactivate the current active project.",
  })

  local project_augroup = vim.api.nvim_create_augroup("EapProjects", {})

  vim.api.nvim_create_autocmd("BufEnter", {
    group = project_augroup,
    callback = function()
      local project_id = state:buf_current_project()
      if project_id then
        logger.debug("Attempting to activate project")
        state:activate_project(project_id)
        local name = vim.fn.expand("<afile>:p")
        if vim.uv.fs_stat(name) then
          state:set_active_proj_buf(name)
        end
      else
        logger.debug("No match, not project to activate")
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "BufDelete" }, {
    group = project_augroup,
    callback = function()
      local name = vim.fn.expand("<afile>:p")
      state:delete_project_buffer(name)
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = project_augroup,
    callback = function()
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      local name = vim.api.nvim_buf_get_name(0)
      state:save_last_cursor_pos(name, row, col)
    end,
  })
  -- TODO: Activate Project
  -- Setup a command that allows me to designate a startup project
  -- and have it startup on vim enter. Also a command to deactivate the
  -- startup project

  -- TODO: List All Functions Command in file in telescope
  --
  -- vim.api.nvim_create_autocmd("VimEnter", {
  --   group = project_augroup,
  --   callback = function()
  --     local pid = state:active_project_id()
  --     if pid then
  --       state:open_project_bufs(pid)
  --     end
  --   end,
  -- })
end

return M
