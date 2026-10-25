@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';

import 'contour_presentation_test_harness_vm.dart'
    if (dart.library.js_interop) 'contour_presentation_test_unsupported.dart'
    as native_tests;

void main() => native_tests.main();
