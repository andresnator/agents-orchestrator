# Syntax-check the shell scripts.

lint: ## Syntax-check shell scripts (bash -n)
	@for f in $(SCRIPTS); do bash -n "$$f" || exit 1; done

.PHONY: lint
