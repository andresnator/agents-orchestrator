# Install and remove the harness with installers/opencode.sh.

install: ## Install the harness globally (ARGS="--project" etc.)
	installers/opencode.sh install $(ARGS)

uninstall: ## Remove the installed harness
	installers/opencode.sh uninstall $(ARGS)

.PHONY: install uninstall
