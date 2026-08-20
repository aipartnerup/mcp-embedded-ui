.DEFAULT_GOAL := help

.PHONY: help sync-html install-hooks

help:  ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

sync-html:  ## Copy docs/explorer.html into every checked-out SDK repo
	@scripts/sync-explorer.sh

install-hooks:  ## Point git at .githooks (one-time, per clone)
	@git config core.hooksPath .githooks
	@echo "core.hooksPath -> .githooks"
	@echo "docs/explorer.html will now sync to the SDK repos after each commit that touches it."
