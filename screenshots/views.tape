Set Shell "bash"
Set FontSize 14
Set Width 1400
Set Height 900
Set Theme "Catppuccin Mocha"
Set WindowBar Colorful

Type `nvim --clean -u scripts/screenshots.lua -c 'lua JimScreenshot("sprint")'`
Enter
Sleep 2s
Screenshot screenshots/sprint.png

Type `:lua JimScreenshot("backlog")`
Enter
Sleep 1s
Screenshot screenshots/backlog.png

Type `:lua JimScreenshot("my_issues")`
Enter
Sleep 1s
Screenshot screenshots/my_issues.png

Type `:lua JimScreenshot("jql")`
Enter
Sleep 1s
Screenshot screenshots/jql.png

Type `:lua JimScreenshot("help")`
Enter
Sleep 1s
Screenshot screenshots/help.png

Type `:qa!`
Enter
