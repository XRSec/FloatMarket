APP_NAME := FloatMarket
PROJECT := $(APP_NAME).xcodeproj
SCHEME := $(APP_NAME)
DERIVED_DATA_PATH := $(HOME)/Library/Developer/Xcode/DerivedData/$(APP_NAME)
APP_PATH := $(DERIVED_DATA_PATH)/Build/Products/Release/$(APP_NAME).app
DEBUG_APP_PATH := $(DERIVED_DATA_PATH)/Build/Products/Debug/$(APP_NAME).app
VERSION := $(shell /usr/bin/python3 -c 'from pathlib import Path; import re; text = Path("FloatMarket.xcodeproj/project.pbxproj").read_text(); match = re.search(r"MARKETING_VERSION = ([^;]+);", text); print(match.group(1).strip() if match else "0.0.0")')
DMG_NAME := $(APP_NAME)-$(VERSION).dmg
DMG_TEMP_DIR := /tmp/$(APP_NAME)-dmg
DMG_ASSETS_DIR := $(CURDIR)/dmg-assets
DMG_SCRIPT := $(CURDIR)/scripts/package_dmg.sh

.PHONY: list build build-debug run debug dmg clean version

list:
	@xcodebuild -list -project "$(PROJECT)"

version:
	@echo "$(VERSION)"

build:
	@xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration Release -arch arm64 -derivedDataPath "$(DERIVED_DATA_PATH)" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO clean build

build-debug:
	@xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration Debug -arch arm64 -derivedDataPath "$(DERIVED_DATA_PATH)" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO clean build

run: build
	@open "$(APP_PATH)"

debug: build-debug
	@open "$(DEBUG_APP_PATH)"

dmg: build
	@echo "Packaging $(DMG_NAME)..."
	@"$(DMG_SCRIPT)" "$(APP_NAME)" "$(APP_PATH)" "$(DMG_NAME)" "$(DMG_TEMP_DIR)" "$(DMG_ASSETS_DIR)"
	@echo "DMG created: $(DMG_NAME)"

clean:
	@rm -rf "$(DERIVED_DATA_PATH)"
	@rm -f "$(DMG_NAME)"
