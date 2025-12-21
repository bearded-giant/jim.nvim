local M = {}

local config = require "jira.config"
local render = require "jira.render"
local util = require "jira.util"
local sprint = require("jira.jira-api.sprint")
local ui = require("jira.ui")

M.setup = function(opts)
  config.setup(opts)
end

M.open = function(project_key)
  -- Validate Config
  local jc = config.options.jira
  if not jc.base or jc.base == "" or not jc.email or jc.email == "" or not jc.token or jc.token == "" then
    vim.notify("Jira configuration is missing. Please run setup() with base, email, and token.", vim.log.levels.ERROR)
    return
  end

  if not project_key then
    project_key = vim.fn.input("Jira Project Key: ")
  end

  if not project_key or project_key == "" then
    vim.notify("Project key is required", vim.log.levels.ERROR)
    return
  end

  vim.notify("Loading Dashboard for " .. project_key .. "...", vim.log.levels.INFO)
  local issues, err = sprint.get_active_sprint_issues(project_key)
  if err then
    vim.notify("Error: " .. err, vim.log.levels.ERROR)
    return
  end
  if #issues == 0 then
    vim.notify("No issues in active sprint.", vim.log.levels.WARN)
    return
  end

  vim.notify("Loaded Dashboard for " .. project_key .. "...", vim.log.levels.INFO)

  -- Fetch Status Colors
  local api_client = require("jira.jira-api.api")
  local project_statuses, st_err = api_client.get_project_statuses(project_key)

  -- Setup UI
  ui.create_window()
  ui.setup_static_highlights()
  if not st_err and project_statuses then
    ui.setup_highlights(project_statuses)
  end

  local tree = util.build_issue_tree(issues)
  render.render_issue_tree(tree)
end

return M

