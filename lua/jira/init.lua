local M = {}

local api = vim.api

local state = require "jira.state"
local render = require "jira.render"
local util = require "jira.util"
local sprint = require("jira.jira-api.sprint")

M.setup = function(opts)
  state.config = vim.tbl_deep_extend("force", state.config, opts or {})
end

M.open = function()
  vim.notify("Loading Dashboard...", vim.log.levels.INFO)
  local issues, err = sprint.get_active_sprint_issues()
  if err then
    vim.notify("Error: " .. err, vim.log.levels.ERROR)
    return
  end
  if #issues == 0 then
    vim.notify("No issues in active sprint.", vim.log.levels.WARN)
    return
  end

  -- Backdrop
  local dim_buf = api.nvim_create_buf(false, true)
  state.dim_win = api.nvim_open_win(dim_buf, false, {
    relative = "editor",
    width = vim.o.columns,
    height = vim.o.lines,
    row = 0,
    col = 0,
    style = "minimal",
    focusable = false,
    zindex = 100,
  })
  api.nvim_win_set_option(state.dim_win, "winblend", 50)
  api.nvim_win_set_option(state.dim_win, "winhighlight", "Normal:JiraDim")
  vim.api.nvim_set_hl(0, "JiraDim", { bg = "#000000" })

  state.buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(state.buf, "bufhidden", "wipe")

  local height = 42
  local width = 160

  state.win = api.nvim_open_win(state.buf, true, {
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2 - 1,

    relative = 'editor',
    style = "minimal",
    border = { " ", " ", " ", " ", " ", " ", " ", " " },
    title = { { " 󱥚 Jira Board ", "StatusLineTerm" } },
    title_pos = "center",
    zindex = 101,
  })

  api.nvim_win_set_hl_ns(state.win, state.ns)
  api.nvim_win_set_option(state.win, "cursorline", true)

  api.nvim_create_autocmd("BufWipeout", {
    buffer = state.buf,
    callback = function()
      if state.dim_win and api.nvim_win_is_valid(state.dim_win) then
        api.nvim_win_close(state.dim_win, true)
        state.dim_win = nil
      end
    end,
  })

  vim.api.nvim_set_hl(0, "JiraTopLevel", {
    link = "CursorLineNr",
    bold = true,
  })

  vim.api.nvim_set_hl(0, "JiraStoryPoint", {
    link = "Error",
    bold = true,
  })

  vim.api.nvim_set_hl(0, "JiraAssignee", {
    link = "MoreMsg",
  })

  vim.api.nvim_set_hl(0, "JiraAssigneeUnassigned", {
    link = "Comment",
    italic = true,
  })

  vim.api.nvim_set_hl(0, "exgreen", {
    fg = "#a6e3a1", -- Green-ish
  })

  vim.api.nvim_set_hl(0, "JiraStatus", {
    link = "lualine_a_insert",
  })

  vim.api.nvim_set_hl(0, "JiraStatusRoot", {
    link = "lualine_a_insert",
    bold = true,
  })

  vim.api.nvim_set_hl(0, "JiraIconBug", { fg = "#f38ba8" }) -- Red
  vim.api.nvim_set_hl(0, "JiraIconStory", { fg = "#a6e3a1" }) -- Green
  vim.api.nvim_set_hl(0, "JiraIconTask", { fg = "#89b4fa" }) -- Blue
  vim.api.nvim_set_hl(0, "JiraIconSubTask", { fg = "#94e2d5" }) -- Teal
  vim.api.nvim_set_hl(0, "JiraIconTest", { fg = "#fab387" }) -- Peach
  vim.api.nvim_set_hl(0, "JiraIconDesign", { fg = "#cba6f7" }) -- Mauve
  vim.api.nvim_set_hl(0, "JiraIconOverhead", { fg = "#9399b2" }) -- Overlay2
  vim.api.nvim_set_hl(0, "JiraIconImp", { fg = "#89dceb" }) -- Sky

  api.nvim_set_current_win(state.win)

  local tree = util.build_issue_tree(issues)
  render.render_issue_tree(tree)
end

return M
