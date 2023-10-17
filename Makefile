all: test-package build-ui-preview

test-package:
	cd app/xcode && swift test

build-ui-preview:
	cd app/xcode/App && xcodebuild -project VCam.xcodeproj -scheme VCamUIPreview -derivedDataPath /tmp/build clean build

