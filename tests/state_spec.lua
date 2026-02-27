local state = require("jim.state")

describe("state.assignable_users_cache", function()
  before_each(function()
    -- clear cache before each test
    state.assignable_users_cache = {}
  end)

  it("returns nil when no cache entry exists", function()
    local result = state.get_assignable_users("PROJ")
    assert.is_nil(result)
  end)

  it("returns users after set_assignable_users", function()
    local users = {
      { name = "Alice", accountId = "123" },
      { name = "Bob", accountId = "456" },
    }
    state.set_assignable_users("PROJ", users)
    local result = state.get_assignable_users("PROJ")
    assert.are.same(users, result)
  end)

  it("returns nil when cache entry is expired (>86400 seconds old)", function()
    local users = { { name = "Alice" } }
    state.set_assignable_users("PROJ", users)

    -- simulate time passing: set fetched_at to past
    state.assignable_users_cache["PROJ"].fetched_at = os.time() - 86401
    local result = state.get_assignable_users("PROJ")
    assert.is_nil(result)
  end)

  it("returns users when cache entry is fresh (<86400 seconds old)", function()
    local users = { { name = "Alice" } }
    state.set_assignable_users("PROJ", users)

    -- simulate recent cache
    state.assignable_users_cache["PROJ"].fetched_at = os.time() - 3600
    local result = state.get_assignable_users("PROJ")
    assert.are.same(users, result)
  end)

  it("handles multiple project caches independently", function()
    local users1 = { { name = "Alice" } }
    local users2 = { { name = "Bob" } }
    state.set_assignable_users("PROJ1", users1)
    state.set_assignable_users("PROJ2", users2)

    assert.are.same(users1, state.get_assignable_users("PROJ1"))
    assert.are.same(users2, state.get_assignable_users("PROJ2"))
  end)

  it("stores fetched_at timestamp on set", function()
    local users = { { name = "Alice" } }
    state.set_assignable_users("PROJ", users)
    local entry = state.assignable_users_cache["PROJ"]
    assert.is_not_nil(entry.fetched_at)
    assert.is_true(entry.fetched_at > 0)
  end)

  it("returns nil for expired cache even with valid users", function()
    local users = { { name = "Alice" }, { name = "Bob" } }
    state.set_assignable_users("PROJ", users)
    state.assignable_users_cache["PROJ"].fetched_at = os.time() - 172800
    local result = state.get_assignable_users("PROJ")
    assert.is_nil(result)
  end)
end)
