# Fast, deterministic unit tests. POSIX make (macOS and Linux).
.POSIX:

NODE = node
SCRIPTS = installers/*.sh installers/lib/*.sh scripts/*.sh
ARGS =
OPENCODE_DIR = $(HOME)/.config/opencode
DEFAULT_AGENT = orchestraitor

all: test

help:
	@echo "make install    Install the harness globally (ARGS=\"--project\" etc.)"
	@echo "make uninstall  Remove the installed harness"
	@echo "make default-agent         Set $(DEFAULT_AGENT) as the default OpenCode agent (FORCE=1 to replace)"
	@echo "make default-agent-remove  Remove default_agent if it is $(DEFAULT_AGENT)"
	@echo "make test   Run lint and all unit tests"
	@echo "make lint   Syntax-check shell scripts (bash -n)"
	@echo "make hooks  Install the git pre-push hook"
	@echo "make help   Show this help"

lint:
	@for f in $(SCRIPTS); do bash -n "$$f" || exit 1; done

test: lint
	@tests=$$(find . -path ./node_modules -prune -o -path '*/node_modules' -prune \
	  -o -path './skills/*/assets' -prune -o -path ./.git -prune \
	  -o -type f \( -name '*.test.mjs' -o -path './scripts/test-*.mjs' \) -print | sort); \
	[ -n "$$tests" ] || { echo "no tests found" >&2; exit 1; }; \
	$(NODE) --test $$tests

install:
	installers/opencode.sh install $(ARGS)

uninstall:
	installers/opencode.sh uninstall $(ARGS)

# Pick opencode.jsonc, else opencode.json, else a new opencode.jsonc.
OPENCODE_CONFIG = f="$(OPENCODE_DIR)/opencode.jsonc"; \
	[ -e "$$f" ] || [ ! -e "$(OPENCODE_DIR)/opencode.json" ] || f="$(OPENCODE_DIR)/opencode.json"

# Write through cat so symlinks and file modes stay intact. Never touch a
# default_agent the user picked, unless FORCE=1.
JSONC_EDIT = tmp=$$(mktemp); python3 scripts/jsonc-array.py

default-agent:
	@$(OPENCODE_CONFIG); mkdir -p "$(OPENCODE_DIR)"; \
	cur=$$(python3 scripts/jsonc-array.py get "$$f" default_agent 2>/dev/null || true); \
	if [ "$$cur" = '"$(DEFAULT_AGENT)"' ]; then echo "default_agent already $(DEFAULT_AGENT)"; exit 0; fi; \
	if [ -n "$$cur" ] && [ -z "$(FORCE)" ]; then echo "default_agent is $$cur in $$f; run with FORCE=1 to replace it" >&2; exit 1; fi; \
	[ -e "$(OPENCODE_DIR)/agents/$(DEFAULT_AGENT).md" ] || echo "warning: agent $(DEFAULT_AGENT) is not installed; run make install" >&2; \
	$(JSONC_EDIT) set "$$f" default_agent '"$(DEFAULT_AGENT)"' > "$$tmp" || { rm -f "$$tmp"; exit 1; }; \
	[ -e "$$f" ] || { touch "$$f"; chmod 600 "$$f"; }; \
	cat "$$tmp" > "$$f"; rm -f "$$tmp"; echo "default_agent = $(DEFAULT_AGENT) in $$f"

default-agent-remove:
	@$(OPENCODE_CONFIG); \
	cur=$$(python3 scripts/jsonc-array.py get "$$f" default_agent 2>/dev/null || true); \
	if [ "$$cur" != '"$(DEFAULT_AGENT)"' ]; then echo "default_agent is not $(DEFAULT_AGENT); nothing to remove"; exit 0; fi; \
	$(JSONC_EDIT) remove-property "$$f" default_agent > "$$tmp" || { rm -f "$$tmp"; exit 1; }; \
	cat "$$tmp" > "$$f"; rm -f "$$tmp"; echo "default_agent removed from $$f"

hooks:
	git config core.hooksPath .githooks
	@echo "pre-push hook installed (.githooks/pre-push)"

.PHONY: all help install uninstall default-agent default-agent-remove lint test hooks
