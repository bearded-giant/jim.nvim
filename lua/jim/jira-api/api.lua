-- api.lua: Jira REST API client using curl
local config = require("jim.config")
local M = {}

-- Get environment variables
local function get_env()
  return config.options.jira
end

-- Validate environment variables
local function validate_env()
  local env = get_env()
  if not env.base or not env.email or not env.token then
    vim.notify(
      "Missing Jira environment variables. Please check your setup.",
      vim.log.levels.ERROR
    )
    return false
  end
  return true
end

-- Execute curl command asynchronously
local function curl_request(method, endpoint, data, callback)
  if not validate_env() then
    if callback then callback(nil, "Missing environment variables") end
    return
  end

  local env = get_env()
  local url = env.base .. endpoint
  local auth = env.email .. ":" .. env.token

  -- Build curl command
  local cmd = string.format(
    'curl -s -X %s -H "Content-Type: application/json" -H "Accept: application/json" -u "%s" ',
    method,
    auth
  )

  if data then
    local json_data = vim.json.encode(data)
    -- Escape quotes for shell
    json_data = json_data:gsub('"', '\\"')
    cmd = cmd .. string.format('-d "%s" ',
      json_data)
  end

  cmd = cmd .. string.format('"%s"', url)

  local stdout = {}
  local stderr = {}

  vim.fn.jobstart(cmd, {
    on_stdout = function(_, d, _) 
      for _, chunk in ipairs(d) do
        if chunk ~= "" then table.insert(stdout, chunk) end
      end
    end,
    on_stderr = function(_, d, _) 
      for _, chunk in ipairs(d) do
        if chunk ~= "" then table.insert(stderr, chunk) end
      end
    end,
    on_exit = function(_, code, _) 
      if code ~= 0 then
        if callback then callback(nil, "Curl failed: " .. table.concat(stderr, "\n")) end
        return
      end

      local response = table.concat(stdout, "")
      if not response or response == "" then
        if callback then callback(nil, "Empty response from Jira") end
        return
      end

      -- Parse JSON
      local ok, result = pcall(vim.json.decode, response)
      if not ok then
        if callback then callback(nil, "Failed to parse JSON: " .. tostring(result) .. " | Resp: " .. response) end
        return
      end

      if callback then callback(result, nil) end
    end,
  })
end

-- Search for issues using JQL
function M.search_issues(jql, page_token, max_results, fields, callback, project_key)
  local p_config = config.get_project_config(project_key)
  local story_point_field = p_config.story_point_field
  fields = fields or { "summary", "status", "parent", "priority", "assignee", "timespent", "timeoriginalestimate", "issuetype", story_point_field }

  local data = {
    jql = jql,
    fields = fields,
    nextPageToken = page_token or "",
    maxResults = max_results or 100,
  }

  curl_request("POST", "/rest/api/3/search/jql", data, callback)
end

-- Get available transitions for an issue
function M.get_transitions(issue_key, callback)
  curl_request("GET", "/rest/api/3/issue/" .. issue_key .. "/transitions", nil, function(result, err)
    if err then
      if callback then callback(nil, err) end
      return
    end
    if callback then callback(result.transitions or {}, nil) end
  end)
end

-- Transition an issue to a new status
function M.transition_issue(issue_key, transition_id, callback)
  local data = {
    transition = {
      id = transition_id,
    },
  }

  curl_request("POST", "/rest/api/3/issue/" .. issue_key .. "/transitions", data, function(result, err)
    if err then
      if callback then callback(nil, err) end
      return
    end
    if callback then callback(true, nil) end
  end)
end

-- Add worklog to an issue
function M.add_worklog(issue_key, time_spent, callback)
  local data = {
    timeSpent = time_spent,
  }

  curl_request("POST", "/rest/api/3/issue/" .. issue_key .. "/worklog", data, function(result, err)
    if err then
      if callback then callback(nil, err) end
      return
    end
    if callback then callback(true, nil) end
  end)
end

-- Get issue details
function M.get_issue(issue_key, callback)
  curl_request("GET", "/rest/api/3/issue/" .. issue_key, nil, callback)
end

-- Get statuses for a project
function M.get_project_statuses(project, callback)
  curl_request("GET", "/rest/api/3/project/" .. project .. "/statuses", nil, callback)
end

-- Get all projects (may return empty if user lacks browse permissions)
function M.get_projects(callback)
  curl_request("GET", "/rest/api/3/project/search?maxResults=100&orderBy=name", nil, function(result, err)
    if err then
      if callback then callback(nil, err) end
      return
    end
    if callback then callback(result.values or {}, nil) end
  end)
end

-- Get current user info
function M.get_myself(callback)
  curl_request("GET", "/rest/api/3/myself", nil, callback)
end

-- Convert plain text to ADF format
local function text_to_adf(text)
  if not text or text == "" then
    return nil
  end

  local paragraphs = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    if line == "" then
      table.insert(paragraphs, {
        type = "paragraph",
        content = {},
      })
    else
      table.insert(paragraphs, {
        type = "paragraph",
        content = {
          { type = "text", text = line },
        },
      })
    end
  end

  return {
    type = "doc",
    version = 1,
    content = paragraphs,
  }
end

-- Append text to existing ADF document
function M.append_to_adf(existing_adf, text)
  local new_paragraphs = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    if line == "" then
      table.insert(new_paragraphs, {
        type = "paragraph",
        content = {},
      })
    else
      table.insert(new_paragraphs, {
        type = "paragraph",
        content = {
          { type = "text", text = line },
        },
      })
    end
  end

  if not existing_adf or not existing_adf.content then
    return {
      type = "doc",
      version = 1,
      content = new_paragraphs,
    }
  end

  -- Append to existing
  local combined = vim.deepcopy(existing_adf)
  for _, p in ipairs(new_paragraphs) do
    table.insert(combined.content, p)
  end
  return combined
end

-- Update an existing issue
function M.update_issue(issue_key, fields, callback)
  curl_request("PUT", "/rest/api/3/issue/" .. issue_key, { fields = fields }, function(result, err)
    if err then
      if callback then callback(nil, err) end
      return
    end
    -- PUT returns 204 No Content on success (result may be empty)
    if callback then callback(true, nil) end
  end)
end

-- Create a new issue
function M.create_issue(project_key, summary, issue_type, opts, callback)
  opts = opts or {}

  local fields = {
    project = { key = project_key },
    summary = summary,
    issuetype = { name = issue_type or "Story" },
  }

  if opts.description and opts.description ~= "" then
    fields.description = text_to_adf(opts.description)
  end

  if opts.assignee_account_id then
    fields.assignee = { accountId = opts.assignee_account_id }
  end

  local data = { fields = fields }

  curl_request("POST", "/rest/api/3/issue", data, function(result, err)
    if err then
      if callback then callback(nil, err) end
      return
    end
    if callback then callback(result, nil) end
  end)
end

return M