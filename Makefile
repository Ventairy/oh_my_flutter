SHELL := /bin/bash

.PHONY: setup format format-check analyze test coverage docs example publish-dry-run pana check clean

setup:
	fvm install
	fvm flutter pub upgrade
	cd example && fvm flutter pub get --enforce-lockfile

format:
	fvm dart format lib test example/lib/main.dart

format-check:
	fvm dart format --output none --set-exit-if-changed lib test example/lib/main.dart

analyze:
	fvm flutter analyze --fatal-infos

test:
	fvm flutter test

coverage:
	fvm flutter test --coverage

docs:
	rm -rf doc/api
	fvm dart doc --validate-links

example:
	cd example && fvm flutter analyze --fatal-infos

publish-dry-run:
	fvm flutter pub publish --dry-run

pana:
	fvm dart pub global activate pana
	fvm dart pub global run pana .

check: format-check analyze test docs example publish-dry-run

clean:
	fvm flutter clean
	cd example && fvm flutter clean
