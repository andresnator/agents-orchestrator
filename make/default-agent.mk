# Set or remove default_agent in the global OpenCode config.

DEFAULT_AGENT = orchestraitor

# Pick opencode.jsonc, else opencode.json, else a new opencode.jsonc.
OPENCODE_CONFIG = f="$(OPENCODE_DIR)/opencode.jsonc"; \
	[ -e "$$f" ] || [ ! -e "$(OPENCODE_DIR)/opencode.json" ] || f="$(OPENCODE_DIR)/opencode.json"

# Write through cat so symlinks and file modes stay intact. Never touch a
# default_agent the user picked, unless FORCE=1.
JSONC_EDIT = tmp=$$(mktemp); python3 scripts/jsonc-array.py

default-agent: ## Set DEFAULT_AGENT (orchestraitor) as the default OpenCode agent (FORCE=1 to replace)
	@$(OPENCODE_CONFIG); mkdir -p "$(OPENCODE_DIR)"; \
	cur=$$(python3 scripts/jsonc-array.py get "$$f" default_agent 2>/dev/null || true); \
	if [ "$$cur" = '"$(DEFAULT_AGENT)"' ]; then echo "default_agent already $(DEFAULT_AGENT)"; exit 0; fi; \
	if [ -n "$$cur" ] && [ -z "$(FORCE)" ]; then echo "default_agent is $$cur in $$f; run with FORCE=1 to replace it" >&2; exit 1; fi; \
	[ -e "$(OPENCODE_DIR)/agents/$(DEFAULT_AGENT).md" ] || echo "warning: agent $(DEFAULT_AGENT) is not installed; run make install" >&2; \
	$(JSONC_EDIT) set "$$f" default_agent '"$(DEFAULT_AGENT)"' > "$$tmp" || { rm -f "$$tmp"; exit 1; }; \
	[ -e "$$f" ] || { touch "$$f"; chmod 600 "$$f"; }; \
	cat "$$tmp" > "$$f"; rm -f "$$tmp"; echo "default_agent = $(DEFAULT_AGENT) in $$f"

default-agent-remove: ## Remove default_agent if it is DEFAULT_AGENT
	@$(OPENCODE_CONFIG); \
	cur=$$(python3 scripts/jsonc-array.py get "$$f" default_agent 2>/dev/null || true); \
	if [ "$$cur" != '"$(DEFAULT_AGENT)"' ]; then echo "default_agent is not $(DEFAULT_AGENT); nothing to remove"; exit 0; fi; \
	$(JSONC_EDIT) remove-property "$$f" default_agent > "$$tmp" || { rm -f "$$tmp"; exit 1; }; \
	cat "$$tmp" > "$$f"; rm -f "$$tmp"; echo "default_agent removed from $$f"

.PHONY: default-agent default-agent-remove
