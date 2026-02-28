# Jim (Jira Improved-ish)

A Neovim plugin for viewing and managing Jira issues with an interactive TUI.

Since Jira UX is a time sucking disaster for dev productivity....

## Features

- **My Issues** - Cross-project view of issues assigned to you (persisted)
- **Sprint Board** - View active sprint issues with parent/subtask hierarchy
- **Backlog View** - Browse backlog items not in active sprints
- **Custom JQL** - Run arbitrary JQL queries
- **Summary Filter** - Filter any view by issue summary text
- **Status Transitions** - Change issue status via workflow-aware picker
- **Edit Issues** - Update summary, append to description, change status
- **Create Stories** - Story creation with summary, description, auto-assigned to you
- **Close Issues** - One-keypress close to Done status
- **Toggle Resolved** - Show/hide resolved issues (works in all views including JQL)
- **Issue Details** - Popup with summary, description, status, created date, sprint, assignee
- **Markdown View** - Read full issue description and acceptance criteria
- **Browser Integration** - Open issues in your browser
- **Persistent State** - Saved projects and preferences across sessions
- **Assign Issues** - Assign, reassign, or unassign issues via picker
- **Tab Visibility** - Hide/show tabs (Sprint, Backlog, JQL) at runtime, persisted across sessions
- **Column Sorting** - Sort issue lists by any column (key, title, assignee, status, time, points)
- **Configurable Columns** - Add/remove visible columns at runtime
- **Fully Configurable Keymaps** - All keybindings can be customized

## Requirements

- Neovim 0.9+
- curl
- Jira Cloud instance with API access

## Installation

Using lazy.nvim:

```lua
{
  "bearded-giant/jim.nvim",
  config = function()
    require("jim").setup({
      jira = {
        base = "https://your-domain.atlassian.net",
        email = "your-email@example.com",
        token = "your-api-token",
      },
    })
  end,
}
```

Using environment variables (recommended):

```lua
{
  dir = "~/path/to/jim.nvim",
  config = function()
    require("jim").setup({
      jira = {
        base = vim.fn.getenv("JIRA_BASE_URL"),
        email = vim.fn.getenv("JIRA_EMAIL"),
        token = vim.fn.getenv("JIRA_API_TOKEN"),
      },
    })
  end,
}
```

## Configuration

```lua
require("jim").setup({
  jira = {
    base = "https://your-domain.atlassian.net",  -- Required: Jira instance URL
    email = "your-email@example.com",             -- Required: Atlassian account email
    token = "your-api-token",                     -- Required: API token
    limit = 500,                                  -- Optional: Max issues per query (default: 500)
  },
  projects = {
    -- Optional: Project-specific custom field overrides
    ["PROJECT_KEY"] = {
      story_point_field = "customfield_10035",
      acceptance_criteria_field = "customfield_10016",
    },
  },
  keymaps = {
    -- All keymaps are configurable. Defaults shown below.
    -- Use a string for single key, or table for multiple keys.
    toggle_node = { "o", "<CR>", "<Tab>" },
    toggle_all = "t",
    my_issues = "M",
    jql = "J",
    jql_input = "gj",
    sprint = "S",
    backlog = "B",
    help = "H",
    edit_projects = "E",
    edit_issue = "e",
    filter = "/",
    clear_filter = "<BS>",
    details = "K",
    read_task = "m",
    open_browser = "gx",
    change_status = "s",
    create_story = "c",
    close_issue = "d",
    toggle_resolved = "x",
    assign_user = "a",
    yank_key = "y",
    export_csv = "gE",
    export_markdown = "gm",
    refresh = "r",
    next_tab = "<Right>",
    prev_tab = "<Left>",
    toggle_tabs = "gT",
    sort_column = "gs",
    toggle_columns = "gc",
    close = { "q", "<Esc>" },
  },
  columns = {
    -- Default visible columns. Add/remove/reorder as needed.
    -- Available fields: key, summary, assignee, time, status, priority, reporter, story_points, type
    { field = "key", header = "Key", width = 12 },
    { field = "summary", header = "Title", width = 60 },
    { field = "assignee", header = "Assignee", width = 12 },
    { field = "time", header = "Time", width = 10 },
    { field = "status", header = "Status", width = 14 },
  },
})
```

### API Token

Generate an API token at: <https://id.atlassian.com/manage-profile/security/api-tokens>

### Finding Custom Field IDs

Story points and acceptance criteria use custom fields that vary per Jira instance. To find yours:

```bash
curl -s -u "email:token" "https://your-domain.atlassian.net/rest/api/3/field" | jq '.[] | select(.custom==true) | {id, name}'
```

## Usage

Open the board:

```vim
:Jim              " Opens My Issues if projects configured, else prompts
:Jim PROJECT_KEY  " Opens Active Sprint for specific project
```

## Keymaps

All keymaps are configurable via `setup()`. Defaults shown below.

### Navigation

| Key                   | Action                      |
| --------------------- | --------------------------- |
| `o` / `Enter` / `Tab` | Toggle node expand/collapse |
| `t`                   | Toggle all expand/collapse  |
| `q` / `Esc`           | Close board                 |

### Views

| Key | Action                                         |
| --- | ---------------------------------------------- |
| `M` | My Issues (cross-project, uses saved projects) |
| `J` | Run last JQL query (or prompt if none)          |
| `gj` | JQL history picker / new query                 |
| `S` | Switch to Active Sprint                        |
| `B` | Switch to Backlog                              |
| `H` | Show help                                      |
| `E` | Edit saved projects                            |
| `r` | Refresh current view                           |
| `Right` / `Left` | Cycle tabs                          |
| `gT` | Toggle tab visibility (hide/show tabs)         |

### Filtering

| Key         | Action                 |
| ----------- | ---------------------- |
| `/`         | Filter by summary text |
| `Backspace` | Clear active filter    |

### Issue Actions

| Key  | Action                                           |
| ---- | ------------------------------------------------ |
| `e`  | Edit issue (summary/description/status menu)     |
| `s`  | Change issue status (workflow-aware)             |
| `c`  | Create new story (prompts summary + description) |
| `d`  | Close issue (transition to Done)                 |
| `x`  | Toggle show/hide resolved issues                 |
| `a`  | Assign issue to user                             |
| `K`  | Show issue details (fetches full data)           |
| `m`  | Read full task as markdown                       |
| `y`  | Copy issue key to clipboard                      |
| `gx` | Open issue in browser                            |
| `gE` | Export current view to CSV                       |
| `gm` | Export issue under cursor to Markdown file       |
| `gs` | Sort by column                                   |
| `gc` | Toggle visible columns                           |

## Views

### My Issues

Cross-project view showing issues assigned to you. Press `E` to configure which projects to include (comma-separated, e.g., `SEC, PLAT, INFRA`). Your selection is saved to `~/.local/share/nvim/jim_nvim.json` and persists across sessions.

Press `M` to load My Issues. If no projects are configured, you'll be prompted to set them up with `E`.

### Active Sprint

Shows all issues in the current active sprint for the selected project. Issues are displayed hierarchically with parent tasks and their subtasks.

When switching to Sprint view:

- If you have a project context, it uses that project
- If you have saved projects, shows a picker
- Otherwise prompts for project key

### Backlog

Shows issues not assigned to an active sprint and not in Done status. Same project selection behavior as Sprint view.

### Custom JQL

Press `J` to re-run your last JQL query instantly (or open the input if you haven't run one yet). Press `gj` to browse your query history or write a new one. The history picker uses `vim.ui.select`, so if you have telescope or fzf-lua installed you get fuzzy search automatically. Selecting a query from history opens the text input pre-filled so you can tweak it before running.

Up to 50 queries are saved across sessions, deduped, most recent first. Examples:

```
assignee = currentUser() AND project = PROJ
status = "In Progress" AND updated >= -7d
labels = "urgent" ORDER BY priority DESC
```

### Filtering

Press `/` in any list view to filter by summary text. The filter uses Jira's `summary ~ "term"` JQL syntax. Active filters are displayed in the header. Press `Backspace` to clear the filter.

### Issue Details

Press `K` to open a details popup for the issue under cursor. The popup fetches full issue data and displays:

- **Summary** - Full issue summary with word wrapping
- **Description** - Rendered from Atlassian Document Format (truncated to 15 lines)
- **Status** - Current status with color coding
- **Created** - Date with relative age (e.g., "2025-12-15 (8d ago)")
- **Sprint** - Current sprint name if assigned
- **Assignee** - Assigned user or "Unassigned"

Press `q` or `Esc` to close the popup.

For the full description with acceptance criteria, use `m` to open the markdown view.

### Editing Issues

Press `e` to open the edit menu for the issue under cursor:

- **Edit Summary** - Update the issue title (pre-filled with current summary)
- **Append to Description** - Add text to the existing description
- **Change Status** - Same as `s`, opens workflow-aware transition picker

For direct status changes without the menu, use `s`.

**Note:** Attachments and rich formatting require the browser (`gx`).

### Tab Visibility

Press `gT` to toggle which tabs appear in the header. The picker shows JQL, Active Sprint, and Backlog with `[x]` (visible) or `[ ]` (hidden) markers. Select a tab to toggle it, then press `Esc` to apply. My Issues and Help are always visible.

Hidden tabs are persisted to `jim_nvim.json` so your preference carries across sessions. If you hide the tab you're currently viewing, the plugin auto-switches to My Issues.

Tab cycling with `Right`/`Left` also skips hidden tabs.

### Sorting

Press `gs` to sort the issue list by a column. A picker shows the available columns -- selecting one sorts ascending. Selecting the same column again flips to descending. A third selection clears the sort and returns to the original order. The current sort column and direction are shown in the column header row with `▲` / `▼` indicators.

Sorting applies to root-level issues only. Children stay grouped under their parent.

### Configurable Columns

Press `gc` to add or remove columns from the issue list at runtime. The picker shows available fields (Key, Title, Assignee, Time, Status, Priority, Reporter, Points, Type) with `[x]`/`[ ]` markers. Toggle fields on/off, then press `Esc` to apply.

Column widths and defaults can also be set in `setup()` via the `columns` config. The column header row at the top of the issue list reflects the active configuration.

### Assigning Issues

Press `a` on any issue to open the assignment picker. It fetches assignable users from Jira (cached for 24 hours per project) and shows them in a `vim.ui.select` picker. The current assignee is marked. Select "Unassigned" to remove the assignee.

## Display

Each issue line shows:

- Expand/collapse indicator (for parent issues)
- Issue type icon (Bug, Story, Task, Sub-task, etc.)
- Issue key
- Summary (truncated)
- Story points (for parent issues)
- Progress bar (aggregate time for parent issues)
- Time spent / estimated
- Assignee
- Status badge (color-coded)

Issues are collapsed by default. Use `o`/`Enter`/`Tab` to expand individual items or `t` to toggle all.

## State Persistence

The plugin saves the following to `~/.local/share/nvim/jim_nvim.json`:

- `my_issues_projects` - Your configured project keys for My Issues
- `hide_resolved` - Whether to show/hide resolved issues
- `hidden_tabs` - Which tabs are hidden from the header
- `last_jql` - Your last executed JQL query (restored on next session)
- `jql_history` - Last 50 JQL queries for the history picker

## License

MIT
