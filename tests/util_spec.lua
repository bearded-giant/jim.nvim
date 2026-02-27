local util = require("jim.util")

describe("util.build_issue_tree", function()
  it("returns empty table for empty input", function()
    local result = util.build_issue_tree({})
    assert.are.same({}, result)
  end)

  it("returns flat list as roots when no parents specified", function()
    local issues = {
      { key = "PROJ-1", summary = "Task 1" },
      { key = "PROJ-2", summary = "Task 2" },
    }
    local result = util.build_issue_tree(issues)
    assert.are.equal(2, #result)
    assert.are.equal("PROJ-1", result[1].key)
    assert.are.equal("PROJ-2", result[2].key)
    assert.are.same({}, result[1].children)
    assert.are.same({}, result[2].children)
    assert.is_false(result[1].expanded)
  end)

  it("places child under parent when parent exists", function()
    local issues = {
      { key = "PROJ-1", summary = "Parent" },
      { key = "PROJ-2", summary = "Child", parent = "PROJ-1" },
    }
    local result = util.build_issue_tree(issues)
    assert.are.equal(1, #result)
    assert.are.equal("PROJ-1", result[1].key)
    assert.are.equal(1, #result[1].children)
    assert.are.equal("PROJ-2", result[1].children[1].key)
  end)

  it("makes orphan child a root when parent not in list", function()
    local issues = {
      { key = "PROJ-2", summary = "Orphan", parent = "PROJ-1" },
    }
    local result = util.build_issue_tree(issues)
    assert.are.equal(1, #result)
    assert.are.equal("PROJ-2", result[1].key)
  end)

  it("handles multiple children under one parent", function()
    local issues = {
      { key = "PROJ-1", summary = "Parent" },
      { key = "PROJ-2", summary = "Child 1", parent = "PROJ-1" },
      { key = "PROJ-3", summary = "Child 2", parent = "PROJ-1" },
    }
    local result = util.build_issue_tree(issues)
    assert.are.equal(1, #result)
    assert.are.equal(2, #result[1].children)
    assert.are.equal("PROJ-2", result[1].children[1].key)
    assert.are.equal("PROJ-3", result[1].children[2].key)
  end)

  it("preserves order from input", function()
    local issues = {
      { key = "PROJ-3", summary = "Third" },
      { key = "PROJ-1", summary = "First" },
      { key = "PROJ-2", summary = "Second" },
    }
    local result = util.build_issue_tree(issues)
    assert.are.equal(3, #result)
    assert.are.equal("PROJ-3", result[1].key)
    assert.are.equal("PROJ-1", result[2].key)
    assert.are.equal("PROJ-2", result[3].key)
  end)

  it("inherits all issue fields in nodes", function()
    local issues = {
      { key = "PROJ-1", summary = "Task", status = "In Progress", priority = "High" },
    }
    local result = util.build_issue_tree(issues)
    assert.are.equal("PROJ-1", result[1].key)
    assert.are.equal("Task", result[1].summary)
    assert.are.equal("In Progress", result[1].status)
    assert.are.equal("High", result[1].priority)
  end)

  it("adds children and expanded fields to nodes", function()
    local issues = {
      { key = "PROJ-1", summary = "Task" },
    }
    local result = util.build_issue_tree(issues)
    assert.are.equal(true, result[1].children ~= nil)
    assert.are.equal(true, result[1].expanded ~= nil)
  end)
end)

describe("util.format_time", function()
  it("returns '0' for nil input", function()
    assert.are.equal("0", util.format_time(nil))
  end)

  it("returns '0' for 0", function()
    assert.are.equal("0", util.format_time(0))
  end)

  it("returns '0' for negative numbers", function()
    assert.are.equal("0", util.format_time(-1))
    assert.are.equal("0", util.format_time(-100))
  end)

  it("returns integer format for whole hours", function()
    assert.are.equal("1", util.format_time(3600))
    assert.are.equal("2", util.format_time(7200))
    assert.are.equal("10", util.format_time(36000))
  end)

  it("returns 1 decimal place for fractional hours", function()
    assert.are.equal("1.5", util.format_time(5400))
    assert.are.equal("0.5", util.format_time(1800))
  end)

  it("handles quarter hour correctly", function()
    -- 900/3600 = 0.25, %.1f rounds to "0.2" (round half to even)
    assert.are.equal("0.2", util.format_time(900))
  end)
end)

describe("util.adf_to_markdown", function()
  it("returns empty string for nil input", function()
    assert.are.equal("", util.adf_to_markdown(nil))
  end)

  it("converts simple paragraph to markdown", function()
    local adf = {
      type = "doc",
      version = 1,
      content = {
        {
          type = "paragraph",
          content = {
            { type = "text", text = "hello" }
          }
        }
      }
    }
    local result = util.adf_to_markdown(adf)
    assert.are.equal("hello\n\n", result)
  end)

  it("converts bold text with strong mark", function()
    local adf = {
      type = "doc",
      version = 1,
      content = {
        {
          type = "paragraph",
          content = {
            {
              type = "text",
              text = "bold",
              marks = { { type = "strong" } }
            }
          }
        }
      }
    }
    local result = util.adf_to_markdown(adf)
    assert.are.equal("**bold**\n\n", result)
  end)

  it("converts heading level 2", function()
    local adf = {
      type = "doc",
      version = 1,
      content = {
        {
          type = "heading",
          attrs = { level = 2 },
          content = {
            { type = "text", text = "Title" }
          }
        }
      }
    }
    local result = util.adf_to_markdown(adf)
    assert.are.equal("## Title\n\n", result)
  end)

  it("converts italic text with em mark", function()
    local adf = {
      type = "doc",
      version = 1,
      content = {
        {
          type = "paragraph",
          content = {
            {
              type = "text",
              text = "italic",
              marks = { { type = "em" } }
            }
          }
        }
      }
    }
    local result = util.adf_to_markdown(adf)
    assert.are.equal("_italic_\n\n", result)
  end)

  it("converts code text with code mark", function()
    local adf = {
      type = "doc",
      version = 1,
      content = {
        {
          type = "paragraph",
          content = {
            {
              type = "text",
              text = "code",
              marks = { { type = "code" } }
            }
          }
        }
      }
    }
    local result = util.adf_to_markdown(adf)
    assert.are.equal("`code`\n\n", result)
  end)

  it("converts multiple paragraphs", function()
    local adf = {
      type = "doc",
      version = 1,
      content = {
        {
          type = "paragraph",
          content = {
            { type = "text", text = "first" }
          }
        },
        {
          type = "paragraph",
          content = {
            { type = "text", text = "second" }
          }
        }
      }
    }
    local result = util.adf_to_markdown(adf)
    assert.are.equal("first\n\nsecond\n\n", result)
  end)

  it("decodes html entities", function()
    local adf = {
      type = "doc",
      version = 1,
      content = {
        {
          type = "paragraph",
          content = {
            { type = "text", text = "hello &amp; goodbye" }
          }
        }
      }
    }
    local result = util.adf_to_markdown(adf)
    assert.are.equal("hello & goodbye\n\n", result)
  end)
end)
