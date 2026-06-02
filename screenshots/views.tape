Set Shell "bash"
Set FontSize 14
Set Width 1400
Set Height 900
Set Theme "Catppuccin Mocha"
Set WindowBar Colorful

# each shot runs a fresh nvim so sort/columns/float state never leaks between captures

Type `nvim --clean -u scripts/screenshots.lua -c 'lua JimScreenshot("sprint")'`
Enter
Sleep 2s
Screenshot screenshots/sprint.png
Escape
Type ":qa!"
Enter
Sleep 800ms

Type `nvim --clean -u scripts/screenshots.lua -c 'lua JimScreenshot("backlog")'`
Enter
Sleep 1500ms
Screenshot screenshots/backlog.png
Escape
Type ":qa!"
Enter
Sleep 800ms

Type `nvim --clean -u scripts/screenshots.lua -c 'lua JimScreenshot("my_issues")'`
Enter
Sleep 1500ms
Screenshot screenshots/my_issues.png
Escape
Type ":qa!"
Enter
Sleep 800ms

Type `nvim --clean -u scripts/screenshots.lua -c 'lua JimScreenshot("jql")'`
Enter
Sleep 1500ms
Screenshot screenshots/jql.png
Escape
Type ":qa!"
Enter
Sleep 800ms

Type `nvim --clean -u scripts/screenshots.lua -c 'lua JimScreenshot("help")'`
Enter
Sleep 1500ms
Screenshot screenshots/help.png
Escape
Type ":qa!"
Enter
Sleep 800ms

Type `nvim --clean -u scripts/screenshots.lua -c 'lua JimScreenshot("sort")'`
Enter
Sleep 1500ms
Screenshot screenshots/sort.png
Escape
Type ":qa!"
Enter
Sleep 800ms

Type `nvim --clean -u scripts/screenshots.lua -c 'lua JimScreenshot("columns")'`
Enter
Sleep 1500ms
Screenshot screenshots/columns.png
Escape
Type ":qa!"
Enter
Sleep 800ms

Type `nvim --clean -u scripts/screenshots.lua -c 'lua JimScreenshot("details")'`
Enter
Sleep 1500ms
Screenshot screenshots/details.png
Escape
Type ":qa!"
Enter
Sleep 800ms

Type `nvim --clean -u scripts/screenshots.lua -c 'lua JimScreenshot("create")'`
Enter
Sleep 1500ms
Screenshot screenshots/create.png
Escape
Escape
Type ":qa!"
Enter
Sleep 500ms
