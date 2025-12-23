local M = {}
local api = vim.api
local state = require("jira.state")

local function get_theme_color(groups, attr)
  for _, g in ipairs(groups) do
    local hl = vim.api.nvim_get_hl(0, { name = g, link = false })
    if hl and hl[attr] then return string.format("#%06x", hl[attr]) end
  end
  return nil
end

local function get_palette()
  return {
    get_theme_color({ "DiagnosticOk", "String", "DiffAdd" }, "fg") or "#a6e3a1",         -- Green
    get_theme_color({ "DiagnosticInfo", "Function", "DiffChange" }, "fg") or "#89b4fa",  -- Blue
    get_theme_color({ "DiagnosticWarn", "WarningMsg", "Todo" }, "fg") or "#f9e2af",      -- Yellow
    get_theme_color({ "DiagnosticError", "ErrorMsg", "DiffDelete" }, "fg") or "#f38ba8", -- Red
    get_theme_color({ "Special", "Constant" }, "fg") or "#cba6f7",                       -- Magenta
    get_theme_color({ "Identifier", "PreProc" }, "fg") or "#89dceb",                     -- Cyan
    get_theme_color({ "Cursor", "CursorIM" }, "fg") or "#524f67",                        -- Grey
  }
end

function M.get_status_hl(status_name)
  if not status_name or status_name == "" then return "JiraStatus" end

  local hl_name = "JiraStatus_" .. status_name:gsub("%s+", "_"):gsub("[^%w_]", "")
  if state.status_hls[status_name] then return hl_name end

  local palette = get_palette()
  local bg_base = get_theme_color({ "Normal" }, "bg") or "#1e1e2e"

  local name_upper = status_name:upper()
  local color
  if name_upper:find("READY FOR DEV") or name_upper:find("READY FOR TEST") then
    color = palette[7] -- Grey
  elseif name_upper:find("DONE") or name_upper:find("RESOLVED") or name_upper:find("CLOSED") or name_upper:find("FINISHED") then
    color = palette[1] -- Green
  elseif name_upper:find("PROGRESS") or name_upper:find("DEVELOPMENT") or name_upper:find("BUILDING") or name_upper:find("WORKING") then
    color = palette[3] -- Yellow
  elseif name_upper:find("TODO") or name_upper:find("OPEN") or name_upper:find("BACKLOG") then
    color = palette[2] -- Blue
  elseif name_upper:find("BLOCK") or name_upper:find("REJECT") or name_upper:find("BUG") or name_upper:find("ERROR") then
    color = palette[4] -- Red
  elseif name_upper:find("REVIEW") or name_upper:find("QA") or name_upper:find("TEST") then
    color = palette[5] -- Magenta
  else
    -- Hash
    local hash = 0
    for i = 1, #status_name do
      hash = (hash * 31 + string.byte(status_name, i)) % #palette
    end
    color = palette[hash + 1]
  end

  vim.api.nvim_set_hl(0, hl_name, {
    fg = bg_base,
    bg = color,
    bold = true,
  })

  state.status_hls[status_name] = hl_name
  return hl_name
end

function M.setup_static_highlights()
  vim.api.nvim_set_hl(0, "JiraTopLevel", { link = "CursorLineNr", bold = true })
  vim.api.nvim_set_hl(0, "JiraStoryPoint", { link = "Error", bold = true })
  vim.api.nvim_set_hl(0, "JiraAssignee", { link = "MoreMsg" })
  vim.api.nvim_set_hl(0, "JiraAssigneeUnassigned", { link = "Comment", italic = true })
  vim.api.nvim_set_hl(0, "exgreen", { fg = "#a6e3a1" })
  vim.api.nvim_set_hl(0, "JiraProgressBar", { link = "Function" })
  vim.api.nvim_set_hl(0, "JiraStatus", { link = "lualine_a_insert" })
  vim.api.nvim_set_hl(0, "JiraStatusRoot", { link = "lualine_a_insert", bold = true })

  vim.api.nvim_set_hl(0, "JiraTabActive", { link = "CurSearch", bold = true })
  vim.api.nvim_set_hl(0, "JiraTabInactive", { link = "Search" })

  -- Icons
  vim.api.nvim_set_hl(0, "JiraIconBug", { fg = "#f38ba8" })      -- Red
  vim.api.nvim_set_hl(0, "JiraIconStory", { fg = "#a6e3a1" })    -- Green
  vim.api.nvim_set_hl(0, "JiraIconTask", { fg = "#89b4fa" })     -- Blue
  vim.api.nvim_set_hl(0, "JiraIconSubTask", { fg = "#94e2d5" })  -- Teal
  vim.api.nvim_set_hl(0, "JiraIconTest", { fg = "#fab387" })     -- Peach
  vim.api.nvim_set_hl(0, "JiraIconDesign", { fg = "#cba6f7" })   -- Mauve
  vim.api.nvim_set_hl(0, "JiraIconOverhead", { fg = "#9399b2" }) -- Overlay2
  vim.api.nvim_set_hl(0, "JiraIconImp", { fg = "#89dceb" })      -- Sky
end

local function get_window_dimensions()
  local width = math.min(math.floor(vim.o.columns * 0.9), 180)
  local height = math.min(math.floor(vim.o.lines * 0.85), 50)
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2) - 1
  return width, height, col, row
end

local function resize_windows()
  if not state.win or not api.nvim_win_is_valid(state.win) then return end
  if not state.dim_win or not api.nvim_win_is_valid(state.dim_win) then return end

  local width, height, col, row = get_window_dimensions()

  api.nvim_win_set_config(state.dim_win, {
    relative = "editor",
    width = vim.o.columns,
    height = vim.o.lines,
    row = 0,
    col = 0,
  })

  api.nvim_win_set_config(state.win, {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
  })
end

local resize_autocmd_id = nil

function M.create_window()
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
    zindex = 44,
  })
  api.nvim_win_set_option(state.dim_win, "winblend", 50)
  api.nvim_win_set_option(state.dim_win, "winhighlight", "Normal:JiraDim")
  vim.api.nvim_set_hl(0, "JiraDim", { bg = "#000000" })

  state.buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(state.buf, "bufhidden", "wipe")

  local width, height, col, row = get_window_dimensions()

  state.win = api.nvim_open_win(state.buf, true, {
    width = width,
    height = height,
    col = col,
    row = row,
    relative = 'editor',
    style = "minimal",
    border = { " ", " ", " ", " ", " ", " ", " ", " " },
    title = { { "  Jira Board ", "StatusLineTerm" } },
    title_pos = "center",
    zindex = 45,
  })

  api.nvim_win_set_hl_ns(state.win, state.ns)
  api.nvim_win_set_option(state.win, "cursorline", true)

  resize_autocmd_id = api.nvim_create_autocmd("VimResized", {
    callback = function()
      resize_windows()
    end,
  })

  api.nvim_create_autocmd("BufWipeout", {
    buffer = state.buf,
    callback = function()
      if state.dim_win and api.nvim_win_is_valid(state.dim_win) then
        api.nvim_win_close(state.dim_win, true)
        state.dim_win = nil
      end
      if resize_autocmd_id then
        api.nvim_del_autocmd(resize_autocmd_id)
        resize_autocmd_id = nil
      end
    end,
  })

  api.nvim_set_current_win(state.win)
end

local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local spinner_timer = nil
local spinner_win = nil
local spinner_buf = nil

function M.start_loading(msg)
  msg = msg or "Loading..."
  if spinner_win and api.nvim_win_is_valid(spinner_win) then return end

  spinner_buf = api.nvim_create_buf(false, true)
  local width = #msg + 4
  local height = 1
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  spinner_win = api.nvim_open_win(spinner_buf, false, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    zindex = 200,
  })

  local idx = 1
  spinner_timer = vim.loop.new_timer()
  spinner_timer:start(0, 100, vim.schedule_wrap(function()
    if not spinner_buf or not api.nvim_buf_is_valid(spinner_buf) then return end
    local frame = spinner_frames[idx]
    api.nvim_buf_set_lines(spinner_buf, 0, -1, false, { " " .. frame .. " " .. msg })
    idx = (idx % #spinner_frames) + 1
  end))
end

function M.stop_loading()
  if spinner_timer then
    spinner_timer:stop()
    spinner_timer:close()
    spinner_timer = nil
  end
  if spinner_win and api.nvim_win_is_valid(spinner_win) then
    api.nvim_win_close(spinner_win, true)
    spinner_win = nil
  end
  if spinner_buf and api.nvim_buf_is_valid(spinner_buf) then
    api.nvim_buf_delete(spinner_buf, { force = true })
    spinner_buf = nil
  end
end

local function format_age(iso_date)
  if not iso_date then return "" end
  local year, month, day, hour, min, sec = iso_date:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
  if not year then return iso_date end
  local created = os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = tonumber(hour), min = tonumber(min), sec = tonumber(sec) })
  local now = os.time()
  local diff = now - created
  if diff < 60 then return "just now"
  elseif diff < 3600 then return math.floor(diff / 60) .. "m ago"
  elseif diff < 86400 then return math.floor(diff / 3600) .. "h ago"
  elseif diff < 604800 then return math.floor(diff / 86400) .. "d ago"
  elseif diff < 2592000 then return math.floor(diff / 604800) .. "w ago"
  else return math.floor(diff / 2592000) .. "mo ago"
  end
end

local function wrap_text(text, width)
  local lines = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    if #line <= width then
      table.insert(lines, line)
    else
      local remaining = line
      while #remaining > width do
        local break_at = width
        local space = remaining:sub(1, width):match(".*()%s")
        if space and space > width * 0.5 then break_at = space end
        table.insert(lines, remaining:sub(1, break_at):gsub("%s+$", ""))
        remaining = remaining:sub(break_at + 1):gsub("^%s+", "")
      end
      if #remaining > 0 then table.insert(lines, remaining) end
    end
  end
  return lines
end

function M.show_issue_details_popup(issue)
  local util = require("jira.util")
  local fields = issue.fields or {}
  local max_width = 80

  local summary = fields.summary or ""
  local status = fields.status and fields.status.name or "Unknown"
  local assignee = fields.assignee and fields.assignee.displayName or "Unassigned"
  local created = fields.created
  local sprint_name = nil
  if fields.sprint then
    sprint_name = fields.sprint.name
  elseif fields.customfield_10020 and type(fields.customfield_10020) == "table" then
    local sprints = fields.customfield_10020
    if #sprints > 0 and sprints[#sprints].name then
      sprint_name = sprints[#sprints].name
    end
  end

  local lines = {}
  local hls = {}

  -- Summary
  table.insert(lines, " Summary:")
  table.insert(hls, { row = #lines - 1, col = 1, end_col = 9, hl = "Label" })
  table.insert(lines, " " .. string.rep("─", max_width - 2))
  table.insert(hls, { row = #lines - 1, col = 0, end_col = -1, hl = "Comment" })
  local summary_lines = wrap_text(summary, max_width - 2)
  for _, sl in ipairs(summary_lines) do
    table.insert(lines, " " .. sl)
  end
  table.insert(lines, "")

  -- Description
  table.insert(lines, " Description:")
  table.insert(hls, { row = #lines - 1, col = 1, end_col = 13, hl = "Label" })
  table.insert(lines, " " .. string.rep("─", max_width - 2))
  table.insert(hls, { row = #lines - 1, col = 0, end_col = -1, hl = "Comment" })
  if fields.description then
    local desc_md = util.adf_to_markdown(fields.description)
    if desc_md and desc_md ~= "" then
      local desc_lines = wrap_text(desc_md, max_width - 2)
      local max_desc_lines = 15
      for i, dl in ipairs(desc_lines) do
        if i > max_desc_lines then
          table.insert(lines, " ...")
          break
        end
        table.insert(lines, " " .. dl)
      end
    else
      table.insert(lines, " (no description)")
      table.insert(hls, { row = #lines - 1, col = 1, end_col = -1, hl = "Comment" })
    end
  else
    table.insert(lines, " (no description)")
    table.insert(hls, { row = #lines - 1, col = 1, end_col = -1, hl = "Comment" })
  end
  table.insert(lines, "")

  -- Metadata section
  table.insert(lines, " " .. string.rep("─", max_width - 2))
  table.insert(hls, { row = #lines - 1, col = 0, end_col = -1, hl = "Comment" })

  -- Status
  local status_row = #lines
  table.insert(lines, string.format(" Status:    %s", status))
  table.insert(hls, { row = status_row, col = 1, end_col = 10, hl = "Label" })
  table.insert(hls, { row = status_row, col = 12, end_col = -1, hl = M.get_status_hl(status) })

  -- Created
  if created then
    local created_row = #lines
    local age = format_age(created)
    local date_str = created:sub(1, 10)
    table.insert(lines, string.format(" Created:   %s (%s)", date_str, age))
    table.insert(hls, { row = created_row, col = 1, end_col = 10, hl = "Label" })
  end

  -- Sprint
  if sprint_name then
    local sprint_row = #lines
    table.insert(lines, string.format(" Sprint:    %s", sprint_name))
    table.insert(hls, { row = sprint_row, col = 1, end_col = 10, hl = "Label" })
  end

  -- Assignee
  local assignee_row = #lines
  table.insert(lines, string.format(" Assignee:  %s", assignee))
  table.insert(hls, { row = assignee_row, col = 1, end_col = 10, hl = "Label" })
  local ass_hl = assignee == "Unassigned" and "JiraAssigneeUnassigned" or "JiraAssignee"
  table.insert(hls, { row = assignee_row, col = 12, end_col = -1, hl = ass_hl })

  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  api.nvim_buf_set_option(buf, "modifiable", false)
  api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  -- Apply highlights
  for _, h in ipairs(hls) do
    local end_col = h.end_col
    if end_col == -1 then
      end_col = #lines[h.row + 1]
    end
    api.nvim_buf_set_extmark(buf, state.ns, h.row, h.col, {
      end_col = end_col,
      hl_group = h.hl,
    })
  end

  local width = 0
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end
  width = math.min(width + 2, max_width)
  local height = math.min(#lines, 30)

  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " " .. issue.key .. " ",
    title_pos = "center",
  })

  api.nvim_buf_set_keymap(buf, "n", "q", "", {
    callback = function()
      if api.nvim_win_is_valid(win) then
        api.nvim_win_close(win, true)
      end
    end,
    noremap = true,
    silent = true,
  })
  api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", {
    callback = function()
      if api.nvim_win_is_valid(win) then
        api.nvim_win_close(win, true)
      end
    end,
    noremap = true,
    silent = true,
  })
end

function M.open_markdown_view(title, lines)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  api.nvim_buf_set_option(buf, "filetype", "markdown")
  api.nvim_buf_set_option(buf, "buftype", "nofile")
  api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  api.nvim_buf_set_name(buf, title)

  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)

  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = (vim.o.lines - height) / 2,
    col = (vim.o.columns - width) / 2,
    style = "minimal",
    border = "rounded",
  })

  local config = require("jira.config")
  local close_keys = config.options.keymaps.close
  if type(close_keys) == "table" then
    for _, key in ipairs(close_keys) do
      vim.keymap.set("n", key, function() api.nvim_win_close(win, true) end, { buffer = buf, silent = true })
    end
  else
    vim.keymap.set("n", close_keys, function() api.nvim_win_close(win, true) end, { buffer = buf, silent = true })
  end
end

return M
