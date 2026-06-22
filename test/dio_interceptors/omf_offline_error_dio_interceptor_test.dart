import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import '../mocks.dart';

class _ThrowingAdapter implements HttpClientAdapter {
  _ThrowingAdapter(this.exception);

  final DioException exception;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw exception;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late MockInternetConnection mockConnection;
  late Dio dioWithInterceptor;

  setUp(() {
    mockConnection = MockInternetConnection();
    when(() => mockConnection.dispose()).thenAnswer((_) async {});
  });

  void buildDio({required DioExceptionType type, String message = ''}) {
    final exception = DioException(
      requestOptions: RequestOptions(path: '/jobs'),
      type: type,
      message: message,
    );

    dioWithInterceptor = Dio()
      ..httpClientAdapter = _ThrowingAdapter(exception)
      ..interceptors.add(OmfOfflineErrorDioInterceptor.test(internetConnection: mockConnection));
  }

  group('OfflineErrorDioInterceptor', () {
    group('when the device is offline', () {
      setUp(() {
        when(() => mockConnection.hasInternetAccess).thenAnswer((_) async => false);
      });

      test('when the dio error is connectionError and device is offline, '
          'it should wrap the error with OfflineConnectionException', () async {
        buildDio(type: DioExceptionType.connectionError);

        await expectLater(
          dioWithInterceptor.get<void>('/jobs'),
          throwsA(isA<DioException>().having((e) => e.error, 'error', isA<OmfOfflineConnectionDioException>())),
        );
      });

      test('when the dio error is connectionTimeout and device is offline, '
          'it should wrap the error with OfflineConnectionException', () async {
        buildDio(type: DioExceptionType.connectionTimeout);

        await expectLater(
          dioWithInterceptor.get<void>('/jobs'),
          throwsA(isA<DioException>().having((e) => e.error, 'error', isA<OmfOfflineConnectionDioException>())),
        );
      });

      test('when the dio error is sendTimeout and device is offline, '
          'it should wrap the error with OfflineConnectionException', () async {
        buildDio(type: DioExceptionType.sendTimeout);

        await expectLater(
          dioWithInterceptor.get<void>('/jobs'),
          throwsA(isA<DioException>().having((e) => e.error, 'error', isA<OmfOfflineConnectionDioException>())),
        );
      });

      test('when the dio error is receiveTimeout and device is offline, '
          'it should wrap the error with OfflineConnectionException', () async {
        buildDio(type: DioExceptionType.receiveTimeout);

        await expectLater(
          dioWithInterceptor.get<void>('/jobs'),
          throwsA(isA<DioException>().having((e) => e.error, 'error', isA<OmfOfflineConnectionDioException>())),
        );
      });

      test('when the dio error is badResponse and device is offline, '
          'it should wrap the error with OfflineConnectionException', () async {
        buildDio(type: DioExceptionType.badResponse);

        await expectLater(
          dioWithInterceptor.get<void>('/jobs'),
          throwsA(isA<DioException>().having((e) => e.error, 'error', isA<OmfOfflineConnectionDioException>())),
        );
      });

      test('when the dio error is unknown and device is offline, '
          'it should wrap the error with OfflineConnectionException', () async {
        buildDio(type: DioExceptionType.unknown);

        await expectLater(
          dioWithInterceptor.get<void>('/jobs'),
          throwsA(isA<DioException>().having((e) => e.error, 'error', isA<OmfOfflineConnectionDioException>())),
        );
      });

      test('when the connectivity check itself throws, '
          'it should wrap the error with OfflineConnectionException', () async {
        buildDio(type: DioExceptionType.connectionError);
        when(() => mockConnection.hasInternetAccess).thenAnswer((_) => Future.error(Exception('check failed')));

        await expectLater(
          dioWithInterceptor.get<void>('/jobs'),
          throwsA(isA<DioException>().having((e) => e.error, 'error', isA<OmfOfflineConnectionDioException>())),
        );
      });

      test('when the connectivity check times out, '
          'it should wrap the error with OfflineConnectionException', () async {
        buildDio(type: DioExceptionType.connectionError);
        when(() => mockConnection.hasInternetAccess).thenAnswer((_) => Completer<bool>().future);

        await expectLater(
          dioWithInterceptor.get<void>('/jobs'),
          throwsA(isA<DioException>().having((e) => e.error, 'error', isA<OmfOfflineConnectionDioException>())),
        );
      });
    });

    group('when the device is online', () {
      setUp(() {
        when(() => mockConnection.hasInternetAccess).thenAnswer((_) async => true);
      });

      test('when the dio error is connectionError and device is online, '
          'it should preserve the original DioException', () async {
        buildDio(type: DioExceptionType.connectionError, message: 'Failed to connect');

        await expectLater(
          dioWithInterceptor.get<void>('/jobs'),
          throwsA(isA<DioException>().having((e) => e.type, 'type', DioExceptionType.connectionError)),
        );
      });

      test('when the dio error is badResponse and device is online, '
          'it should preserve the original DioException', () async {
        buildDio(type: DioExceptionType.badResponse, message: 'Bad response');

        await expectLater(
          dioWithInterceptor.get<void>('/jobs'),
          throwsA(isA<DioException>().having((e) => e.type, 'type', DioExceptionType.badResponse)),
        );
      });

      test('when the dio error is unknown and device is online, '
          'it should preserve the original DioException', () async {
        buildDio(type: DioExceptionType.unknown, message: 'Unknown error');

        await expectLater(
          dioWithInterceptor.get<void>('/jobs'),
          throwsA(isA<DioException>().having((e) => e.type, 'type', DioExceptionType.unknown)),
        );
      });
    });

    group('when the error type should skip the check', () {
      setUp(() {
        when(() => mockConnection.hasInternetAccess).thenAnswer((_) async => false);
      });

      test('when the dio error is badCertificate, '
          'it should preserve the original DioException unchanged', () async {
        buildDio(type: DioExceptionType.badCertificate, message: 'Bad cert');

        await expectLater(
          dioWithInterceptor.get<void>('/jobs'),
          throwsA(isA<DioException>().having((e) => e.type, 'type', DioExceptionType.badCertificate)),
        );
      });

      test('when the dio error is cancel, '
          'it should preserve the original DioException unchanged', () async {
        buildDio(type: DioExceptionType.cancel, message: 'Cancelled');

        await expectLater(
          dioWithInterceptor.get<void>('/jobs'),
          throwsA(isA<DioException>().having((e) => e.type, 'type', DioExceptionType.cancel)),
        );
      });
    });

    test('when the request fails offline, '
        'the DioException.error should carry the OfflineConnectionException '
        'with the original DioException as its cause', () async {
      when(() => mockConnection.hasInternetAccess).thenAnswer((_) async => false);

      final originalError = DioException(
        requestOptions: RequestOptions(path: '/jobs'),
        type: DioExceptionType.connectionError,
        message: 'Failed to connect',
      );

      final dio = Dio()
        ..httpClientAdapter = _ThrowingAdapter(originalError)
        ..interceptors.add(OmfOfflineErrorDioInterceptor.test(internetConnection: mockConnection));

      try {
        await dio.get<void>('/jobs');
        fail('expected exception to be thrown');
      } on DioException catch (e) {
        expect(e.error, isA<OmfOfflineConnectionDioException>().having((o) => o.cause, 'cause', same(originalError)));
      }
    });

    test('when dispose is called, it should dispose the InternetConnection', () async {
      final interceptor = OmfOfflineErrorDioInterceptor.test(internetConnection: mockConnection);

      await interceptor.dispose();

      verify(() => mockConnection.dispose()).called(1);
    });
  });
}
