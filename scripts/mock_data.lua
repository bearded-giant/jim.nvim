-- mock issue data for screenshot generation
-- returns flat issue arrays keyed by view name
-- each array is what the jira api would return (pre-tree-building)

local sprint = {
  {
    key = "ACME-42", summary = "User authentication overhaul",
    status = "In Progress", status_category = "In Progress",
    type = "Story", priority = "High",
    assignee = "Sarah Chen", story_points = 8,
    time_spent = 14400, time_estimate = 28800,
  },
  {
    key = "ACME-43", summary = "Implement OAuth2 provider integration",
    status = "In Progress", status_category = "In Progress",
    type = "Sub-Imp", parent = "ACME-42",
    assignee = "Sarah Chen",
    time_spent = 7200, time_estimate = 14400,
  },
  {
    key = "ACME-44", summary = "Add session token management",
    status = "To Do", status_category = "To Do",
    type = "Sub-task", parent = "ACME-42",
    assignee = "Unassigned",
    time_spent = 0, time_estimate = 7200,
  },
  {
    key = "ACME-45", summary = "Write auth integration tests",
    status = "Done", status_category = "Done",
    type = "Sub-Test", parent = "ACME-42",
    assignee = "Mike Torres",
    time_spent = 10800, time_estimate = 10800,
  },
  {
    key = "ACME-46", summary = "Dashboard widgets loading slowly on first render",
    status = "In Review", status_category = "In Progress",
    type = "Bug", priority = "High",
    assignee = "Alex Kim", story_points = 3,
    time_spent = 14400, time_estimate = 21600,
  },
  {
    key = "ACME-47", summary = "Payment gateway integration",
    status = "To Do", status_category = "To Do",
    type = "Story", priority = "Medium",
    assignee = "Unassigned", story_points = 13,
    time_spent = 0, time_estimate = 144000,
  },
  {
    key = "ACME-48", summary = "Build Stripe SDK wrapper",
    status = "To Do", status_category = "To Do",
    type = "Sub-Imp", parent = "ACME-47",
    assignee = "Unassigned",
    time_spent = 0, time_estimate = 57600,
  },
  {
    key = "ACME-49", summary = "Payment form UI components",
    status = "To Do", status_category = "To Do",
    type = "Sub Design", parent = "ACME-47",
    assignee = "Priya Patel",
    time_spent = 0, time_estimate = 43200,
  },
  {
    key = "ACME-50", summary = "PCI compliance review",
    status = "To Do", status_category = "To Do",
    type = "Sub-task", parent = "ACME-47",
    assignee = "Unassigned",
    time_spent = 0, time_estimate = 43200,
  },
  {
    key = "ACME-51", summary = "API rate limiting middleware",
    status = "In Progress", status_category = "In Progress",
    type = "Task", priority = "Medium",
    assignee = "Jordan Lee", story_points = 5,
    time_spent = 43200, time_estimate = 72000,
  },
  {
    key = "ACME-52", summary = "Timezone bug in weekly reports export",
    status = "Blocked", status_category = "In Progress",
    type = "Bug", priority = "Highest",
    assignee = "Unassigned", story_points = 2,
    time_spent = 7200, time_estimate = 0,
  },
  {
    key = "ACME-53", summary = "Redesign onboarding email templates",
    status = "Done", status_category = "Done",
    type = "Task", priority = "Low",
    assignee = "Priya Patel", story_points = 1,
    time_spent = 14400, time_estimate = 14400,
  },
}

local backlog = {
  {
    key = "ACME-60", summary = "Multi-language support (i18n)",
    status = "Backlog", status_category = "To Do",
    type = "Story", priority = "Medium",
    assignee = "Unassigned", story_points = 21,
    time_spent = 0, time_estimate = 0,
  },
  {
    key = "ACME-61", summary = "Dark mode implementation",
    status = "Backlog", status_category = "To Do",
    type = "Story", priority = "Low",
    assignee = "Unassigned", story_points = 8,
    time_spent = 0, time_estimate = 0,
  },
  {
    key = "ACME-62", summary = "Bulk CSV data export",
    status = "Backlog", status_category = "To Do",
    type = "Task", priority = "Medium",
    assignee = "Unassigned", story_points = 3,
    time_spent = 0, time_estimate = 0,
  },
  {
    key = "ACME-63", summary = "CI/CD pipeline automation",
    status = "Backlog", status_category = "To Do",
    type = "Task", priority = "High",
    assignee = "Jordan Lee", story_points = 5,
    time_spent = 0, time_estimate = 0,
  },
  {
    key = "ACME-64", summary = "Mobile responsive overhaul",
    status = "Backlog", status_category = "To Do",
    type = "Story", priority = "Medium",
    assignee = "Unassigned", story_points = 13,
    time_spent = 0, time_estimate = 0,
  },
  {
    key = "ACME-65", summary = "Audit logging system",
    status = "Backlog", status_category = "To Do",
    type = "Story", priority = "High",
    assignee = "Unassigned", story_points = 8,
    time_spent = 0, time_estimate = 0,
  },
  {
    key = "ACME-66", summary = "Performance monitoring dashboard",
    status = "Backlog", status_category = "To Do",
    type = "Task", priority = "Medium",
    assignee = "Alex Kim", story_points = 5,
    time_spent = 0, time_estimate = 0,
  },
}

local my_issues = {
  {
    key = "ACME-42", summary = "User authentication overhaul",
    status = "In Progress", status_category = "In Progress",
    type = "Story", priority = "High",
    assignee = "Jordan Lee", story_points = 8,
    time_spent = 32400, time_estimate = 61200,
  },
  {
    key = "ACME-51", summary = "API rate limiting middleware",
    status = "In Progress", status_category = "In Progress",
    type = "Task", priority = "Medium",
    assignee = "Jordan Lee", story_points = 5,
    time_spent = 43200, time_estimate = 72000,
  },
  {
    key = "PLAT-15", summary = "Migrate to PostgreSQL 16",
    status = "In Progress", status_category = "In Progress",
    type = "Task", priority = "High",
    assignee = "Jordan Lee", story_points = 8,
    time_spent = 28800, time_estimate = 57600,
  },
  {
    key = "PLAT-18", summary = "Fix connection pool exhaustion under load",
    status = "To Do", status_category = "To Do",
    type = "Bug", priority = "Highest",
    assignee = "Jordan Lee", story_points = 3,
    time_spent = 0, time_estimate = 14400,
  },
  {
    key = "ACME-64", summary = "Mobile responsive overhaul",
    status = "Backlog", status_category = "To Do",
    type = "Story", priority = "Medium",
    assignee = "Jordan Lee", story_points = 13,
    time_spent = 0, time_estimate = 0,
  },
}

local jql = {
  {
    key = "ACME-42", summary = "User authentication overhaul",
    status = "In Progress", status_category = "In Progress",
    type = "Story", priority = "High",
    assignee = "Sarah Chen", story_points = 8,
    time_spent = 32400, time_estimate = 61200,
  },
  {
    key = "ACME-51", summary = "API rate limiting middleware",
    status = "In Progress", status_category = "In Progress",
    type = "Task", priority = "Medium",
    assignee = "Jordan Lee", story_points = 5,
    time_spent = 43200, time_estimate = 72000,
  },
  {
    key = "PLAT-15", summary = "Migrate to PostgreSQL 16",
    status = "In Progress", status_category = "In Progress",
    type = "Task", priority = "High",
    assignee = "Jordan Lee", story_points = 8,
    time_spent = 28800, time_estimate = 57600,
  },
  {
    key = "PLAT-22", summary = "Add health check endpoints",
    status = "In Progress", status_category = "In Progress",
    type = "Task", priority = "Medium",
    assignee = "Alex Kim", story_points = 2,
    time_spent = 3600, time_estimate = 7200,
  },
  {
    key = "SEC-8", summary = "Rotate production API keys",
    status = "In Progress", status_category = "In Progress",
    type = "Task", priority = "High",
    assignee = "Sarah Chen", story_points = 1,
    time_spent = 1800, time_estimate = 3600,
  },
}

return {
  sprint = sprint,
  backlog = backlog,
  my_issues = my_issues,
  jql = jql,
}
