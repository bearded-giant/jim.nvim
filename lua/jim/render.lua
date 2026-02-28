local state = require("jim.state")
local util = require("jim.util")
local ui = require("jim.ui")
local api = vim.api

local MAX = {
  TITLE = 60,
  ASSIGNEE = 10,
  TIME = 7,
  STATUS = 14,
}

local M = {}

local function truncate(str, max)
  if vim.fn.strdisplaywidth(str) <= max then
    return str
  end
  return vim.fn.strcharpart(str, 0, max - 1) .. "…"
end

local function get_totals(node)
  local spent = node.time_spent or 0
  local estimate = node.time_estimate or 0

  for _, child in ipairs(node.children or {}) do
    local s, e = get_totals(child)
    spent = spent + s
    estimate = estimate + e
  end

  return spent, estimate
end

local function render_progress_bar(spent, estimate, width)
  local total = math.max(estimate, spent)
  if total <= 0 then
    return string.rep("▰", width), 0
  end

  local ratio = spent / total
  local filled_len = math.floor(ratio * width)
  filled_len = math.min(width, math.max(0, filled_len))

  local bar = string.rep("▰", filled_len) .. string.rep("▱", width - filled_len)
  return bar, filled_len
end

local function add_hl(hls, start_col, text, hl)
  local width = string.len(text)
  table.insert(hls, {
    start_col = start_col,
    end_col = start_col + width,
    hl = hl,
  })
end

-- ---------------------------------------------
-- Helpers
-- ---------------------------------------------
local function get_issue_icon(node)
  local type = node.type or ""
  if type == "Bug" then
    return "", "JimIconBug"
  elseif type == "Story" then
    return "", "JimIconStory"
  elseif type == "Task" then
    return "", "JimIconTask"
  elseif type == "Sub-task" or type == "Subtask" then
    return "󰙅", "JimIconSubTask"
  elseif type == "Sub-Test" or type == "Sub Test Execution" then
    return "󰙨", "JimIconTest"
  elseif type == "Sub Design" then
    return "󰟶", "JimIconDesign"
  elseif type == "Sub Overhead" then
    return "󱖫", "JimIconOverhead"
  elseif type == "Sub-Imp" then
    return "", "JimIconImp"
  end

  return "●", "JimIconStory"
end

---@param spent number
---@param estimate number
---@return string col1_str
---@return string col1_hl
local function get_time_display_info(spent, estimate)
  local col1_str = ""
  local col1_hl = "Comment"
  local remaining = math.max(0, estimate - spent)

  if estimate == 0 and spent > 0 then
    col1_str = string.format("%s", util.format_time(spent))
    col1_hl = "WarningMsg"
  elseif estimate > 0 then
    col1_str = string.format("%s/%s", util.format_time(spent), util.format_time(estimate))

    if remaining > 0 then
      col1_hl = "Comment"
    else
      local overdue = spent - estimate
      if overdue > 0 then
        col1_hl = "Error"
      else
        col1_str = util.format_time(spent) .. " "
        col1_hl = "exgreen"
      end
    end
  elseif spent == 0 and estimate == 0 then
    col1_str = "-"
    col1_hl = "Comment"
  end

  return col1_str, col1_hl
end

---@param node JiraIssueNode
---@param is_root boolean
---@param bar_width number
---@return string col1_str
---@return string col1_hl
---@return string col2_str
---@return number bar_filled_len
local function get_right_part_info(node, is_root, bar_width)
  local time_str = ""
  local time_hl = "Comment"
  local assignee_str = ""
  local bar_str = ""
  local bar_filled_len = 0

  if is_root then
    local spent, estimate = get_totals(node)
    local bar, filled = render_progress_bar(spent, estimate, bar_width)
    bar_str = bar
    bar_filled_len = filled
    time_str = string.format("%s/%s", util.format_time(spent), util.format_time(math.max(estimate, spent)))
  else
    local spent = node.time_spent or 0
    local estimate = node.time_estimate or 0
    time_str, time_hl = get_time_display_info(spent, estimate)
  end

  local ass = truncate(node.assignee or "Unassigned", MAX.ASSIGNEE - 2)
  assignee_str = " " .. ass

  return time_str, time_hl, assignee_str, bar_str, bar_filled_len
end

-- ---------------------------------------------
-- Render ONE issue line
-- ---------------------------------------------
---@param node JiraIssueNode
---@param depth number
---@param row number
---@return string, table[]
local function render_issue_line(node, depth, row)
  local cols = require("jim.config").options.columns or {}
  local col_widths = {}
  for _, c in ipairs(cols) do col_widths[c.field] = c.width end
  local ASSIGNEE_W = col_widths["assignee"] or MAX.ASSIGNEE
  local TIME_W = col_widths["time"] or MAX.TIME
  local STATUS_W = col_widths["status"] or MAX.STATUS

  local indent = string.rep("    ", depth - 1)
  local icon, icon_hl = get_issue_icon(node)

  local expand_icon = " "
  if node.children and #node.children > 0 then
    expand_icon = node.expanded and "" or ""
  end

  local is_root = depth == 1

  local key = node.key or ""
  local points = node.story_points or node.points
  local pts = ""
  if is_root and points ~= nil and points ~= vim.NIL then
    pts = string.format(" 󰫢 %s", points)
  end

  local status = truncate(node.status or "Unknown", STATUS_W)

  -- build right part first so we know its display width
  local bar_width = 8
  local time_str, time_hl, assignee_str, bar_str, bar_filled_len = get_right_part_info(node, is_root, bar_width)

  local bar_display = bar_str
  if bar_display == "" then
    bar_display = string.rep(" ", bar_width)
  end

  local time_pad = string.rep(" ", TIME_W - vim.fn.strdisplaywidth(time_str))
  local ass_pad = string.rep(" ", ASSIGNEE_W - vim.fn.strdisplaywidth(assignee_str))
  local status_pad = string.rep(" ", STATUS_W - vim.fn.strdisplaywidth(status))
  local status_str = " " .. status .. status_pad .. " "

  local right_part = string.format("%s  %s%s  %s%s  %s", bar_display, time_str, time_pad, assignee_str, ass_pad, status_str)
  local right_dw = vim.fn.strdisplaywidth(right_part)

  -- compute effective title width from remaining space
  local left_prefix = string.format("%s%s %s %s ", indent, expand_icon, icon, key)
  local total_width = api.nvim_win_get_width(state.win or 0)
  local configured_title = col_widths["summary"] or MAX.TITLE
  local available_title = total_width - vim.fn.strdisplaywidth(left_prefix) - vim.fn.strdisplaywidth(pts) - right_dw - 2
  local TITLE_W = math.max(15, math.min(configured_title, available_title))

  local title = truncate(node.summary or "", TITLE_W)

  local highlights = {}
  local col = #indent

  -- LEFT --------------------------------------------------
  local left = string.format("%s%s %s %s %s %s", indent, expand_icon, icon, key, title, pts)

  add_hl(highlights, col, expand_icon, "Comment")
  col = col + #expand_icon + 1

  add_hl(highlights, col, icon, icon_hl)
  col = col + #icon + 1

  add_hl(highlights, col, key, depth == 1 and "Title" or "LineNr")
  col = col + #key + 1

  add_hl(highlights, col, title, depth == 1 and "JimTopLevel" or "Comment")
  col = col + #title + 1

  add_hl(highlights, col, pts, "JimStoryPoint")

  -- RIGHT -------------------------------------------------
  local left_width = vim.fn.strdisplaywidth(left)
  local padding = string.rep(" ", math.max(1, total_width - left_width - vim.fn.strdisplaywidth(right_part) - 1))

  local full_line = left .. padding .. right_part

  local right_col_start = #left + #padding

  -- Highlight Progress Bar
  if is_root then
    local filled_bytes = bar_filled_len * 3
    local empty_bytes = (bar_width - bar_filled_len) * 3
    add_hl(highlights, right_col_start, string.sub(bar_display, 1, filled_bytes), "JimProgressBar")
    add_hl(highlights, right_col_start + filled_bytes,
      string.sub(bar_display, filled_bytes + 1, filled_bytes + empty_bytes), "linenr")
  end

  local current_col = right_col_start + #bar_display + 2

  -- Highlight Time
  if time_str ~= "" then
    add_hl(highlights, current_col, time_str, time_hl)
  end
  current_col = current_col + #time_str + #time_pad + 2

  -- Highlight Assignee
  local ass_hl = (node.assignee == nil or node.assignee == "Unassigned") and "JimAssigneeUnassigned" or "JimAssignee"
  add_hl(highlights, current_col, assignee_str, ass_hl)

  -- Highlight Status
  local right_status_start = current_col + #assignee_str + #ass_pad + 2
  local status_hl = ui.get_status_hl(node.status)
  add_hl(highlights, right_status_start, status_str, status_hl)

  api.nvim_buf_set_lines(state.buf, row, row + 1, false, { full_line })

  for _, h in ipairs(highlights) do
    api.nvim_buf_set_extmark(state.buf, state.ns, row, h.start_col, {
      end_col = h.end_col,
      hl_group = h.hl,
    })
  end

  return full_line, highlights
end

local function format_keys(keys)
  if type(keys) == "table" then
    return table.concat(keys, ", ")
  end
  return keys
end

local function get_effective_summary_width(cols, overhead)
  local win_width = state.win and api.nvim_win_get_width(state.win) or 160
  local fixed = overhead
  local summary_max = MAX.TITLE
  for _, c in ipairs(cols) do
    if c.field == "summary" then
      summary_max = c.width or MAX.TITLE
    else
      fixed = fixed + (c.width or 12) + 2
    end
  end
  local available = win_width - fixed - 2
  return math.max(15, math.min(summary_max, available))
end

local function render_column_header(row)
  local cols = require("jim.config").options.columns or {}
  local hls = {}

  local left_pad = "       "
  local header = left_pad
  local effective_summary = get_effective_summary_width(cols, #left_pad)

  for _, col in ipairs(cols) do
    local label = col.header or col.field
    local width = col.field == "summary" and effective_summary or (col.width or 12)

    if state.sort_column == col.field then
      if state.sort_direction == "asc" then
        label = label .. " ▲"
      else
        label = label .. " ▼"
      end
    end

    local padded = label .. string.rep(" ", math.max(0, width - vim.fn.strdisplaywidth(label)))
    local start_col = #header
    header = header .. padded .. "  "

    table.insert(hls, {
      start_col = start_col,
      end_col = start_col + #padded,
      hl = state.sort_column == col.field and "Title" or "Comment",
    })
  end

  api.nvim_buf_set_lines(state.buf, row, row + 1, false, { header })
  for _, h in ipairs(hls) do
    api.nvim_buf_set_extmark(state.buf, state.ns, row, h.start_col, {
      end_col = h.end_col,
      hl_group = h.hl,
    })
  end

  state.column_header_row = row
end

local function render_header(view)
  local config = require("jim.config")
  local km = config.options.keymaps

  local tabs = {
    { name = "My Issues", key = format_keys(km.my_issues) },
    { name = "JQL", key = format_keys(km.jql) },
    { name = "Active Sprint", key = format_keys(km.sprint) },
    { name = "Backlog", key = format_keys(km.backlog) },
    { name = "Help", key = format_keys(km.help) },
  }

  local visible_tabs = {}
  for _, tab in ipairs(tabs) do
    if tab.name == "My Issues" or tab.name == "Help" or not state.hidden_tabs[tab.name] then
      table.insert(visible_tabs, tab)
    end
  end

  local header = "  "
  local hls = {}

  for _, tab in ipairs(visible_tabs) do
    local is_active = (view == tab.name)
    local tab_str = string.format(" %s (%s) ", tab.name, tab.key)
    local start_col = #header
    header = header .. tab_str .. "  "

    table.insert(hls, {
      start_col = start_col,
      end_col = start_col + #tab_str,
      hl = is_active and "JimTabActive" or "JimTabInactive",
    })
  end

  -- Show active filter if present
  local filter_line = ""
  if state.current_filter and state.current_filter ~= "" then
    filter_line = "  Filter: " .. state.current_filter .. "  (press " .. format_keys(km.clear_filter) .. " to clear)"
  end

  api.nvim_buf_set_lines(state.buf, 0, -1, false, { header, filter_line })
  for _, h in ipairs(hls) do
    api.nvim_buf_set_extmark(state.buf, state.ns, 0, h.start_col, {
      end_col = h.end_col,
      hl_group = h.hl,
    })
  end

  -- Highlight filter line
  if filter_line ~= "" then
    api.nvim_buf_set_extmark(state.buf, state.ns, 1, 0, {
      end_col = #filter_line,
      hl_group = "WarningMsg",
    })
  end
end

function M.render_help(view)
  render_header(view)
  local config = require("jim.config")
  local km = config.options.keymaps

  local sections = {
    { title = "Views", items = {
      { k = format_keys(km.my_issues), d = "My Issues (cross-project)" },
      { k = format_keys(km.sprint), d = "Active Sprint" },
      { k = format_keys(km.backlog), d = "Backlog" },
      { k = format_keys(km.next_tab) .. " / " .. format_keys(km.prev_tab), d = "Cycle tabs" },
      { k = format_keys(km.toggle_tabs), d = "Toggle tab visibility" },
      { k = format_keys(km.edit_projects), d = "Edit saved projects" },
    }},
    { title = "JQL", items = {
      { k = format_keys(km.jql), d = "Run last JQL query" },
      { k = format_keys(km.jql_input), d = "History / new query" },
    }},
    { title = "Navigation", items = {
      { k = format_keys(km.toggle_node), d = "Expand / collapse node" },
      { k = format_keys(km.toggle_all), d = "Expand / collapse all" },
      { k = format_keys(km.filter), d = "Filter by summary" },
      { k = format_keys(km.clear_filter), d = "Clear filter" },
      { k = format_keys(km.toggle_resolved), d = "Show/hide resolved" },
    }},
    { title = "Issue Actions", items = {
      { k = format_keys(km.edit_issue), d = "Edit issue" },
      { k = format_keys(km.change_status), d = "Change status" },
      { k = format_keys(km.assign_user), d = "Assign user" },
      { k = format_keys(km.create_story), d = "Create new story" },
      { k = format_keys(km.close_issue), d = "Close issue (Done)" },
    }},
    { title = "Issue Details", items = {
      { k = format_keys(km.details), d = "Details popup" },
      { k = format_keys(km.read_task), d = "Read as markdown" },
      { k = format_keys(km.open_browser), d = "Open in browser" },
      { k = format_keys(km.yank_key), d = "Copy key to clipboard" },
    }},
    { title = "Display", items = {
      { k = format_keys(km.sort_column), d = "Sort by column" },
      { k = format_keys(km.toggle_columns), d = "Toggle columns" },
    }},
    { title = "Export", items = {
      { k = format_keys(km.export_csv), d = "Export to CSV" },
      { k = format_keys(km.export_markdown), d = "Export to markdown" },
    }},
    { title = "General", items = {
      { k = format_keys(km.refresh), d = "Refresh view" },
      { k = format_keys(km.help), d = "This help" },
      { k = format_keys(km.close), d = "Close board" },
    }},
  }

  -- line height per section: title + separator + items + blank
  local function section_height(s) return 2 + #s.items + 1 end

  -- split sections into two columns, balanced by line count
  local total = 0
  for _, s in ipairs(sections) do total = total + section_height(s) end
  local left, right = {}, {}
  local left_h = 0
  for _, s in ipairs(sections) do
    if left_h <= total / 2 then
      table.insert(left, s)
      left_h = left_h + section_height(s)
    else
      table.insert(right, s)
    end
  end

  -- render one column into an array of {text, hls} per line
  -- hls entries are {start_col, end_col, hl} relative to the column
  local function render_column(col_sections)
    local col_lines = {}
    for _, section in ipairs(col_sections) do
      -- title
      table.insert(col_lines, {
        text = section.title,
        hls = {{ start_col = 0, end_col = #section.title, hl = "Label" }},
      })
      -- separator
      local sep = string.rep("─", 38)
      table.insert(col_lines, {
        text = sep,
        hls = {{ start_col = 0, end_col = #sep, hl = "Comment" }},
      })
      -- items
      for _, item in ipairs(section.items) do
        local line = string.format("  %-16s %s", item.k, item.d)
        table.insert(col_lines, {
          text = line,
          hls = {{ start_col = 2, end_col = 2 + #item.k, hl = "Special" }},
        })
      end
      -- blank line
      table.insert(col_lines, { text = "", hls = {} })
    end
    return col_lines
  end

  local left_col = render_column(left)
  local right_col = render_column(right)

  local win_width = state.win and api.nvim_win_get_width(state.win) or 160
  local col_width = math.floor((win_width - 6) / 2) -- 2 margin + 2 gutter + 2 margin
  local gutter = 4

  local row_count = math.max(#left_col, #right_col)
  local lines = { "" }
  local hls = {}

  for i = 1, row_count do
    local l = left_col[i]
    local r = right_col[i]
    local l_text = l and l.text or ""
    local r_text = r and r.text or ""

    -- pad left column to fixed width
    local padded = l_text .. string.rep(" ", col_width - vim.fn.strdisplaywidth(l_text))
    local line = "  " .. padded .. string.rep(" ", gutter) .. r_text
    table.insert(lines, line)

    local buf_row = 2 + #lines - 1
    local left_offset = 2

    if l then
      for _, h in ipairs(l.hls) do
        table.insert(hls, {
          row = buf_row,
          start_col = left_offset + h.start_col,
          end_col = left_offset + h.end_col,
          hl = h.hl,
        })
      end
    end

    if r then
      local right_offset = 2 + col_width + gutter
      for _, h in ipairs(r.hls) do
        table.insert(hls, {
          row = buf_row,
          start_col = right_offset + h.start_col,
          end_col = right_offset + h.end_col,
          hl = h.hl,
        })
      end
    end
  end

  api.nvim_buf_set_lines(state.buf, 2, -1, false, lines)
  for _, h in ipairs(hls) do
    api.nvim_buf_set_extmark(state.buf, state.ns, h.row, h.start_col, {
      end_col = h.end_col,
      hl_group = h.hl,
    })
  end

  api.nvim_buf_set_option(state.buf, "modifiable", false)
end

-- ---------------------------------------------
-- Render TREE into buffer
-- ---------------------------------------------
---@param issues JiraIssueNode[]
---@param view string?
---@param depth number?
---@param row number?
---@return number
function M.render_issue_tree(issues, view, depth, row)
  depth = depth or 1
  row = row or 2

  if depth == 1 then
    state.line_map = {}
    if view then
      render_header(view)
    end
    render_column_header(row)
    row = row + 1
  end

  for i, node in ipairs(issues) do
    if depth == 1 and i > 1 then
      api.nvim_buf_set_lines(state.buf, row, row + 1, false, { "" })
      row = row + 1
    end

    state.line_map[row] = node
    render_issue_line(node, depth, row)
    row = row + 1

    if node.children and #node.children > 0 and node.expanded then
      row = M.render_issue_tree(node.children, view, depth + 1, row)
    end
  end

  if depth == 1 then
    api.nvim_buf_set_option(state.buf, "modifiable", false)
  end

  return row
end

-- ---------------------------------------------
-- Clear buffer
-- ---------------------------------------------
function M.clear(buf)
  api.nvim_buf_set_option(buf, "modifiable", true)
  api.nvim_buf_clear_namespace(buf, state.ns, 0, -1)
  api.nvim_buf_set_lines(buf, 0, -1, false, {})
end

return M
