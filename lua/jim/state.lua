local data_path = vim.fn.stdpath("data") .. "/jim_nvim.json"

local state = {
  buf = nil,
  win = nil,
  dim_win = nil,
  ns = vim.api.nvim_create_namespace("Jim"),
  status_hls = {},
  tree = {},
  line_map = {},
  project_key = nil,
  current_view = nil,
  custom_jql = nil,
  cache = {},
  my_issues_projects = {},
  cached_projects = nil,
  hide_resolved = true,
  current_filter = nil,
  current_user_account_id = nil,
  assignable_users_cache = {},
  hidden_tabs = {},
  sort_column = nil,
  sort_direction = nil,
  column_header_row = nil,
}

function state.get_assignable_users(project_key)
  local entry = state.assignable_users_cache[project_key]
  if not entry then return nil end
  if os.time() - entry.fetched_at > 86400 then return nil end
  return entry.users
end

function state.set_assignable_users(project_key, users)
  state.assignable_users_cache[project_key] = {
    users = users,
    fetched_at = os.time(),
  }
end

function state.save()
  local data = {
    my_issues_projects = state.my_issues_projects,
    hide_resolved = state.hide_resolved,
    last_jql = state.custom_jql,
    hidden_tabs = state.hidden_tabs,
  }
  local json = vim.json.encode(data)
  local file = io.open(data_path, "w")
  if file then
    file:write(json)
    file:close()
  end
end

function state.load()
  local file = io.open(data_path, "r")
  if file then
    local content = file:read("*a")
    file:close()
    local ok, data = pcall(vim.json.decode, content)
    if ok and data then
      state.my_issues_projects = data.my_issues_projects or {}
      if data.hide_resolved ~= nil then
        state.hide_resolved = data.hide_resolved
      end
      state.custom_jql = data.last_jql
      state.hidden_tabs = data.hidden_tabs or {}
    end
  end
end

-- Load on require
state.load()

return state
