# Contributing

Thanks for your interest in contributing to jim.nvim!

## Issues

Found a bug or have a feature request? [Open an issue](https://github.com/bearded-giant/jim.nvim/issues/new).

Please include:
- Neovim version (`nvim --version`)
- Steps to reproduce (for bugs)
- Expected vs actual behavior

## Pull Requests

PRs are welcome! For larger changes, consider opening an issue first to discuss.

1. Fork the repo
2. Create a branch (`git checkout -b my-feature`)
3. Make your changes
4. Test manually (`:Jim` command, keymaps, etc.)
5. Submit a PR

## Development

No build step required. To test locally:

```lua
vim.opt.rtp:prepend('/path/to/jim.nvim')
require('jim').setup({ jira = { base = "...", email = "...", token = "..." } })
```

Then run `:Jim` to test.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
