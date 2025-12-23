local M = {}

local api = vim.api

local state = require "jira.state"
local config = require "jira.config"
local render = require "jira.render"
local util = require "jira.util"
local sprint = require("jira.jira-api.sprint")
local ui = require("jira.ui")

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

  set_keymap(km.toggle_node, function() require("jira").toggle_node() end, opts)
  set_keymap(km.toggle_all, function() require("jira").toggle_all_nodes() end, opts)

  -- Tab switching
  local function pick_project_for_view(view_name)
    -- If we have multiple saved projects, always show picker to allow switching
    if #state.my_issues_projects > 1 then
      local current = state.project_key
      vim.ui.select(state.my_issues_projects, {
        prompt = view_name .. " - Select project:",
        format_item = function(item)
          if item == current then
            return item .. " (current)"
          end
          return item
        end,
      }, function(choice)
        if choice then
          require("jira").load_view(choice, view_name)
        end
      end)
    elseif #state.my_issues_projects == 1 then
      require("jira").load_view(state.my_issues_projects[1], view_name)
    elseif state.project_key and state.project_key ~= "" then
      -- No saved projects but have current context
      require("jira").load_view(state.project_key, view_name)
    else
      -- No saved projects, prompt for input
      vim.ui.input({ prompt = "Project key for " .. view_name .. ": " }, function(input)
        if input and input ~= "" then
          require("jira").load_view(input:upper(), view_name)
        end
      end)
    end
  end

  set_keymap(km.my_issues, function()
    if #state.my_issues_projects == 0 then
      vim.notify("No projects configured. Press E to edit projects.", vim.log.levels.WARN)
      return
    end
    require("jira").load_my_issues_view()
  end, opts)
  set_keymap(km.jql, function() require("jira").prompt_jql() end, opts)
  set_keymap(km.sprint, function() pick_project_for_view("Active Sprint") end, opts)
  set_keymap(km.backlog, function() pick_project_for_view("Backlog") end, opts)
  set_keymap(km.help, function() require("jira").load_view(state.project_key, "Help") end, opts)
  set_keymap(km.edit_projects, function() require("jira").prompt_my_issues_projects() end, opts)
  set_keymap(km.edit_issue, function() require("jira").edit_issue() end, opts)
  set_keymap(km.filter, function() require("jira").prompt_filter() end, opts)
  set_keymap(km.clear_filter, function() require("jira").clear_filter() end, opts)
  set_keymap(km.details, function() require("jira").show_issue_details() end, opts)
  set_keymap(km.read_task, function() require("jira").read_task() end, opts)
  set_keymap(km.open_browser, function() require("jira").open_in_browser() end, opts)

  -- Issue actions
  set_keymap(km.change_status, function() require("jira").change_status() end, opts)
  set_keymap(km.create_story, function() require("jira").create_story() end, opts)
  set_keymap(km.close_issue, function() require("jira").close_issue() end, opts)
  set_keymap(km.toggle_resolved, function() require("jira").toggle_resolved() end, opts)

  -- Actions
  set_keymap(km.refresh, function()
    local cache_key = get_cache_key(state.project_key, state.current_view)
    state.cache[cache_key] = nil
    if state.current_view == "My Issues" then
      require("jira").load_my_issues_view()
    else
      require("jira").load_view(state.project_key, state.current_view)
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

      if not issues or #issues == 0 then
        state.tree = {}
        render.clear(state.buf)
        render.render_issue_tree(state.tree, state.current_view)
        vim.notify("No issues found in " .. view_name .. ".", vim.log.levels.WARN)
      else
        state.tree = util.build_issue_tree(issues)
        render.clear(state.buf)
        render.render_issue_tree(state.tree, state.current_view)
        if not cached_issues then
          local msg = project_key
            and ("Loaded " .. view_name .. " for " .. project_key)
            or ("Loaded " .. view_name)
          vim.notify(msg, vim.log.levels.INFO)
        end
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
      local jql = state.custom_jql
      if state.hide_resolved and jql and not jql:lower():find("statuscategory") then
        jql = "(" .. jql .. ") AND statusCategory != Done"
      end
      sprint.get_issues_by_jql(pk, jql, cb)
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

M.prompt_jql = function()
  vim.ui.input({ prompt = "JQL: ", default = state.custom_jql or "" }, function(input)
    if not input or input == "" then return end
    state.custom_jql = input
    state.save()
    M.load_view(state.project_key, "JQL")
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
  local jira_api = require("jira.jira-api.api")
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
  local jira_api = require("jira.jira-api.api")
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

      ui.open_markdown_view("Jira: " .. issue.key, lines)
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

    local jira_api = require("jira.jira-api.api")
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
  vim.ui.input({ prompt = "Append to description: " }, function(input)
    if not input or input == "" then return end

    local jira_api = require("jira.jira-api.api")
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

  local jira_api = require("jira.jira-api.api")

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

  local jira_api = require("jira.jira-api.api")

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
  vim.ui.input({ prompt = "Summary: " }, function(summary)
    if not summary or summary == "" then return end

    vim.ui.input({ prompt = "Description (optional): " }, function(description)
      local jira_api = require("jira.jira-api.api")

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

      -- Get current user's account ID (cached)
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
--   local jira_api = require("jira.jira-api.api")
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

  -- If no project key, open My Issues flow
  if not project_key or project_key == "" then
    -- If we have saved projects, load them directly
    if #state.my_issues_projects > 0 then
      M.load_my_issues_view()
    else
      M.prompt_my_issues_projects()
    end
    return
  end

  M.load_view(project_key, "Active Sprint")
end

return M