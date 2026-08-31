SHELL := /bin/bash

.PHONY: setup generate-device-location-pigeon check-device-location-pigeon generate-device-display-pigeon check-device-display-pigeon collect-device-display-model generate-device-display-model validate-device-display-model validate-device-display-collectors check-device-display-publish-archive format check-format analyze test update-goldens test-with-coverage generate-api-docs check-example validate-android-native-code test-device-location-on-android-emulators validate-ios-native-code validate-native-code dry-run-publish analyze-package check clean

setup:
	fvm install
	fvm flutter pub upgrade
	cd example && fvm flutter pub get --enforce-lockfile

generate-device-location-pigeon:
	./tool/generate_device_location_pigeon.sh

check-device-location-pigeon:
	./tool/check_device_location_pigeon.sh

generate-device-display-pigeon:
	./tool/generate_device_display_pigeon.sh

check-device-display-pigeon:
	./tool/check_device_display_pigeon.sh

collect-device-display-model:
	./tool/device_display_model/collect_device_display_model.sh

generate-device-display-model:
	./tool/device_display_model/generate_device_display_model.sh

validate-device-display-model:
	./tool/device_display_model/validate_device_display_model.sh

validate-device-display-collectors:
	if [ "$$(uname -s)" = "Darwin" ]; then ./tool/device_display_model/validate_device_display_collectors.sh; else fvm dart run tool/device_display_model/device_display_model.dart check-collectors; fi

check-device-display-publish-archive:
	./tool/device_display_model/check_device_display_publish_archive.sh

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

validate-native-code: validate-android-native-code
	if [ "$$(uname -s)" = "Darwin" ]; then $(MAKE) validate-ios-native-code; fi

dry-run-publish:
	fvm flutter pub publish --dry-run

analyze-package:
	fvm dart pub global activate pana
	fvm dart pub global run pana .

check: check-device-location-pigeon check-device-display-pigeon validate-device-display-model validate-device-display-collectors check-format analyze test generate-api-docs check-example validate-native-code dry-run-publish check-device-display-publish-archive

clean:
	fvm flutter clean
	cd example && fvm flutter clean
