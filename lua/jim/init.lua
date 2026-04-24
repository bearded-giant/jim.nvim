local M = {}

local api = vim.api

local state = require "jim.state"
local config = require "jim.config"
local render = require "jim.render"
local util = require "jim.util"
local sprint = require("jim.jira-api.sprint")
local ui = require("jim.ui")

M.setup = function(opts)
  config.setup(opts)
end

M.toggle_node = function()
  local cursor = api.nvim_win_get_cursor(state.win)
  local row = cursor[1] - 1
  local node = state.line_map[row]

  if node and node.children and #node.children > 0 then
    node.expanded = not node.expanded
    render.clear(state.buf)
    render.render_issue_tree(state.tree, state.current_view)

    local line_count = api.nvim_buf_line_count(state.buf)
    if cursor[1] > line_count then
      cursor[1] = line_count
    end
    api.nvim_win_set_cursor(state.win, cursor)
  end
end

M.toggle_all_nodes = function()
  -- Determine target state: if any node is expanded, collapse all; otherwise expand all
  local any_expanded = false
  local function check_expanded(nodes)
    for _, node in ipairs(nodes) do
      if node.children and #node.children > 0 then
        if node.expanded then
          any_expanded = true
          return
        end
        check_expanded(node.children)
      end
    end
  end
  check_expanded(state.tree)

  local target = not any_expanded
  local function set_expanded(nodes)
    for _, node in ipairs(nodes) do
      if node.children and #node.children > 0 then
        node.expanded = target
        set_expanded(node.children)
      end
    end
  end
  set_expanded(state.tree)

  local cursor = api.nvim_win_get_cursor(state.win)
  render.clear(state.buf)
  render.render_issue_tree(state.tree, state.current_view)

  local line_count = api.nvim_buf_line_count(state.buf)
  if cursor[1] > line_count then
    cursor[1] = line_count
  end
  api.nvim_win_set_cursor(state.win, cursor)
end

local function get_cache_key(project_key, view_name)
  if view_name == "My Issues" then
    local sorted = vim.tbl_map(function(p) return p end, state.my_issues_projects)
    table.sort(sorted)
    local key = "global:MyIssues:" .. table.concat(sorted, ",")
    if state.current_filter and state.current_filter ~= "" then
      key = key .. ":filter:" .. state.current_filter
    end
    return key
  end
  if view_name == "JQL" then
    -- JQL queries are global, not project-specific
    local key = "global:JQL:" .. (state.custom_jql or "")
    if state.current_filter and state.current_filter ~= "" then
      key = key .. ":filter:" .. state.current_filter
    end
    return key
  end
  local key = (project_key or "unknown") .. ":" .. view_name
  if state.current_filter and state.current_filter ~= "" then
    key = key .. ":filter:" .. state.current_filter
  end
  return key
end

-- Helper to set keymap from config (handles string or table of keys)
local function set_keymap(keys, fn, opts)
  if type(keys) == "table" then
    for _, key in ipairs(keys) do
      vim.keymap.set("n", key, fn, opts)
    end
  else
    vim.keymap.set("n", keys, fn, opts)
  end
end

M.setup_keymaps = function()
  local opts = { noremap = true, silent = true, buffer = state.buf }
  local km = config.options.keymaps

  set_keymap(km.toggle_node, function() require("jim").toggle_node() end, opts)
  set_keymap(km.toggle_all, function() require("jim").toggle_all_nodes() end, opts)

  -- skip empty lines between issues
  local function jump_to_issue(direction)
    local cursor = api.nvim_win_get_cursor(state.win)
    local row = cursor[1] - 1 -- 0-indexed
    local line_count = api.nvim_buf_line_count(state.buf)
    local pos = row + direction
    while pos >= 0 and pos < line_count do
      if state.line_map[pos] then
        api.nvim_win_set_cursor(state.win, { pos + 1, cursor[2] })
        return
      end
      pos = pos + direction
    end
  end

  for _, key in ipairs({ "j", "<Down>" }) do
    vim.keymap.set("n", key, function() jump_to_issue(1) end, opts)
  end
  for _, key in ipairs({ "k", "<Up>" }) do
    vim.keymap.set("n", key, function() jump_to_issue(-1) end, opts)
  end

  -- Tab switching
  local function pick_project_for_view(view_name)
    local projects = state.my_issues_projects or {}
    local default = state.project_key or ""

    vim.ui.input({
      prompt = view_name .. " - Project key: ",
      default = default,
      completion = "customlist,v:lua._jim_complete_projects",
    }, function(input)
      if not input or input == "" then return end
      require("jim").load_view(input:upper(), view_name)
    end)
  end

  _G._jim_complete_projects = function(arg_lead)
    local projects = state.my_issues_projects or {}
    if arg_lead == "" then return projects end
    local lead = arg_lead:upper()
    return vim.tbl_filter(function(p) return p:upper():find(lead, 1, true) end, projects)
  end

  set_keymap(km.my_issues, function()
    if #state.my_issues_projects == 0 then
      vim.notify("No projects configured. Press E to edit projects.", vim.log.levels.WARN)
      return
    end
    require("jim").load_my_issues_view()
  end, opts)
  set_keymap(km.jql, function()
    if state.custom_jql and state.custom_jql ~= "" then
      require("jim").load_view(state.project_key, "JQL")
    else
      require("jim").prompt_jql()
    end
  end, opts)
  set_keymap(km.jql_input, function() require("jim").prompt_jql_history() end, opts)
  set_keymap(km.sprint, function() pick_project_for_view("Active Sprint") end, opts)
  set_keymap(km.backlog, function() pick_project_for_view("Backlog") end, opts)
  set_keymap(km.help, function() require("jim").load_view(state.project_key, "Help") end, opts)
  set_keymap(km.edit_projects, function() require("jim").prompt_my_issues_projects() end, opts)
  set_keymap(km.edit_issue, function() require("jim").edit_issue() end, opts)
  set_keymap(km.filter, function() require("jim").prompt_filter() end, opts)
  set_keymap(km.clear_filter, function() require("jim").clear_filter() end, opts)
  set_keymap(km.details, function() require("jim").show_issue_details() end, opts)
  set_keymap(km.read_task, function() require("jim").read_task() end, opts)
  set_keymap(km.open_browser, function() require("jim").open_in_browser() end, opts)
  set_keymap(km.yank_key, function() require("jim").yank_key() end, opts)
  set_keymap(km.export_csv, function() require("jim").export_csv() end, opts)
  set_keymap(km.export_markdown, function() require("jim").export_markdown() end, opts)

  -- tab cycling with arrow keys
  local tab_order = { "My Issues", "JQL", "Active Sprint", "Backlog", "Help" }

  local function cycle_tab(direction)
    local visible_order = vim.tbl_filter(function(name)
      return name == "My Issues" or name == "Help" or not state.hidden_tabs[name]
    end, tab_order)

    local current = state.current_view or "Help"
    local idx = 1
    for i, name in ipairs(visible_order) do
      if name == current then idx = i break end
    end
    idx = idx + direction
    if idx < 1 then idx = #visible_order end
    if idx > #visible_order then idx = 1 end
    local target = visible_order[idx]

    if target == "My Issues" then
      if #state.my_issues_projects > 0 then
        require("jim").load_my_issues_view()
      else
        vim.notify("No projects configured. Press E to edit projects.", vim.log.levels.WARN)
      end
    elseif target == "JQL" then
      if state.custom_jql and state.custom_jql ~= "" then
        require("jim").load_view(state.project_key, "JQL")
      else
        require("jim").prompt_jql()
      end
    elseif target == "Active Sprint" or target == "Backlog" then
      pick_project_for_view(target)
    elseif target == "Help" then
      require("jim").load_view(state.project_key, "Help")
    end
  end

  set_keymap(km.next_tab, function() cycle_tab(1) end, opts)
  set_keymap(km.prev_tab, function() cycle_tab(-1) end, opts)
  set_keymap(km.toggle_tabs, function() require("jim").toggle_tab_visibility() end, opts)

  set_keymap(km.sort_column, function() require("jim").sort_by_column() end, opts)
  set_keymap(km.toggle_columns, function() require("jim").toggle_columns() end, opts)

  -- Issue actions
  set_keymap(km.assign_user, function() require("jim").assign_user() end, opts)
  set_keymap(km.change_status, function() require("jim").change_status() end, opts)
  set_keymap(km.create_story, function() require("jim").create_story() end, opts)
  set_keymap(km.close_issue, function() require("jim").close_issue() end, opts)
  set_keymap(km.toggle_resolved, function() require("jim").toggle_resolved() end, opts)

  -- Actions
  set_keymap(km.refresh, function()
    local cache_key = get_cache_key(state.project_key, state.current_view)
    state.cache[cache_key] = nil
    if state.current_view == "My Issues" then
      require("jim").load_my_issues_view()
    else
      require("jim").load_view(state.project_key, state.current_view)
    end
  end, opts)

  set_keymap(km.close, function()
    if state.win and api.nvim_win_is_valid(state.win) then
      -- Check if this is the last window
      local wins = vim.tbl_filter(function(w)
        return api.nvim_win_get_config(w).relative == ""
      end, api.nvim_list_wins())
      if #wins <= 1 then
        -- Create empty buffer before closing to avoid E444
        vim.cmd("enew")
      end
      if state.dim_win and api.nvim_win_is_valid(state.dim_win) then
        api.nvim_win_close(state.dim_win, true)
        state.dim_win = nil
      end
      api.nvim_win_close(state.win, true)
    end
  end, opts)
end

M.load_view = function(project_key, view_name)
  state.project_key = project_key
  state.current_view = view_name

  if view_name == "Help" then
    vim.schedule(function()
      if not state.win or not api.nvim_win_is_valid(state.win) then
        ui.create_window()
        ui.setup_static_highlights()
      end
      state.tree = {}
      state.line_map = {}
      render.clear(state.buf)
      render.render_help(view_name)
      M.setup_keymaps()
    end)
    return
  end

  local cache_key = get_cache_key(project_key, view_name)
  local cached_issues = state.cache[cache_key]

  local function process_issues(issues)
    vim.schedule(function()
      ui.stop_loading()

      -- Setup UI if not already created
      if not state.win or not api.nvim_win_is_valid(state.win) then
        ui.create_window()
        ui.setup_static_highlights()
      end

      -- client-side filtering for JQL view (don't mutate the user's query)
      if view_name == "JQL" and state.hide_resolved and issues then
        issues = vim.tbl_filter(function(i) return i.status_category ~= "Done" end, issues)
      end

      if not issues or #issues == 0 then
        state.tree = {}
        render.clear(state.buf)
        render.render_issue_tree(state.tree, state.current_view)
        vim.notify("No issues found in " .. view_name .. ".", vim.log.levels.WARN)
      else
        state.tree = util.build_issue_tree(issues)
        render.clear(state.buf)
        render.render_issue_tree(state.tree, state.current_view)
      end

      M.setup_keymaps()
    end)
  end

  if cached_issues then
    process_issues(cached_issues)
    return
  end

  local loading_msg = project_key
    and ("Loading " .. view_name .. " for " .. project_key .. "...")
    or ("Loading " .. view_name .. "...")
  ui.start_loading(loading_msg)

  local fetch_fn
  local filter = state.current_filter
  if view_name == "Active Sprint" then
    fetch_fn = function(pk, cb) sprint.get_active_sprint_issues(pk, filter, cb) end
  elseif view_name == "Backlog" then
    fetch_fn = function(pk, cb) sprint.get_backlog_issues(pk, filter, cb) end
  elseif view_name == "JQL" then
    fetch_fn = function(pk, cb)
      sprint.get_issues_by_jql(pk, state.custom_jql, cb)
    end
  end

  fetch_fn(project_key, function(issues, err)
    if err then
      vim.schedule(function()
        ui.stop_loading()
        vim.notify("Error: " .. err, vim.log.levels.ERROR)
      end)
      return
    end

    state.cache[cache_key] = issues
    process_issues(issues)
  end)
end

M.prompt_jql = function(default_query)
  local default = default_query or state.custom_jql or ""
  local height = math.max(12, math.floor(vim.o.lines * 0.4))
  local width = math.max(80, math.floor(vim.o.columns * 0.7))
  ui.open_text_input("JQL", { default = default, height = height, width = width }, function(input)
    if not input or input == "" then return end
    local jql = input:gsub("\n", " "):gsub("%s+", " ")
    state.custom_jql = jql
    state.push_jql_history(jql)
    state.save()
    M.load_view(state.project_key, "JQL")
  end)
end

M.prompt_jql_history = function()
  local history = state.jql_history or {}
  if #history == 0 then
    M.prompt_jql()
    return
  end

  local items = {}
  table.insert(items, "[New Query]")
  for _, q in ipairs(history) do
    table.insert(items, q)
  end

  vim.ui.select(items, {
    prompt = "JQL History:",
    format_item = function(item)
      if item == "[New Query]" then return "  New Query" end
      if #item > 80 then return item:sub(1, 77) .. "..." end
      return item
    end,
  }, function(choice)
    if not choice then return end
    if choice == "[New Query]" then
      M.prompt_jql("")
    else
      M.prompt_jql(choice)
    end
  end)
end

M.prompt_filter = function()
  vim.ui.input({ prompt = "Filter (summary ~): ", default = state.current_filter or "" }, function(input)
    if input == nil then return end -- cancelled
    state.current_filter = input ~= "" and input or nil
    -- Refresh current view with filter
    if state.current_view == "My Issues" then
      M.load_my_issues_view()
    elseif state.current_view and state.project_key then
      M.load_view(state.project_key, state.current_view)
    end
  end)
end

M.clear_filter = function()
  if not state.current_filter then
    vim.notify("No filter active", vim.log.levels.INFO)
    return
  end
  state.current_filter = nil
  vim.notify("Filter cleared", vim.log.levels.INFO)
  -- Refresh current view
  if state.current_view == "My Issues" then
    M.load_my_issues_view()
  elseif state.current_view and state.project_key then
    M.load_view(state.project_key, state.current_view)
  end
end

M.show_issue_details = function()
  local cursor = api.nvim_win_get_cursor(state.win)
  local row = cursor[1] - 1
  local node = state.line_map[row]
  if not node or not node.key then return end

  ui.start_loading("Fetching details for " .. node.key .. "...")
  local jira_api = require("jim.jira-api.api")
  jira_api.get_issue(node.key, function(issue, err)
    vim.schedule(function()
      ui.stop_loading()
      if err then
        vim.notify("Error: " .. err, vim.log.levels.ERROR)
        return
      end
      ui.show_issue_details_popup(issue)
    end)
  end)
end

M.read_task = function()
  local cursor = api.nvim_win_get_cursor(state.win)
  local row = cursor[1] - 1
  local node = state.line_map[row]
  if not node or not node.key then return end

  ui.start_loading("Fetching full details for " .. node.key .. "...")
  local jira_api = require("jim.jira-api.api")
  jira_api.get_issue(node.key, function(issue, err)
    vim.schedule(function()
      ui.stop_loading()
      if err then
        vim.notify("Error: " .. err, vim.log.levels.ERROR)
        return
      end

      local fields = issue.fields or {}
      local lines = {}
      table.insert(lines, "# " .. issue.key .. ": " .. (fields.summary or ""))
      table.insert(lines, "")
      table.insert(lines, "**Status**: " .. (fields.status and fields.status.name or "Unknown"))
      table.insert(lines, "**Assignee**: " .. (fields.assignee and fields.assignee.displayName or "Unassigned"))
      table.insert(lines, "**Priority**: " .. (fields.priority and fields.priority.name or "None"))
      table.insert(lines, "")
      table.insert(lines, "## Description")
      table.insert(lines, "")

      if fields.description then
        local md = util.adf_to_markdown(fields.description)
        for line in md:gmatch("[^\r\n]+") do
          table.insert(lines, line)
        end
      else
        table.insert(lines, "_No description_")
      end

      local p_config = config.get_project_config(state.project_key)
      local ac_field = p_config.acceptance_criteria_field
      if ac_field and fields[ac_field] then
        table.insert(lines, "")
        table.insert(lines, "## Acceptance Criteria")
        table.insert(lines, "")
        local ac_md = util.adf_to_markdown(fields[ac_field])
        for line in ac_md:gmatch("[^\r\n]+") do
          table.insert(lines, line)
        end
      end

      ui.open_markdown_view("Jim: " .. issue.key, lines)
    end)
  end)
end

M.export_csv = function()
  if not state.tree or #state.tree == 0 then
    vim.notify("No issues to export", vim.log.levels.WARN)
    return
  end

  local rows = {}
  local function collect(nodes)
    for _, node in ipairs(nodes) do
      local created = node.created or ""
      if created:find("T") then created = created:match("^([^T]+)") or created end
      table.insert(rows, string.format("%s,%s,%s,%s,%s,%s,%s",
        node.key or "",
        '"' .. (node.summary or ""):gsub('"', '""') .. '"',
        node.status or "",
        node.type or "",
        node.assignee or "Unassigned",
        node.reporter or "Unknown",
        created
      ))
      if node.children then collect(node.children) end
    end
  end

  table.insert(rows, "key,summary,status,type,assignee,reporter,created")
  collect(state.tree)

  local filename = "jim_export.csv"
  local f = io.open(filename, "w")
  if not f then
    vim.notify("Failed to write " .. filename, vim.log.levels.ERROR)
    return
  end
  f:write(table.concat(rows, "\n") .. "\n")
  f:close()
  vim.notify("Exported " .. (#rows - 1) .. " issues to " .. filename, vim.log.levels.INFO)
end

M.export_markdown = function()
  local cursor = api.nvim_win_get_cursor(state.win)
  local row = cursor[1] - 1
  local node = state.line_map[row]
  if not node or not node.key then return end

  ui.start_loading("Fetching full details for " .. node.key .. "...")
  local jira_api = require("jim.jira-api.api")
  jira_api.get_issue(node.key, function(issue, err)
    vim.schedule(function()
      ui.stop_loading()
      if err then
        vim.notify("Error: " .. err, vim.log.levels.ERROR)
        return
      end

      local fields = issue.fields or {}
      local lines = {}
      table.insert(lines, "# " .. issue.key .. ": " .. (fields.summary or ""))
      table.insert(lines, "")
      table.insert(lines, "**Status**: " .. (fields.status and fields.status.name or "Unknown"))
      table.insert(lines, "**Assignee**: " .. (fields.assignee and fields.assignee.displayName or "Unassigned"))
      table.insert(lines, "**Reporter**: " .. (fields.reporter and fields.reporter.displayName or "Unknown"))
      table.insert(lines, "**Priority**: " .. (fields.priority and fields.priority.name or "None"))
      table.insert(lines, "**Created**: " .. (fields.created or ""))
      table.insert(lines, "")
      table.insert(lines, "## Description")
      table.insert(lines, "")

      if fields.description then
        local md = util.adf_to_markdown(fields.description)
        for line in md:gmatch("[^\r\n]+") do
          table.insert(lines, line)
        end
      else
        table.insert(lines, "_No description_")
      end

      local p_config = config.get_project_config(state.project_key)
      local ac_field = p_config.acceptance_criteria_field
      if ac_field and fields[ac_field] then
        table.insert(lines, "")
        table.insert(lines, "## Acceptance Criteria")
        table.insert(lines, "")
        local ac_md = util.adf_to_markdown(fields[ac_field])
        for line in ac_md:gmatch("[^\r\n]+") do
          table.insert(lines, line)
        end
      end

      local filename = issue.key .. ".md"
      local f = io.open(filename, "w")
      if not f then
        vim.notify("Failed to write " .. filename, vim.log.levels.ERROR)
        return
      end
      f:write(table.concat(lines, "\n") .. "\n")
      f:close()
      vim.notify("Exported to " .. filename, vim.log.levels.INFO)
    end)
  end)
end

M.open_in_browser = function()
  local cursor = api.nvim_win_get_cursor(state.win)
  local row = cursor[1] - 1
  local node = state.line_map[row]
  if not node or not node.key then return end

  local base = config.options.jira.base
  if not base or base == "" then
    vim.notify("Jira base URL is not configured", vim.log.levels.ERROR)
    return
  end

  if not base:match("/$") then
    base = base .. "/"
  end

  local url = base .. "browse/" .. node.key
  vim.ui.open(url)
end

M.yank_key = function()
  local cursor = api.nvim_win_get_cursor(state.win)
  local row = cursor[1] - 1
  local node = state.line_map[row]
  if not node or not node.key then return end

  vim.fn.setreg("+", node.key)
  vim.fn.setreg('"', node.key)
  vim.notify("Copied: " .. node.key, vim.log.levels.INFO)
end

M.assign_user = function()
  local cursor = api.nvim_win_get_cursor(state.win)
  local row = cursor[1] - 1
  local node = state.line_map[row]
  if not node or not node.key then
    vim.notify("No issue under cursor", vim.log.levels.WARN)
    return
  end

  local project = state.project_key or (node.key:match("^(%u+)%-"))

  local function show_picker(users)
    local items = { { accountId = nil, displayName = "Unassigned" } }
    for _, u in ipairs(users) do
      table.insert(items, u)
    end

    vim.ui.select(items, {
      prompt = "Assign " .. node.key .. " to:",
      format_item = function(item)
        local label = item.displayName or "Unknown"
        if item.accountId and item.accountId == node.assignee_account_id then
          label = label .. " (current)"
        end
        return label
      end,
    }, function(choice)
      if not choice then return end

      local fields = {}
      if choice.accountId then
        fields.assignee = { accountId = choice.accountId }
      else
        fields.assignee = vim.NIL
      end

      local jira_api = require("jim.jira-api.api")
      ui.start_loading("Assigning...")
      jira_api.update_issue(node.key, fields, function(_, err)
        vim.schedule(function()
          ui.stop_loading()
          if err then
            vim.notify("Assignment failed: " .. err, vim.log.levels.ERROR)
            return
          end
          local name = choice.displayName or "Unassigned"
          vim.notify(node.key .. " -> " .. name, vim.log.levels.INFO)
          refresh_current_view()
        end)
      end)
    end)
  end

  local cached = state.get_assignable_users(project)
  if cached then
    show_picker(cached)
    return
  end

  local jira_api = require("jim.jira-api.api")
  ui.start_loading("Fetching assignable users...")
  jira_api.get_assignable_users(project, function(users, err)
    vim.schedule(function()
      ui.stop_loading()
      if err then
        vim.notify("Error: " .. err, vim.log.levels.ERROR)
        return
      end
      state.set_assignable_users(project, users)
      show_picker(users)
    end)
  end)
end

-- Helper to refresh current view after updates
local function refresh_current_view()
  local cache_key = get_cache_key(state.project_key, state.current_view)
  state.cache[cache_key] = nil
  if state.current_view == "My Issues" then
    M.load_my_issues_view()
  elseif state.current_view and state.project_key then
    M.load_view(state.project_key, state.current_view)
  end
end

M._edit_summary = function(node)
  vim.ui.input({ prompt = "Summary: ", default = node.summary }, function(input)
    if not input or input == "" or input == node.summary then return end

    local jira_api = require("jim.jira-api.api")
    ui.start_loading("Updating summary...")
    jira_api.update_issue(node.key, { summary = input }, function(success, err)
      vim.schedule(function()
        ui.stop_loading()
        if err then
          vim.notify("Update failed: " .. err, vim.log.levels.ERROR)
          return
        end
        vim.notify(node.key .. " summary updated", vim.log.levels.INFO)
        refresh_current_view()
      end)
    end)
  end)
end

M._append_description = function(node)
  ui.open_text_input("Append to " .. node.key .. " description", { filetype = "markdown" }, function(input)
    if not input or input == "" then return end

    local jira_api = require("jim.jira-api.api")
    ui.start_loading("Fetching current description...")
    jira_api.get_issue(node.key, function(issue, err)
      if err then
        vim.schedule(function()
          ui.stop_loading()
          vim.notify("Failed to fetch issue: " .. err, vim.log.levels.ERROR)
        end)
        return
      end

      vim.schedule(function()
        local current_adf = issue.fields and issue.fields.description
        local new_adf = jira_api.append_to_adf(current_adf, input)

        jira_api.update_issue(node.key, { description = new_adf }, function(success, u_err)
          vim.schedule(function()
            ui.stop_loading()
            if u_err then
              vim.notify("Update failed: " .. u_err, vim.log.levels.ERROR)
              return
            end
            vim.notify(node.key .. " description updated", vim.log.levels.INFO)
            refresh_current_view()
          end)
        end)
      end)
    end)
  end)
end

M.edit_issue = function()
  local cursor = api.nvim_win_get_cursor(state.win)
  local row = cursor[1] - 1
  local node = state.line_map[row]
  if not node or not node.key then
    vim.notify("No issue under cursor", vim.log.levels.WARN)
    return
  end

  vim.ui.select({
    { key = "summary", label = "Edit Summary" },
    { key = "description", label = "Append to Description" },
    { key = "status", label = "Change Status" },
  }, {
    prompt = "Edit " .. node.key .. ":",
    format_item = function(item) return item.label end,
  }, function(choice)
    if not choice then return end
    if choice.key == "summary" then
      M._edit_summary(node)
    elseif choice.key == "description" then
      M._append_description(node)
    elseif choice.key == "status" then
      M.change_status()
    end
  end)
end

M.change_status = function()
  local cursor = api.nvim_win_get_cursor(state.win)
  local row = cursor[1] - 1
  local node = state.line_map[row]
  if not node or not node.key then
    vim.notify("No issue under cursor", vim.log.levels.WARN)
    return
  end

  local jira_api = require("jim.jira-api.api")

  ui.start_loading("Fetching transitions...")
  jira_api.get_transitions(node.key, function(transitions, err)
    vim.schedule(function()
      ui.stop_loading()
      if err then
        vim.notify("Error: " .. err, vim.log.levels.ERROR)
        return
      end

      if not transitions or #transitions == 0 then
        vim.notify("No transitions available for " .. node.key, vim.log.levels.WARN)
        return
      end

      vim.ui.select(transitions, {
        prompt = "Transition " .. node.key .. " to:",
        format_item = function(item)
          return item.name
        end,
      }, function(choice)
        if not choice then return end

        ui.start_loading("Transitioning...")
        jira_api.transition_issue(node.key, choice.id, function(success, t_err)
          vim.schedule(function()
            ui.stop_loading()
            if t_err then
              vim.notify("Transition failed: " .. t_err, vim.log.levels.ERROR)
              return
            end
            vim.notify(node.key .. " -> " .. choice.name, vim.log.levels.INFO)

            local cache_key = get_cache_key(state.project_key, state.current_view)
            state.cache[cache_key] = nil
            if state.current_view == "My Issues" then
              M.load_my_issues_view()
            else
              M.load_view(state.project_key, state.current_view)
            end
          end)
        end)
      end)
    end)
  end)
end

M.close_issue = function()
  local cursor = api.nvim_win_get_cursor(state.win)
  local row = cursor[1] - 1
  local node = state.line_map[row]
  if not node or not node.key then
    vim.notify("No issue under cursor", vim.log.levels.WARN)
    return
  end

  local jira_api = require("jim.jira-api.api")

  ui.start_loading("Finding done transition...")
  jira_api.get_transitions(node.key, function(transitions, err)
    vim.schedule(function()
      ui.stop_loading()
      if err then
        vim.notify("Error: " .. err, vim.log.levels.ERROR)
        return
      end

      local done_transition = nil
      for _, t in ipairs(transitions or {}) do
        local name_upper = (t.name or ""):upper()
        if name_upper:find("DONE") or name_upper:find("CLOSED") or name_upper:find("RESOLVED") or name_upper:find("COMPLETE") then
          done_transition = t
          break
        end
      end

      if not done_transition then
        vim.notify("No 'Done' transition found. Use 's' to see all transitions.", vim.log.levels.WARN)
        return
      end

      ui.start_loading("Closing issue...")
      jira_api.transition_issue(node.key, done_transition.id, function(success, t_err)
        vim.schedule(function()
          ui.stop_loading()
          if t_err then
            vim.notify("Failed to close: " .. t_err, vim.log.levels.ERROR)
            return
          end
          vim.notify(node.key .. " -> " .. done_transition.name, vim.log.levels.INFO)

          local cache_key = get_cache_key(state.project_key, state.current_view)
          state.cache[cache_key] = nil
          if state.current_view == "My Issues" then
            M.load_my_issues_view()
          else
            M.load_view(state.project_key, state.current_view)
          end
        end)
      end)
    end)
  end)
end

M._prompt_and_create_story = function(project_key)
  -- single buffer form: title above ---, description below
  ui.open_text_input("New Story (" .. project_key .. ") | title above --- | description below", {
    filetype = "markdown",
    default = "\n---\n",
  }, function(input)
    if not input then return end

    local lines = vim.split(input, "\n", { plain = true })
    local summary_parts = {}
    local desc_lines = {}
    local past_separator = false

    for _, line in ipairs(lines) do
      if not past_separator then
        if line:match("^%-%-%-") then
          past_separator = true
        else
          table.insert(summary_parts, line)
        end
      else
        table.insert(desc_lines, line)
      end
    end

    local summary = vim.trim(table.concat(summary_parts, " "))
    local description = vim.trim(table.concat(desc_lines, "\n"))

    if summary == "" then
      vim.notify("Title is required", vim.log.levels.WARN)
      return
    end
    if description == "" then
      vim.notify("Description is required", vim.log.levels.WARN)
      return
    end

    local jira_api = require("jim.jira-api.api")

    local function do_create(account_id)
      ui.start_loading("Creating story...")

      local opts = {
        description = description,
        assignee_account_id = account_id,
      }

      jira_api.create_issue(project_key, summary, "Story", opts, function(result, err)
        vim.schedule(function()
          ui.stop_loading()
          if err then
            vim.notify("Failed to create: " .. err, vim.log.levels.ERROR)
            return
          end
          vim.notify("Created " .. result.key .. ": " .. summary, vim.log.levels.INFO)

          local cache_key = get_cache_key(state.project_key, state.current_view)
          state.cache[cache_key] = nil
          if state.current_view == "Backlog" then
            M.load_view(state.project_key, state.current_view)
          elseif state.current_view == "My Issues" then
            local my_cache_key = get_cache_key(nil, "My Issues")
            state.cache[my_cache_key] = nil
            M.load_my_issues_view()
          end
        end)
      end)
    end

    if state.current_user_account_id then
      do_create(state.current_user_account_id)
    else
      jira_api.get_myself(function(user, err)
        vim.schedule(function()
          if err or not user or not user.accountId then
            vim.notify("Could not get current user, creating unassigned", vim.log.levels.WARN)
            do_create(nil)
            return
          end
          state.current_user_account_id = user.accountId
          do_create(user.accountId)
        end)
      end)
    end
  end)
end

M.create_story = function()
  if state.current_view == "My Issues" then
    if #state.my_issues_projects == 0 then
      vim.notify("No projects configured", vim.log.levels.WARN)
      return
    elseif #state.my_issues_projects == 1 then
      M._prompt_and_create_story(state.my_issues_projects[1])
    else
      vim.ui.select(state.my_issues_projects, {
        prompt = "Create story in project:",
      }, function(selected_project)
        if not selected_project then return end
        M._prompt_and_create_story(selected_project)
      end)
    end
  else
    local project = state.project_key
    if not project or project == "" then
      vim.notify("No project context", vim.log.levels.WARN)
      return
    end
    M._prompt_and_create_story(project)
  end
end

M.load_my_issues_view = function()
  if #state.my_issues_projects == 0 then
    vim.notify("No projects selected. Press M to configure.", vim.log.levels.WARN)
    return
  end

  state.current_view = "My Issues"

  local cache_key = get_cache_key(nil, "My Issues")
  local cached_issues = state.cache[cache_key]

  local function process_issues(issues)
    vim.schedule(function()
      ui.stop_loading()
      if not state.win or not api.nvim_win_is_valid(state.win) then
        ui.create_window()
        ui.setup_static_highlights()
      end

      if not issues or #issues == 0 then
        state.tree = {}
        render.clear(state.buf)
        render.render_issue_tree(state.tree, state.current_view)
        vim.notify("No issues found.", vim.log.levels.WARN)
      else
        state.tree = util.build_issue_tree(issues)
        render.clear(state.buf)
        render.render_issue_tree(state.tree, state.current_view)
      end
      M.setup_keymaps()
    end)
  end

  if cached_issues then
    process_issues(cached_issues)
    return
  end

  local project_list = table.concat(state.my_issues_projects, ", ")
  local jql
  if state.hide_resolved then
    jql = string.format("assignee = currentUser() AND project IN (%s) AND statusCategory != Done", project_list)
  else
    jql = string.format("assignee = currentUser() AND project IN (%s)", project_list)
  end

  if state.current_filter and state.current_filter ~= "" then
    jql = jql .. string.format(" AND summary ~ \"%s\"", state.current_filter)
  end

  jql = jql .. " ORDER BY updated DESC"
  ui.start_loading("Loading My Issues...")

  sprint.get_issues_by_jql(state.my_issues_projects[1], jql, function(issues, err)
    print("My Issues callback - err: " .. tostring(err) .. ", issues: " .. tostring(issues and #issues or "nil"))
    if err then
      vim.schedule(function()
        ui.stop_loading()
        vim.notify("Error: " .. err, vim.log.levels.ERROR)
      end)
      return
    end
    state.cache[cache_key] = issues
    process_issues(issues)
  end)
end

M.toggle_resolved = function()
  state.hide_resolved = not state.hide_resolved
  state.save()
  local status = state.hide_resolved and "hidden" or "shown"
  vim.notify("Resolved issues: " .. status, vim.log.levels.INFO)
  -- Clear cache and refresh
  local cache_key = get_cache_key(state.project_key, state.current_view)
  state.cache[cache_key] = nil
  if state.current_view == "My Issues" then
    M.load_my_issues_view()
  elseif state.current_view == "JQL" then
    M.load_view(nil, "JQL")
  elseif state.current_view and state.project_key then
    M.load_view(state.project_key, state.current_view)
  end
end

-- TODO: Project picker from API (commented out due to permissions issues)
-- M._show_project_picker = function(projects)
--   local selected = {}
--   for _, p in ipairs(state.my_issues_projects) do
--     selected[p] = true
--   end
--   vim.ui.select(projects, {
--     prompt = "Select project to add/remove (current: " .. table.concat(state.my_issues_projects, ", ") .. "). Esc to confirm.",
--     format_item = function(item)
--       local marker = selected[item.key] and "[x] " or "[ ] "
--       return marker .. item.key .. " - " .. item.name
--     end,
--   }, function(choice)
--     if not choice then
--       if #state.my_issues_projects > 0 then
--         local cache_key = get_cache_key(nil, "My Issues")
--         state.cache[cache_key] = nil
--         M.load_my_issues_view()
--       end
--       return
--     end
--     if selected[choice.key] then selected[choice.key] = nil else selected[choice.key] = true end
--     state.my_issues_projects = {}
--     for key, _ in pairs(selected) do table.insert(state.my_issues_projects, key) end
--     table.sort(state.my_issues_projects)
--     M._show_project_picker(projects)
--   end)
-- end

M.prompt_my_issues_projects = function()
  local default = table.concat(state.my_issues_projects, ", ")
  vim.ui.input({ prompt = "Projects (comma-separated): ", default = default }, function(input)
    if not input then return end
    if input == "" then
      state.my_issues_projects = {}
      state.save()
      vim.notify("My Issues projects cleared", vim.log.levels.INFO)
      return
    end
    state.my_issues_projects = {}
    for _, p in ipairs(vim.split(input, ",", { trimempty = true })) do
      table.insert(state.my_issues_projects, vim.trim(p):upper())
    end
    state.save()
    local cache_key = get_cache_key(nil, "My Issues")
    state.cache[cache_key] = nil
    M.load_my_issues_view()
  end)
end

-- TODO: Re-enable when project browse permissions are available
-- M.prompt_my_issues_projects_with_fetch = function()
--   if state.cached_projects and #state.cached_projects > 0 then
--     M._show_project_picker(state.cached_projects)
--     return
--   end
--   local jira_api = require("jim.jira-api.api")
--   vim.notify("Fetching projects...", vim.log.levels.INFO)
--   jira_api.get_projects(function(projects, err)
--     vim.schedule(function()
--       if err then
--         vim.notify("Error fetching projects: " .. err, vim.log.levels.ERROR)
--         return
--       end
--       if not projects or #projects == 0 then
--         vim.notify("No projects found. Check your Jira credentials.", vim.log.levels.WARN)
--         return
--       end
--       state.cached_projects = projects
--       M._show_project_picker(projects)
--     end)
--   end)
-- end

M.sort_by_column = function()
  local cols = config.options.columns or {}
  local items = {}
  for _, col in ipairs(cols) do
    table.insert(items, { field = col.field, label = col.header or col.field })
  end

  vim.ui.select(items, {
    prompt = "Sort by:",
    format_item = function(item)
      local indicator = ""
      if state.sort_column == item.field then
        indicator = state.sort_direction == "asc" and " ▲" or " ▼"
      end
      return item.label .. indicator
    end,
  }, function(choice)
    if not choice then return end

    if state.sort_column == choice.field then
      if state.sort_direction == "asc" then
        state.sort_direction = "desc"
      elseif state.sort_direction == "desc" then
        state.sort_column = nil
        state.sort_direction = nil
      end
    else
      state.sort_column = choice.field
      state.sort_direction = "asc"
    end

    if state.sort_column then
      util.sort_tree(state.tree, state.sort_column, state.sort_direction)
    end

    render.clear(state.buf)
    render.render_issue_tree(state.tree, state.current_view)
  end)
end

M.toggle_columns = function()
  local available = {
    { field = "key", header = "Key" },
    { field = "summary", header = "Title" },
    { field = "assignee", header = "Assignee" },
    { field = "time", header = "Time" },
    { field = "status", header = "Status" },
    { field = "priority", header = "Priority" },
    { field = "reporter", header = "Reporter" },
    { field = "story_points", header = "Points" },
    { field = "type", header = "Type" },
  }

  local active = {}
  for _, c in ipairs(config.options.columns or {}) do
    active[c.field] = true
  end

  local function show_picker()
    vim.ui.select(available, {
      prompt = "Toggle columns (Esc to finish):",
      format_item = function(item)
        local marker = active[item.field] and "[x]" or "[ ]"
        return marker .. " " .. item.header
      end,
    }, function(choice)
      if not choice then
        local new_cols = {}
        for _, a in ipairs(available) do
          if active[a.field] then
            local width = 12
            if a.field == "summary" then width = 60
            elseif a.field == "status" then width = 14
            elseif a.field == "time" then width = 10
            end
            table.insert(new_cols, { field = a.field, header = a.header, width = width })
          end
        end
        config.options.columns = new_cols
        render.clear(state.buf)
        render.render_issue_tree(state.tree, state.current_view)
        return
      end

      if active[choice.field] then
        active[choice.field] = nil
      else
        active[choice.field] = true
      end
      show_picker()
    end)
  end

  show_picker()
end

M.toggle_tab_visibility = function()
  local hideable = { "JQL", "Active Sprint", "Backlog" }

  local function show_picker()
    local items = {}
    for _, name in ipairs(hideable) do
      local hidden = state.hidden_tabs[name] or false
      table.insert(items, { name = name, hidden = hidden })
    end

    vim.ui.select(items, {
      prompt = "Toggle tab visibility (Esc to finish):",
      format_item = function(item)
        local marker = item.hidden and "[ ]" or "[x]"
        return marker .. " " .. item.name
      end,
    }, function(choice)
      if not choice then
        state.save()
        if state.hidden_tabs[state.current_view] then
          if #state.my_issues_projects > 0 then
            M.load_my_issues_view()
          else
            M.load_view(state.project_key, "Help")
          end
        else
          render.clear(state.buf)
          render.render_issue_tree(state.tree, state.current_view)
        end
        return
      end
      if state.hidden_tabs[choice.name] then
        state.hidden_tabs[choice.name] = nil
      else
        state.hidden_tabs[choice.name] = true
      end
      show_picker()
    end)
  end

  show_picker()
end

M.open = function(project_key)
  -- If already open, just focus
  if state.win and api.nvim_win_is_valid(state.win) then
    api.nvim_set_current_win(state.win)
    return
  end

  -- Validate Config
  local jc = config.options.jira
  if not jc.base or jc.base == "" or not jc.email or jc.email == "" or not jc.token or jc.token == "" then
    vim.notify("Jira configuration is missing. Please run setup() with base, email, and token.", vim.log.levels.ERROR)
    return
  end

  -- restore last view if no explicit project key
  if not project_key or project_key == "" then
    local last = state.last_view
    if last == "JQL" and state.custom_jql and state.custom_jql ~= "" then
      M.load_view(state.project_key, "JQL")
    elseif last == "My Issues" and #state.my_issues_projects > 0 then
      M.load_my_issues_view()
    elseif (last == "Active Sprint" or last == "Backlog") and (state.project_key or state.last_project_key) then
      M.load_view(state.project_key or state.last_project_key, last)
    elseif #state.my_issues_projects > 0 then
      M.load_my_issues_view()
    else
      M.prompt_my_issues_projects()
    end
    return
  end

  M.load_view(project_key, "Active Sprint")
end

return M