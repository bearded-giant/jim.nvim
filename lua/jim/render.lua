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

-- width of the tree prefix (expand icon + type icon) reserved before the first
-- column; render_column_header pads its label row by the same amount so header
-- and body columns line up
local PREFIX_W = 7

local function priority_hl(p)
  if p == "Highest" or p == "High" then return "Error" end
  if p == "Medium" then return "WarningMsg" end
  return "Comment"
end

-- one cell's content as a list of {text, hl} segments (unpadded)
local function build_cell(node, field, is_root, width, has_points_col)
  if field == "key" then
    return { { text = node.key or "", hl = is_root and "Title" or "LineNr" } }
  elseif field == "summary" then
    local title = truncate(node.summary or "", width - (is_root and 6 or 0))
    local segs = { { text = title, hl = is_root and "JimTopLevel" or "Comment" } }
    if is_root and not has_points_col then
      local points = node.story_points or node.points
      if points ~= nil and points ~= vim.NIL then
        segs[#segs + 1] = { text = string.format("  󰫢 %s", points), hl = "JimStoryPoint" }
      end
    end
    return segs
  elseif field == "assignee" then
    local ass = node.assignee or "Unassigned"
    local hl = (ass == "Unassigned") and "JimAssigneeUnassigned" or "JimAssignee"
    return { { text = truncate(ass, width), hl = hl } }
  elseif field == "status" then
    local status = truncate(node.status or "Unknown", width - 2)
    return { { text = " " .. status .. " ", hl = ui.get_status_hl(node.status) } }
  elseif field == "time" then
    if is_root then
      local spent, estimate = get_totals(node)
      local bar, filled = render_progress_bar(spent, estimate, 8)
      local ratio = string.format("%s/%s", util.format_time(spent), util.format_time(math.max(estimate, spent)))
      return {
        { text = string.sub(bar, 1, filled * 3), hl = "JimProgressBar" },
        { text = string.sub(bar, filled * 3 + 1), hl = "LineNr" },
        { text = " " .. ratio, hl = "Comment" },
      }
    end
    local t, hl = get_time_display_info(node.time_spent or 0, node.time_estimate or 0)
    return { { text = t, hl = hl } }
  elseif field == "story_points" then
    local p = node.story_points or node.points
    local txt = (p ~= nil and p ~= vim.NIL) and tostring(p) or ""
    return { { text = txt, hl = "JimStoryPoint" } }
  elseif field == "priority" then
    local p = node.priority or ""
    return { { text = p, hl = priority_hl(p) } }
  elseif field == "type" then
    return { { text = node.type or "", hl = "Comment" } }
  elseif field == "reporter" then
    return { { text = node.reporter or "", hl = "Comment" } }
  end
  return { { text = "", hl = nil } }
end

-- ---------------------------------------------
-- Render ONE issue line (left-aligned, driven by config.options.columns
-- in the same order/width as render_column_header so the two line up)
-- ---------------------------------------------
---@param node JiraIssueNode
---@param depth number
---@param row number
---@return string, table[]
local function render_issue_line(node, depth, row)
  local cols = require("jim.config").options.columns or {}
  local is_root = depth == 1
  local indent = string.rep("    ", depth - 1)
  local icon, icon_hl = get_issue_icon(node)

  local expand_icon = " "
  if node.children and #node.children > 0 then
    expand_icon = node.expanded and "" or ""
  end

  local has_points_col = false
  for _, c in ipairs(cols) do
    if c.field == "story_points" then has_points_col = true end
  end

  local effective_summary = get_effective_summary_width(cols, PREFIX_W)

  local line = ""
  local highlights = {}
  local function append(text, hl)
    if hl and text ~= "" then
      table.insert(highlights, { start_col = #line, end_col = #line + #text, hl = hl })
    end
    line = line .. text
  end

  -- tree prefix: indent + expand chevron + type icon, padded to PREFIX_W
  append(indent, nil)
  append(expand_icon, "Comment")
  append(" ", nil)
  append(icon, icon_hl)
  local prefix_used = vim.fn.strdisplaywidth(expand_icon) + 1 + vim.fn.strdisplaywidth(icon)
  append(string.rep(" ", math.max(1, PREFIX_W - prefix_used)), nil)

  -- children prepend indent; shrink the flex summary cell by the same amount so
  -- the trailing metadata columns stay aligned with the header across depths
  local indent_dw = 4 * (depth - 1)
  for _, c in ipairs(cols) do
    local width = c.field == "summary" and math.max(10, effective_summary - indent_dw) or (c.width or 12)
    local segs = build_cell(node, c.field, is_root, width, has_points_col)
    local cell_dw = 0
    for _, seg in ipairs(segs) do
      append(seg.text, seg.hl)
      cell_dw = cell_dw + vim.fn.strdisplaywidth(seg.text)
    end
    append(string.rep(" ", math.max(0, width - cell_dw)), nil)
    append("  ", nil)
  end

  api.nvim_buf_set_lines(state.buf, row, row + 1, false, { line })
  for _, h in ipairs(highlights) do
    api.nvim_buf_set_extmark(state.buf, state.ns, row, h.start_col, {
      end_col = h.end_col,
      hl_group = h.hl,
    })
  end

  return line, highlights
end

local function format_keys(keys)
  if type(keys) == "table" then
    return table.concat(keys, ", ")
  end
  return keys
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

local function build_hint_line(view, km)
  local function pair(k, d) return format_keys(k) .. ":" .. d end

  if view == "Help" then
    return pair(km.close, "close")
  end

  local parts = {
    pair(km.toggle_node, "toggle"),
    pair(km.toggle_all, "all"),
    pair(km.filter, "filter"),
    pair(km.change_status, "status"),
    pair(km.edit_issue, "edit"),
    pair(km.create_story, "new"),
    pair(km.details, "details"),
    pair(km.open_browser, "browser"),
    pair(km.refresh, "refresh"),
  }

  if view == "JQL" then
    table.insert(parts, 1, pair(km.jql_input, "new JQL"))
    table.insert(parts, 2, pair(km.jql, "rerun"))
  end

  table.insert(parts, pair(km.help, "help"))
  table.insert(parts, pair(km.close, "quit"))

  return table.concat(parts, "  ")
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

  -- Line 2: filter if active, else contextual key hints
  local second_line = ""
  local second_hl = nil
  if state.current_filter and state.current_filter ~= "" then
    second_line = "  Filter: " .. state.current_filter .. "  (press " .. format_keys(km.clear_filter) .. " to clear)"
    second_hl = "WarningMsg"
  else
    second_line = "  " .. build_hint_line(view, km)
    second_hl = "Comment"
  end

  api.nvim_buf_set_lines(state.buf, 0, -1, false, { header, second_line })
  for _, h in ipairs(hls) do
    api.nvim_buf_set_extmark(state.buf, state.ns, 0, h.start_col, {
      end_col = h.end_col,
      hl_group = h.hl,
    })
  end

  if second_line ~= "" and second_hl then
    api.nvim_buf_set_extmark(state.buf, state.ns, 1, 0, {
      end_col = #second_line,
      hl_group = second_hl,
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
