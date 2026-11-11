# Entry point only. Each action lives in its own file under make/.
.POSIX:

NODE = node
SCRIPTS = installers/*.sh installers/lib/*.sh scripts/*.sh
ARGS =
OPENCODE_DIR = $(HOME)/.config/opencode

all: test

include make/*.mk

help: ## Show this help
	@grep -h -E '^[a-z-]+:.*## ' make/*.mk Makefile | sort | \
	  awk -F ':.*## ' '{ printf "make %-22s %s\n", $$1, $$2 }'

.PHONY: all help
