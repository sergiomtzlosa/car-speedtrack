PYTHON ?= python3
XCODEBUILD ?= xcodebuild
PROJECT := CarSpeedtrack.xcodeproj
SCHEME := CarSpeedtrack
DERIVED := build
APP := $(DERIVED)/Build/Products/Debug/CarSpeedtrack.app

.PHONY: all assets project build test run check clean

all: build

assets:
	$(PYTHON) Tools/generate_art.py
	$(PYTHON) Tools/generate_levels.py
	$(PYTHON) Tools/generate_app_icon.py
	$(PYTHON) Tools/generate_music.py
	$(PYTHON) Tools/validate_assets.py

project:
	xcodegen generate

build: project
	$(XCODEBUILD) -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-derivedDataPath $(DERIVED) CODE_SIGNING_ALLOWED=NO build

test: project
	$(XCODEBUILD) -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-derivedDataPath $(DERIVED) CODE_SIGNING_ALLOWED=NO \
		-destination 'platform=macOS' test

run: build
	open "$(APP)"

check: project
	$(PYTHON) Tools/validate_assets.py
	$(XCODEBUILD) -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-derivedDataPath $(DERIVED) CODE_SIGNING_ALLOWED=NO build
	$(XCODEBUILD) -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-derivedDataPath $(DERIVED) CODE_SIGNING_ALLOWED=NO \
		-destination 'platform=macOS' test

clean:
	rm -rf $(DERIVED) $(PROJECT)
