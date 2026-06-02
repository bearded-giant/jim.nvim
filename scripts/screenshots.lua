-- screenshot init script for jim.nvim
-- usage: nvim --clean -u scripts/screenshots.lua -c 'lua JimScreenshot("sprint")'
-- renders views with mock data, no jira credentials needed

local script_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
local plugin_dir = vim.fn.fnamemodify(script_dir, ":h")

vim.opt.rtp:prepend(plugin_dir)
vim.opt.termguicolors = true
vim.o.background = "dark"
vim.o.laststatus = 0
vim.o.cmdheight = 0
vim.o.showmode = false
vim.o.ruler = false
vim.o.showcmd = false

-- catppuccin mocha palette applied to core highlight groups
-- the plugin reads from these for dynamic status colors
vim.cmd([[
  hi Normal       guibg=#1e1e2e guifg=#cdd6f4
  hi NormalFloat  guibg=#1e1e2e guifg=#cdd6f4
  hi FloatBorder  guifg=#6c7086 guibg=#1e1e2e
  hi CursorLine   guibg=#313244
  hi CurSearch    guibg=#f9e2af guifg=#1e1e2e
  hi Search       guibg=#45475a guifg=#cdd6f4
  hi Comment      guifg=#6c7086
  hi Title        guifg=#cdd6f4 gui=bold
  hi CursorLineNr guifg=#f9e2af
  hi LineNr       guifg=#6c7086
  hi Function     guifg=#89b4fa
  hi Special      guifg=#cba6f7
  hi Label        guifg=#89b4fa gui=bold
  hi WarningMsg   guifg=#f9e2af
  hi Error        guifg=#f38ba8
  hi ErrorMsg     guifg=#f38ba8
  hi MoreMsg      guifg=#a6e3a1
  hi String       guifg=#a6e3a1
  hi Identifier   guifg=#89dceb
  hi Constant     guifg=#fab387
  hi StatusLine   guibg=#313244 guifg=#cdd6f4
  hi StatusLineTerm guibg=#45475a guifg=#cdd6f4 gui=bold
  hi DiagnosticOk   guifg=#a6e3a1
  hi DiagnosticInfo guifg=#89b4fa
  hi DiagnosticWarn guifg=#f9e2af
  hi DiagnosticError guifg=#f38ba8
]])

local mock = dofile(script_dir .. "/mock_data.lua")

require("jim").setup({
  jira = {
    base = "https://acme.atlassian.net",
    email = "dev@acme.co",
    token = "mock-token",
  },
})

local state = require("jim.state")

-- prevent writes to real state file
state.save = function() end
state.load = function() end

state.my_issues_projects = { "ACME", "PLAT" }
state.hide_resolved = true

local jql_query = 'status = "In Progress" AND updated >= -7d'
state.custom_jql = jql_query

-- pre-populate caches so load_view never hits the api
state.cache["ACME:Active Sprint"] = mock.sprint
state.cache["ACME:Backlog"] = mock.backlog
state.cache["global:MyIssues:ACME,PLAT"] = mock.my_issues
state.cache["global:JQL:" .. jql_query] = mock.jql

local jim = require("jim")
local render = require("jim.render")
local util = require("jim.util")
local ui = require("jim.ui")
local config = require("jim.config")

local function expand_first_parent()
  for _, node in ipairs(state.tree) do
    if node.children and #node.children > 0 then
      node.expanded = true
      break
    end
  end
end

local function rerender()
  render.clear(state.buf)
  render.render_issue_tree(state.tree, state.current_view)
end

local mock_issue = {
  key = "ACME-42",
  fields = {
    summary = "User authentication overhaul",
    status = { name = "In Progress" },
    assignee = { displayName = "Sarah Chen" },
    created = "2026-05-12T09:30:00.000+0000",
    sprint = { name = "Sprint 24 - Auth & Payments" },
    description = {
      type = "doc", version = 1,
      content = {
        { type = "paragraph", content = {
          { type = "text", text = "Replace the legacy session cookie flow with OAuth2 and short-lived JWTs." },
        } },
        { type = "paragraph", content = {
          { type = "text", text = "Includes refresh-token rotation and migrating existing sessions on first login." },
        } },
      },
    },
  },
}

-- post-render mutations to showcase interactive features without driving vim.ui.select
local actions = {
  sort = function()
    state.sort_column = "status"
    state.sort_direction = "asc"
    util.sort_tree(state.tree, "status", "asc")
    rerender()
  end,
  columns = function()
    config.options.columns = {
      { field = "key",          header = "Key",      width = 10 },
      { field = "summary",      header = "Title",    width = 44 },
      { field = "type",         header = "Type",     width = 10 },
      { field = "priority",     header = "Priority", width = 10 },
      { field = "story_points", header = "Points",   width = 8 },
      { field = "status",       header = "Status",   width = 14 },
    }
    rerender()
  end,
  details = function()
    ui.show_issue_details_popup(mock_issue)
  end,
  create = function()
    ui.open_text_input(
      "New Story (ACME) | title above --- | description below",
      {
        filetype = "markdown",
        default = "Add CSV export to the backlog view\n---\nUsers want to export the current backlog to CSV for standup sharing.\n\n- include key, summary, status, points\n- respect the active filter",
      },
      function() end
    )
  end,
}

function _G.JimScreenshot(view)
  local views = {
    sprint    = { project = "ACME", name = "Active Sprint" },
    backlog   = { project = "ACME", name = "Backlog" },
    my_issues = { project = nil,    name = "My Issues" },
    jql       = { project = nil,    name = "JQL" },
    help      = { project = "ACME", name = "Help" },
    sort      = { project = "ACME", name = "Active Sprint", after = "sort" },
    columns   = { project = "ACME", name = "Active Sprint", after = "columns" },
    details   = { project = "ACME", name = "Active Sprint", after = "details" },
    create    = { project = "ACME", name = "Active Sprint", after = "create" },
  }

  local v = views[view]
  if not v then
    print("unknown view: " .. view)
    print("options: sprint, backlog, my_issues, jql, help, sort, columns, details, create")
    return
  end

  if v.name == "My Issues" then
    jim.load_my_issues_view()
  else
    jim.load_view(v.project, v.name)
  end

  -- expand first parent node so the screenshot shows hierarchy
  if v.name ~= "Help" then
    vim.defer_fn(function()
      expand_first_parent()
      rerender()
      if v.after and actions[v.after] then
        actions[v.after]()
      end
    end, 150)
  end
end
