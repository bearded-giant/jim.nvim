vim.api.nvim_create_user_command("Jim", function(opts)
  require("jim").open(opts.args ~= "" and opts.args or nil)
end, { nargs = "?" })
