local config = require("jim.config")

describe("config.setup", function()
  -- save defaults before each test
  local original_defaults

  before_each(function()
    original_defaults = vim.deepcopy(config.defaults)
  end)

  after_each(function()
    config.options = vim.deepcopy(original_defaults)
  end)

  it("initializes with expected default structure", function()
    config.setup({})
    assert.is_not_nil(config.options.jira)
    assert.are.equal("", config.options.jira.base)
    assert.are.equal("", config.options.jira.email)
    assert.are.equal("", config.options.jira.token)
    assert.are.equal(500, config.options.jira.limit)
  end)

  it("has keymaps in defaults", function()
    config.setup({})
    assert.is_not_nil(config.options.keymaps)
    assert.is_not_nil(config.options.keymaps.toggle_node)
    assert.are.equal("t", config.options.keymaps.toggle_all)
  end)

  it("merges jira config correctly", function()
    config.setup({ jira = { base = "https://test.atlassian.net" } })
    assert.are.equal("https://test.atlassian.net", config.options.jira.base)
    assert.are.equal("", config.options.jira.email)
    assert.are.equal(500, config.options.jira.limit)
  end)

  it("merges keymap override into defaults", function()
    config.setup({ keymaps = { close = "Q" } })
    assert.are.equal("Q", config.options.keymaps.close)
    assert.are.equal("t", config.options.keymaps.toggle_all)
  end)

  it("handles nested keymap arrays", function()
    config.setup({ keymaps = { toggle_node = { "o" } } })
    assert.are.equal(1, #config.options.keymaps.toggle_node)
    assert.are.equal("o", config.options.keymaps.toggle_node[1])
  end)

  it("merges projects config", function()
    config.setup({ projects = { ["TEST"] = { story_point_field = "custom_123" } } })
    assert.is_not_nil(config.options.projects["TEST"])
    assert.are.equal("custom_123", config.options.projects["TEST"].story_point_field)
  end)

  it("does not mutate defaults on setup", function()
    local original_base = config.defaults.jira.base
    config.setup({ jira = { base = "https://changed.com" } })
    assert.are.equal(original_base, config.defaults.jira.base)
  end)
end)

describe("config.get_project_config", function()
  -- save defaults before each test
  local original_defaults

  before_each(function()
    original_defaults = vim.deepcopy(config.defaults)
  end)

  after_each(function()
    config.options = vim.deepcopy(original_defaults)
  end)

  it("returns fallback values when no project configured", function()
    config.setup({})
    local proj_config = config.get_project_config("UNKNOWN")
    assert.are.equal("customfield_10035", proj_config.story_point_field)
    assert.are.equal("customfield_10016", proj_config.acceptance_criteria_field)
  end)

  it("returns configured project values when available", function()
    config.setup({
      projects = {
        ["TEST"] = {
          story_point_field = "custom_100",
          acceptance_criteria_field = "custom_200",
        }
      }
    })
    local proj_config = config.get_project_config("TEST")
    assert.are.equal("custom_100", proj_config.story_point_field)
    assert.are.equal("custom_200", proj_config.acceptance_criteria_field)
  end)

  it("returns fallback when project_key is nil", function()
    config.setup({})
    local proj_config = config.get_project_config(nil)
    assert.are.equal("customfield_10035", proj_config.story_point_field)
  end)

  it("returns fallback for unconfigured field in configured project", function()
    config.setup({
      projects = {
        ["TEST"] = {
          story_point_field = "custom_100",
        }
      }
    })
    local proj_config = config.get_project_config("TEST")
    assert.are.equal("custom_100", proj_config.story_point_field)
    assert.are.equal("customfield_10016", proj_config.acceptance_criteria_field)
  end)

  it("only returns story_point_field and acceptance_criteria_field", function()
    config.setup({
      projects = {
        ["TEST"] = {
          story_point_field = "custom_100",
          acceptance_criteria_field = "custom_200",
          other_field = "should_not_appear",
        }
      }
    })
    local proj_config = config.get_project_config("TEST")
    assert.is_nil(proj_config.other_field)
    assert.is_not_nil(proj_config.story_point_field)
  end)
end)
