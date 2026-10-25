import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_session.dart';
import 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_trace_policy.dart';

void main() {
  test('when Android captures the prior 188034-pixel fixture, it should retain Dart tracing', () {
    expect(
      const ContourNativeTracePolicy.test(isAndroid: true).additionalSourceBytesWithinBudget(
        pixels: 188034,
        legacyBytes: 24 * 1024 * 1024,
        budgetBytes: 64 * 1024 * 1024,
      ),
      0,
    );
  });

  test('when Android captures the measured 543004-pixel fixture, it should reserve native bookkeeping', () {
    expect(
      const ContourNativeTracePolicy.test(isAndroid: true).additionalSourceBytesWithinBudget(
        pixels: 543004,
        legacyBytes: 24 * 1024 * 1024,
        budgetBytes: 64 * 1024 * 1024,
      ),
      4096,
    );
  });
  const minimumPixels = 512 * 1024;
  const budgetBytes = 64 * 1024 * 1024;
  const android = ContourNativeTracePolicy.test(isAndroid: true);
  const unsupported = ContourNativeTracePolicy.test(isAndroid: false);

  test('when an Android source is one pixel below the threshold, it should preserve the Dart path', () {
    expect(
      android.additionalSourceBytesWithinBudget(
        pixels: minimumPixels - 1,
        legacyBytes: 1024 * 1024,
        budgetBytes: budgetBytes,
      ),
      0,
    );
  });

  test('when an Android source reaches the threshold, it should reserve native job overhead', () {
    expect(
      android.additionalSourceBytesWithinBudget(
        pixels: minimumPixels,
        legacyBytes: 1024 * 1024,
        budgetBytes: budgetBytes,
      ),
      4096,
    );
  });

  test('when a larger Android source is eligible, it should retain the fixed job allowance', () {
    expect(
      android.additionalSourceBytesWithinBudget(
        pixels: 3 * 1024 * 1024,
        legacyBytes: 60 * 1024 * 1024,
        budgetBytes: budgetBytes,
      ),
      4096,
    );
  });

  test('when native job overhead reaches capacity exactly, it should preserve native eligibility', () {
    expect(
      android.additionalSourceBytesWithinBudget(
        pixels: minimumPixels,
        legacyBytes: budgetBytes - 4096,
        budgetBytes: budgetBytes,
      ),
      4096,
    );
  });

  test('when native job overhead exceeds capacity by one byte, it should preserve the Dart path', () {
    expect(
      android.additionalSourceBytesWithinBudget(
        pixels: minimumPixels,
        legacyBytes: budgetBytes - 4096 + 1,
        budgetBytes: budgetBytes,
      ),
      0,
    );
  });

  test('when a large source runs on an unsupported platform, it should preserve the Dart path', () {
    expect(
      unsupported.additionalSourceBytesWithinBudget(
        pixels: 3 * 1024 * 1024,
        legacyBytes: 60 * 1024 * 1024,
        budgetBytes: budgetBytes,
      ),
      0,
    );
  });

  test('when platform policies coexist, it should keep support specific to each instance', () {
    expect((android.isSupported, unsupported.isSupported), (true, false));
  });

  test('when the production policy is created, it should follow the actual Android platform capability', () {
    expect(
      ContourNativeTracePolicy().isSupported,
      ContourNativePortSession.isAndroid,
    );
  });

  for (final invalid in const {
    'pixel count is zero': (pixels: 0, legacyBytes: 1, budgetBytes: 1),
    'pixel count is negative': (pixels: -1, legacyBytes: 1, budgetBytes: 1),
    'legacy allowance is zero': (pixels: 1, legacyBytes: 0, budgetBytes: 1),
    'legacy allowance is negative': (
      pixels: 1,
      legacyBytes: -1,
      budgetBytes: 1,
    ),
    'budget capacity is zero': (pixels: 1, legacyBytes: 1, budgetBytes: 0),
    'budget capacity is negative': (pixels: 1, legacyBytes: 1, budgetBytes: -1),
  }.entries) {
    test(
      'when the ${invalid.key}, it should diagnose invalid configuration',
      () {
        expect(
          () => android.additionalSourceBytesWithinBudget(
            pixels: invalid.value.pixels,
            legacyBytes: invalid.value.legacyBytes,
            budgetBytes: invalid.value.budgetBytes,
          ),
          throwsAssertionError,
        );
      },
    );
  }
}
