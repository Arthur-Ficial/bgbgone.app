APP_NAME    = bgbgone-app
APP_BUNDLE  = build/$(APP_NAME).app
APP_DIR    ?= /Applications
BIN_DIR    ?= $(HOME)/.local/bin
SCRATCH    = --scratch-path build
VENDOR_BIN  = vendor/bgbgone/.build/release/bgbgone

.PHONY: build test app run dist install install-app install-cli release clean screenshots vendor

build:
	swift build -c release $(SCRATCH)

# Build the pinned, version-locked bgbgone CLI from the submodule. Idempotent:
# only (re)builds when the release binary is missing. The real-binary e2e
# (RealBinaryE2ETests) runs against this; without it the e2e SKIPS.
vendor: $(VENDOR_BIN)

$(VENDOR_BIN):
	git submodule update --init --recursive
	$(MAKE) -C vendor/bgbgone build

test: vendor
	swift test $(SCRATCH)

app:
	./scripts/build-app.sh

run: app
	open "$(APP_BUNDLE)"

# Drive the running app through its UI states, capturing one PNG per state. CI uploads
# the resulting build/screenshots/ as an artifact.
screenshots: app
	./scripts/screenshot-tour.sh

dist:
	./scripts/build-dist.sh

release:
	./scripts/release.sh

install: install-app

install-app: app
	@if [ -w "$(APP_DIR)" ]; then \
		rm -rf "$(APP_DIR)/$(APP_NAME).app"; \
		ditto "$(APP_BUNDLE)" "$(APP_DIR)/$(APP_NAME).app"; \
	else \
		sudo rm -rf "$(APP_DIR)/$(APP_NAME).app"; \
		sudo ditto "$(APP_BUNDLE)" "$(APP_DIR)/$(APP_NAME).app"; \
	fi
	@echo "Installed $(APP_NAME).app to $(APP_DIR)"

install-cli: install-app
	@mkdir -p "$(BIN_DIR)"
	@ln -sf "$(APP_DIR)/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" "$(BIN_DIR)/$(APP_NAME)"
	@echo "Linked $(APP_NAME) into $(BIN_DIR)"

clean:
	swift package clean
	rm -rf .build build dist
