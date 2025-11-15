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
local function inactive_projects(dbfile)
  local sql = "select project_id, name, dir from project where active = 0;"
  local result, error = sqlite.execute_sql(dbfile, sql)
  if error and error ~= "No output" then
    logger.error(error)
    return nil
  end
  return result
end

function ProjectState:select_project()
  logger.scope("select_project", function(logs)
    local all_inactive_proj = inactive_projects(self._dbfile)
    if all_inactive_proj == nil then
      logs.warn("No projects found")
      return
    end

    vim.ui.select(all_inactive_proj, {
      prompt = "Select a project",
      format_item = function(item)
        return string.format("Name: %s >> %s", item.name, item.dir)
      end,
      ---@param choice Project
    }, function(choice)
      if choice ~= nil then
        self:activate_project(choice.project_id)
        vim.cmd("cd " .. choice.dir)
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
  if match == nil then
    sqlite.execute_sql(
      self._dbfile,
      [[
        insert into buffer (name, project_id, active)
        values (:name, :project_id, 1);
      ]],
      { name = name, project_id = self:active_project_id() }
    )
  else
    sqlite.execute_sql(
      self._dbfile,
      "update buffer set active = 0; update buffer set active = 1 where name = :name;",
      { name = name }
    )
  end
end

---@param name string
function ProjectState:delete_project_buffer(name)
  sqlite.execute_sql(self._dbfile, "delete from buffer where name = :name", { name = name })
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
end

return M
