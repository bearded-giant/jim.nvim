local sprint = require("jim.jira-api.sprint")

describe("sprint.normalize_jql", function()
  it("rewrites a bare issue key to a key lookup", function()
    assert.are.equal("key = REF-372", sprint.normalize_jql("REF-372"))
  end)

  it("uppercases and trims a bare key", function()
    assert.are.equal("key = REF-372", sprint.normalize_jql("  ref-372  "))
  end)

  it("handles alphanumeric project keys", function()
    assert.are.equal("key = AB12-5", sprint.normalize_jql("AB12-5"))
  end)

  it("leaves a real JQL query untouched", function()
    local jql = 'project = UXUI AND status = "Groomed" ORDER BY status DESC'
    assert.are.equal(jql, sprint.normalize_jql(jql))
  end)

  it("leaves an explicit key query untouched", function()
    assert.are.equal("key = REF-372", sprint.normalize_jql("key = REF-372"))
  end)

  it("does not touch multi-token input that merely starts with a key", function()
    assert.are.equal("REF-372 OR REF-9", sprint.normalize_jql("REF-372 OR REF-9"))
  end)

  it("passes through nil and empty", function()
    assert.is_nil(sprint.normalize_jql(nil))
    assert.are.equal("", sprint.normalize_jql(""))
  end)
end)
