# Fast, deterministic unit tests. POSIX make (macOS and Linux).
.POSIX:

NODE = node
SCRIPTS = installers/*.sh installers/lib/*.sh scripts/*.sh
ARGS =

all: test

help:
	@echo "make install    Install the harness globally (ARGS=\"--project\" etc.)"
	@echo "make uninstall  Remove the installed harness"
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

hooks:
	git config core.hooksPath .githooks
	@echo "pre-push hook installed (.githooks/pre-push)"

.PHONY: all help install uninstall lint test hooks
