all: test-package build-ui-preview test-ui-preview

test-package:
	cd app/xcode && swift test

build-ui-preview:
	cd app/xcode/App && xcodebuild -project VCam.xcodeproj -scheme VCamUIPreview -derivedDataPath /tmp/build clean build

test-ui-preview:
	cd app/xcode/App && xcodebuild -project VCam.xcodeproj -scheme VCamUIPreviewUITests -derivedDataPath /tmp/build -resultBundlePath /tmp/UITestResults test CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

