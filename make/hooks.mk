# Install the git hooks from .githooks/.

hooks: ## Install the git pre-push hook
	git config core.hooksPath .githooks
	@echo "pre-push hook installed (.githooks/pre-push)"

.PHONY: hooks
