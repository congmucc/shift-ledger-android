SHELL := /bin/bash

.PHONY: help release release-dry-run

help:
	@echo "make release VERSION=1.2.3       Validate, tag, and push a manual release"
	@echo "make release-dry-run VERSION=1.2.3  Run release checks without changing git"

release:
	@./scripts/release.sh "$(VERSION)"

release-dry-run:
	@DRY_RUN=1 ./scripts/release.sh "$(VERSION)"
