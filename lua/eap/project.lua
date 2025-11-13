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
        id integer primary key autoincrement
        , filepath text
        , is_shown integer
        , project_id integer 
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

---@param dbfile string
---@param project_id integer
local function project_activate(dbfile, project_id)
  logger.scope("project_activate", function(logs)
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
    local result, error = sqlite.execute_sql(dbfile, sql_with_params)
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
        project_activate(self._dbfile, choice.project_id)
        vim.cmd("cd " .. choice.dir)
      end
    end)
  end)
end

local function current_buf_project_match(dbfile)
  return logger.scope("current_buf_project_match", function(log)
    local bufdir = vim.fn.expand("%:p:h")
    local old_cwd = vim.uv.cwd()
    vim.cmd("lcd " .. bufdir)
    local root = find_git_root()
    vim.cmd("lcd " .. old_cwd)
    local sql = [[
      select project_id
      from project
      where dir = '%s'
    ]]
    local sql_with_params = string.format(sql, root)
    log.debug("\n" .. sql_with_params)
    local result_set, error = sqlite.execute_sql(dbfile, sql_with_params)
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
      local match = current_buf_project_match(fullpath)
      if match then
        logger.debug("Attempting to activate project")
        project_activate(fullpath, match)
      else
        logger.debug("No match, not project to activate")
      end
    end,
  })
end

return M
