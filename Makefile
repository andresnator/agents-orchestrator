# Commands only. Keep every target in this file so shell completion finds it.
# Logic that needs more than one line lives in make-scripts/<action>.sh.
.POSIX:

NODE = node
SCRIPTS = installers/*.sh installers/lib/*.sh scripts/*.sh make-scripts/*.sh
ARGS =
OPENCODE_DIR ?= $(if $(XDG_CONFIG_HOME),$(XDG_CONFIG_HOME),$(HOME)/.config)/opencode
DEFAULT_AGENT ?= orchestraitor
MAKE_ENV = OPENCODE_DIR="$(OPENCODE_DIR)" FORCE="$(FORCE)"

all: test

help: ## Show this help
	@grep -E '^[a-z0-9-]+:.*## ' Makefile | awk -F ':.*## ' '{ printf "make %-22s %s\n", $$1, $$2 }'

install: ## Install the harness globally (ARGS="--project" etc.)
	installers/opencode.sh install $(ARGS)

uninstall: ## Remove the installed harness
	installers/opencode.sh uninstall $(ARGS)

default-agent: ## Set DEFAULT_AGENT (orchestraitor) as the default OpenCode agent (FORCE=1 to replace)
	@$(MAKE_ENV) DEFAULT_AGENT="$(DEFAULT_AGENT)" make-scripts/default-agent.sh set

default-agent-remove: ## Remove default_agent if it is DEFAULT_AGENT
	@$(MAKE_ENV) DEFAULT_AGENT="$(DEFAULT_AGENT)" make-scripts/default-agent.sh remove

mini: ## Hide reasoning, tools, and shell output in OpenCode Mini (FORCE=1 to replace)
	@$(MAKE_ENV) bash make-scripts/mini.sh set

mini-remove: ## Remove the three Mini settings when their value is hide
	@$(MAKE_ENV) bash make-scripts/mini.sh remove

mcp: ## Add the Context7 and Engram MCP servers (FORCE=1 to replace)
	@$(MAKE_ENV) make-scripts/mcp.sh install all

mcp-remove: ## Remove the Context7 and Engram MCP servers we added
	@$(MAKE_ENV) make-scripts/mcp.sh remove all

mcp-context7: ## Add the Context7 MCP server (CONTEXT7_API_KEY set: send it as a header)
	@$(MAKE_ENV) make-scripts/mcp.sh install context7

mcp-context7-remove: ## Remove the Context7 MCP server if we added it
	@$(MAKE_ENV) make-scripts/mcp.sh remove context7

mcp-engram: ## Run engram setup opencode: MCP server and plugin (needs engram; FORCE=1 to replace)
	@$(MAKE_ENV) make-scripts/mcp.sh install engram

mcp-engram-remove: ## Remove the Engram MCP server and plugin if they are what engram setup adds
	@$(MAKE_ENV) make-scripts/mcp.sh remove engram

lint: ## Syntax-check shell scripts (bash -n)
	@for f in $(SCRIPTS); do bash -n "$$f" || exit 1; done

test: lint ## Run lint and all unit tests
	@NODE="$(NODE)" make-scripts/test.sh

hooks: ## Install the git pre-push hook
	git config core.hooksPath .githooks
	@echo "pre-push hook installed (.githooks/pre-push)"

.PHONY: all help install uninstall default-agent default-agent-remove mini mini-remove mcp mcp-remove mcp-context7 mcp-context7-remove mcp-engram mcp-engram-remove lint test hooks
