SHELL := /bin/bash

.PHONY: setup gen gen-check generate-pigeons generate-device-location-pigeon generate-device-display-pigeon generate-native-selectable-text-pigeon generate-country-names check-country-names check-pigeons check-device-location-pigeon check-device-display-pigeon check-native-selectable-text-pigeon generate-device-location-bindings check-device-location-bindings check-binding-tools format check-format analyze test update-goldens test-with-coverage generate-api-docs check-example validate-android-native-code test-device-location-on-android-emulators validate-ios-native-code validate-macos-native-code validate-linux-native-code validate-windows-native-code validate-native-code dry-run-publish analyze-package check clean

setup:
	fvm install
	fvm flutter pub upgrade --no-example
	cd example && fvm flutter pub get --enforce-lockfile

gen: generate-country-names generate-pigeons generate-country-bindings generate-device-location-bindings

gen-check: check-country-names check-pigeons check-country-bindings check-device-location-bindings

generate-pigeons: generate-device-location-pigeon generate-device-display-pigeon generate-native-selectable-text-pigeon

generate-country-names:
	fvm dart run tool/generate_country_names.dart

.PHONY: generate-country-bindings check-country-bindings generate-country-apple-bindings generate-country-android-bindings generate-country-windows-bindings check-country-apple-bindings check-country-android-bindings check-country-windows-bindings

generate-country-bindings: generate-country-apple-bindings generate-country-android-bindings generate-country-windows-bindings

check-country-bindings: check-country-apple-bindings check-country-android-bindings check-country-windows-bindings

generate-country-apple-bindings:
	./tool/generate_country_bindings.sh apple

generate-country-android-bindings:
	./tool/generate_country_bindings.sh android

generate-country-windows-bindings:
	./tool/generate_country_bindings.sh windows

check-country-apple-bindings:
	./tool/generate_country_bindings.sh apple --check

check-country-android-bindings:
	./tool/generate_country_bindings.sh android --check

check-country-windows-bindings:
	./tool/generate_country_bindings.sh windows --check

generate-device-location-bindings:
	./tool/generate_device_location_bindings.sh

check-device-location-bindings:
	./tool/generate_device_location_bindings.sh --check

check-binding-tools:
	cd tool/country_bindings && fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart test
	cd tool/device_location_bindings && fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart test

check-country-names:
	fvm dart run tool/generate_country_names.dart --check

generate-device-location-pigeon:
	./tool/generate_device_location_pigeon.sh

generate-native-selectable-text-pigeon:
	./tool/generate_native_selectable_text_pigeon.sh

check-device-location-pigeon:
	./tool/check_device_location_pigeon.sh

generate-device-display-pigeon:
	./tool/generate_device_display_pigeon.sh

check-device-display-pigeon:
	./tool/check_device_display_pigeon.sh

check-pigeons: check-device-location-pigeon check-device-display-pigeon check-native-selectable-text-pigeon

check-native-selectable-text-pigeon:
	./tool/check_native_selectable_text_pigeon.sh

format:
	fvm dart format hook lib pigeons test tool example/lib example/test example/integration_test example/benchmark

check-format:
	fvm dart format --output none --set-exit-if-changed hook lib pigeons test tool example/lib example/test example/integration_test example/benchmark

analyze:
	fvm flutter analyze --fatal-infos

test:
	fvm flutter test

update-goldens:
	fvm flutter test --update-goldens

test-with-coverage:
	fvm flutter test --coverage

generate-api-docs:
	rm -rf doc/api
	fvm dart doc --validate-links

check-example:
	cd example && fvm flutter analyze --fatal-infos
	cd example && fvm flutter test

validate-android-native-code:
	cd example && fvm flutter build apk --release
	cd example/android && ./gradlew :oh_my_flutter:testDebugUnitTest :oh_my_flutter:lintDebug

test-device-location-on-android-emulators:
	./tool/check_device_location_android_integration.sh

validate-ios-native-code:
	./tool/check_device_location_ios_integration.sh
	./tool/check_device_location_ios.sh
	cd example && fvm flutter pub get --enforce-lockfile
	cd example && fvm flutter build ios --simulator --target=lib/main.dart
	cd example && \
		device_line="$$(xcrun simctl list devices available | grep 'iPhone.*(Booted)' | head -n 1 || true)"; \
		if test -z "$$device_line"; then \
			device_line="$$(xcrun simctl list devices available | grep 'iPhone.*(Shutdown)' | tail -n 1)"; \
		fi; \
		device_id="$$(sed -E 's/.*\(([0-9A-F-]{36})\) \((Booted|Shutdown)\).*/\1/' <<<"$$device_line")"; \
		if ! [[ "$$device_id" =~ ^[0-9A-F-]{36}$$ ]]; then \
			echo 'No available iPhone simulator was found.' >&2; \
			exit 1; \
		fi; \
		flutter_framework_directory="$$PWD/build/ios/Debug-iphonesimulator"; \
		xcodebuild test \
			-quiet \
			-workspace ios/Runner.xcworkspace \
			-scheme oh_my_flutterTests \
			-destination "platform=iOS Simulator,id=$$device_id" \
			CODE_SIGNING_ALLOWED=NO \
			FRAMEWORK_SEARCH_PATHS="$$flutter_framework_directory" \
			LD_RUNPATH_SEARCH_PATHS="$$flutter_framework_directory"

validate-macos-native-code:
	cd example && fvm flutter pub get --enforce-lockfile
	cd example && fvm flutter build macos --debug --target=lib/main.dart
	cd example && \
		flutter_framework_directory="$$PWD/build/macos/Build/Products/Debug"; \
		xcodebuild test \
			-quiet \
			-workspace macos/Runner.xcworkspace \
			-scheme oh_my_flutterTests \
			-destination 'platform=macOS' \
			CODE_SIGNING_ALLOWED=NO \
			FRAMEWORK_SEARCH_PATHS="$$flutter_framework_directory" \
			LD_RUNPATH_SEARCH_PATHS="$$flutter_framework_directory"

validate-linux-native-code:
	cd example && fvm flutter pub get --enforce-lockfile
	cd example && fvm flutter build linux --debug --target=lib/main.dart
	cmake --build example/build/linux/x64/debug --target oh_my_flutter_test
	xvfb-run --auto-servernum ctest --test-dir example/build/linux/x64/debug/plugins/oh_my_flutter --output-on-failure

validate-windows-native-code:
	cd example && fvm flutter pub get --enforce-lockfile
	cd example && fvm flutter build windows --debug --target=lib/main.dart
	cmake --build example/build/windows/x64 --config Debug --target oh_my_flutter_test
	ctest --test-dir example/build/windows/x64/plugins/oh_my_flutter -C Debug --output-on-failure

validate-native-code: validate-android-native-code
	if [ "$$(uname -s)" = "Darwin" ]; then $(MAKE) validate-ios-native-code validate-macos-native-code; fi
	if [ "$$(uname -s)" = "Linux" ]; then $(MAKE) validate-linux-native-code; fi
	if [ "$${OS:-}" = "Windows_NT" ]; then $(MAKE) validate-windows-native-code; fi

dry-run-publish:
	fvm flutter pub publish --dry-run

analyze-package:
	fvm dart pub global activate pana
	fvm dart pub global run pana .

check: check-country-names check-pigeons check-binding-tools check-format analyze test generate-api-docs check-example validate-native-code dry-run-publish

clean:
	fvm flutter clean
	cd example && fvm flutter clean
