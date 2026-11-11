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
	@echo "make default-agent         Open OpenCode with $(DEFAULT_AGENT) selected"
	@echo "make default-agent-remove  Remove default_agent from the OpenCode config"
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

default-agent:
	@rc=0; $(OPENCODE_CONFIG); mkdir -p "$(OPENCODE_DIR)"; \
	python3 scripts/jsonc-array.py set "$$f" default_agent '"$(DEFAULT_AGENT)"' > "$$f.tmp" || rc=$$?; \
	if [ "$$rc" -eq 0 ]; then mv "$$f.tmp" "$$f"; echo "default_agent = $(DEFAULT_AGENT) in $$f"; \
	else rm -f "$$f.tmp"; [ $$rc -eq 3 ] || exit $$rc; echo "default_agent already $(DEFAULT_AGENT)"; fi

default-agent-remove:
	@rc=0; $(OPENCODE_CONFIG); [ -e "$$f" ] || exit 0; \
	python3 scripts/jsonc-array.py remove-property "$$f" default_agent > "$$f.tmp" || rc=$$?; \
	if [ "$$rc" -eq 0 ]; then mv "$$f.tmp" "$$f"; echo "default_agent removed from $$f"; \
	else rm -f "$$f.tmp"; [ $$rc -eq 3 ] || exit $$rc; echo "default_agent not set"; fi

hooks:
	git config core.hooksPath .githooks
	@echo "pre-push hook installed (.githooks/pre-push)"

.PHONY: all help install uninstall default-agent default-agent-remove lint test hooks
