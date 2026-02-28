.PHONY: test screenshots

test:
	nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

screenshots:
	mkdir -p screenshots
	vhs screenshots/views.tape
