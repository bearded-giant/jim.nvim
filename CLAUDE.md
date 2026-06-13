# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

jim.nvim is a Neovim plugin for viewing and managing JIRA tasks with an interactive UI. It provides sprint board viewing, backlog browsing, custom JQL queries, and issue detail popups.

## Architecture

```
plugin/jim.lua          Entry point - creates :Jim command
lua/jim/
├── init.lua             Core module - commands, keymaps, view management
├── config.lua           User configuration storage
├── state.lua            Runtime state (buffer, window, cache, tree)
├── render.lua           Buffer rendering - issue trees, headers, progress bars
├── ui.lua               Window/popup creation, highlights, spinners
├── util.lua             Helpers - tree building, time formatting, ADF→markdown
└── jira-api/
    ├── api.lua          REST client - async curl via vim.fn.jobstart
    └── sprint.lua       High-level queries - sprint, backlog, JQL with pagination
```

**Data flow**: Command → init.lua → sprint.lua → api.lua (async curl) → callback → util.build_issue_tree → render → ui

**Key patterns**:
- All API calls are async using `vim.fn.jobstart()` with callbacks
- Caching uses `state.cache[project:view]` keys
- Rendering builds a `state.line_map` for cursor-to-node mapping
- Highlights use extmarks with namespaced cleanup

## Development

**No build system** - plugin loads directly via Neovim's runtime path.

**Testing manually**:
1. Add plugin path to Neovim: `vim.opt.rtp:prepend('/path/to/jim.nvim')`
2. Configure: `require('jim').setup({ jira = { base = "...", email = "...", token = "..." } })`
3. Run: `:Jim PROJECT_KEY`

**API testing**: Use `jira-api.http` with REST client tools (contains 26 example requests).

## Plugin Keymaps (inside Jim board)

All keymaps are configurable via `config.options.keymaps`. Defaults:

| Key | Action |
|-----|--------|
| `o`/`<CR>`/`<Tab>` | Toggle node expand/collapse |
| `t` | Toggle all expand/collapse |
| `M` | My Issues (cross-project) |
| `J` | Run last JQL query (or prompt if none) |
| `gj` | JQL history / new query |
| `S` | Switch to Active Sprint |
| `B` | Switch to Backlog |
| `H` | Help |
| `E` | Edit saved projects |
| `e` | Edit issue (summary/description/status) |
| `/` | Filter by summary |
| `<BS>` | Clear filter |
| `s` | Change issue status |
| `c` | Create new story |
| `d` | Close issue (Done) |
| `x` | Toggle show/hide resolved |
| `K` | Show issue details popup |
| `m` | Read task as markdown |
| `gx` | Open in browser |
| `r` | Refresh |
| `q`/`<Esc>` | Close |

## Configuration Structure

```lua
require('jim').setup({
  jira = {
    base = "https://your-domain.atlassian.net",
    email = "your@email.com",
    token = "api_token",
    limit = 500,
  },
  projects = {
    ["PROJECT_KEY"] = {
      story_point_field = "customfield_10035",
      acceptance_criteria_field = "customfield_10016",
    }
  },
  keymaps = {
    -- All configurable, see config.lua for full list
  }
})
```

## State Persistence

File: `~/.local/share/nvim/jim_nvim.json`

Persisted: `my_issues_projects`, `hide_resolved`

## Issue Node Structure

```lua
{
  key = "PROJ-123",
  summary = "...",
  status = "In Progress",
  type = "Story",  -- Bug, Story, Task, Sub-task
  priority = "High",
  assignee = "Name" | "Unassigned",
  parent = "PROJ-122" | nil,
  story_points = 5,
  time_spent = 7200,      -- seconds
  time_estimate = 10800,  -- seconds
  children = { ... },
  expanded = false,  -- collapsed by default
}
```

## Dependencies

- curl (system)
- Neovim 0.9+
- No external Lua packages
