# Run the unit tests after lint.

test: lint ## Run lint and all unit tests
	@tests=$$(find . -path ./node_modules -prune -o -path '*/node_modules' -prune \
	  -o -path './skills/*/assets' -prune -o -path ./.git -prune \
	  -o -type f \( -name '*.test.mjs' -o -path './scripts/test-*.mjs' \) -print | sort); \
	[ -n "$$tests" ] || { echo "no tests found" >&2; exit 1; }; \
	$(NODE) --test $$tests

.PHONY: test
