local sqlite = require("eap.sqlite")

local M = {}

local logger = require("eap.logging").get_logger("eap.project")

---@class Project
---@field project_id integer
---@field dir string
---@field name string
---@field active 0 | 1

local function initialize_db(dbfile)
  if not sqlite.table_exists(dbfile, "project") then
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
    local _, error = sqlite.execute_sql(dbfile, sql)
    if error and error ~= "No output" then
      logger.error(error)
    end
  end
end

local function project_add(dbfile, project_name, dir)
  local sql = [[
    insert into project (dir, name)
    values ('%s', '%s');
  ]]
  local sql_with_params = string.format(sql, dir, project_name)
  local _, error = sqlite.execute_sql(dbfile, sql_with_params)
  if error and error ~= "No output" then
    logger.error(error)
  end
end

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

local function find_git_root()
  return vim.fn.trim(vim.fn.system("git rev-parse --show-toplevel"))
end

local function create_project(dbfile)
  logger.scope("create_project", function(logs)
    vim.ui.input({
      prompt = "Project Name: ",
    }, function(name)
      if name ~= nil then
        local git_root = find_git_root()
        project_add(dbfile, name, git_root)
      else
        logs.debug("No project")
      end
    end)
  end)
end

local function select_project(dbfile)
  logger.scope("select_project", function(logs)
    local all_inactive_proj = inactive_projects(dbfile)
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
        project_activate(dbfile, choice.project_id)
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

function M.setup()
  local dbfilename = "eap-projects.db"
  local fullpath = vim.fs.joinpath(vim.fn.stdpath("data"), dbfilename)
  initialize_db(fullpath)

  vim.api.nvim_create_user_command("CreateProject", function()
    create_project(fullpath)
  end, {
    desc = "Creates an entry in the projects database.",
  })

  vim.api.nvim_create_autocmd("BufEnter", {
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
