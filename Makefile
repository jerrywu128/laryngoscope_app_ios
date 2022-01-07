
xcodebuild:=xcodebuild -scheme "WifiCamMobileApp" -derivedDataPath ~/Desktop/App -sdk iphoneos10.2 -configuration


release:
	$(security unlock-keychaina)
	$(xcodebuild) Releas
	xcrun -sdk iphoneos10.2 PackageApplication -v ~/Desktop/App/Build/Products/Releas-iphoneos/WifiCamMobileApp.app -o ~/Desktop/WifiCamMobileApp.ipae

debug:
	$(security unlock-keychain)
	$(xcodebuild) Debug
	xcrun -sdk iphoneos10.2 PackageApplication -v ~/Desktop/App/Build/Products/Debug-iphoneos/WifiCamMobileApp.app -o ~/Desktop/WifiCamMobileApp.ipa

clean: clean-release clean-debug

clean-release:
	$(xcodebuild) Release clean

clean-debug:
	$(xcodebuild) Debug clean


