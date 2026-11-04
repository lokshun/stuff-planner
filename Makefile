ifeq ($(OS),Windows_NT)
    LUACHECK ?= .lua/bin/luacheck.bat
    BUSTED ?= .lua/bin/busted.bat
    PYTHON ?= .venv/Scripts/python.exe
else
    LUACHECK ?= luacheck
    BUSTED ?= busted
    PYTHON ?= python3
endif

# Windows : recettes en ASCII (make réencode les accents) ; `sh` et non `bash`
# (bash peut désigner le lanceur WSL) ; `|| exit 1` force le passage par sh,
# sans quoi make lance le .bat via cmd, qui refuse ce chemin.

.PHONY: lint check test data overlay weights arrow wowsims deploy zip

# Analyse statique seule (utilisée par la CI).
lint:
	@$(LUACHECK) -q --formatter plain StuffPlanner || exit 1
	@sh tools/check_direct_api.sh

# lint + tests busted (dossier tests/ local, non publié).
check: lint
	@$(LUACHECK) -q --formatter plain tests || exit 1
	@$(BUSTED) -o TAP | sh tools/tap_summary.sh

# make test T=Scoring lance tests/scoring_spec.lua
test:
	@test -n "$(T)" || { echo "Usage : make test T=<Nom>"; exit 2; }
	@$(BUSTED) -o TAP "tests/$$(echo '$(T)' | tr '[:upper:]' '[:lower:]')_spec.lua" | sh tools/tap_summary.sh

data:
	@$(PYTHON) tools/build_db.py || exit 1

overlay:
	@$(PYTHON) tools/merge_exports.py || exit 1

arrow:
	@$(PYTHON) tools/gen_arrow.py || exit 1

weights:
	@$(PYTHON) tools/gen_weights.py || exit 1

wowsims:
	@$(PYTHON) tools/import_wowsims.py || exit 1
	@$(PYTHON) tools/gen_weights.py || exit 1

deploy:
	@sh tools/deploy.sh

zip:
	@sh tools/fetch_libs.sh
	@$(PYTHON) tools/package.py || exit 1
