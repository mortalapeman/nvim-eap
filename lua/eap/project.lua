local M = {}

local sqlite = require("eap.sqlite")
local logging = require("eap.logging")

local logger = logging.get_logger("eap.project")

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
local function projects(dbfile)
  local sql = "select project_id, name, dir from project;"
  local result, error = sqlite.execute_sql(dbfile, sql)
  if error and error ~= "No output" then
    logger.error(error)
    return nil
  end
  return result
end

local function project_activate(dbfile, project_id)
  local sql = [[
    update project set active = 0;
    update project set active = 1
    where project_id = %s;
  ]]
  local sql_with_params = string.format(sql, project_id)
  local _, error = sqlite.execute_sql(dbfile, sql_with_params)
  if error and error ~= "No output" then
    logger.error(error)
  end
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
    local all_projects = projects(dbfile)
    if all_projects == nil then
      logs.warn("No projects found")
      return
    end

    vim.ui.select(all_projects, {
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

local dbfile_name = "test.db"

vim.fn.delete(dbfile_name)
initialize_db(dbfile_name)
create_project(dbfile_name)
select_project(dbfile_name)

return M
