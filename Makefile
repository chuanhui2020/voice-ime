APP_NAME = VoiceIME
BUILD_DIR = .build/release
APP_BUNDLE = $(APP_NAME).app
INSTALL_DIR = /Applications

.PHONY: build run install clean

build:
	swift build -c release
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	codesign --force --deep --sign - \
		--entitlements Resources/VoiceIME.entitlements \
		$(APP_BUNDLE)

run: build
	open $(APP_BUNDLE)

install: build
	cp -R $(APP_BUNDLE) $(INSTALL_DIR)/$(APP_BUNDLE)

clean:
	swift package clean
	rm -rf $(APP_BUNDLE)
