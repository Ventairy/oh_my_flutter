/// Focused, strongly typed utilities for Flutter applications.
///
/// Import this library to use every public utility:
///
/// ```dart
/// import 'package:oh_my_flutter/oh_my_flutter.dart';
/// ```
library;

export 'src/dio_interceptors/offline_error_dio_interceptor.dart'
    show OfflineErrorDioInterceptor;
export 'src/exceptions/offline_connection_dio_exception.dart'
    show OfflineConnectionDioException;
export 'src/extensions/color_extension.dart' show ColorExtension;
export 'src/extensions/date_time_extension/date_time_extension.dart'
    show DateTimeExtension, TimeAgoFallback;
export 'src/extensions/object_extension.dart' show ObjectExtension;
export 'src/extensions/oklch_extension.dart' show OklchExtension;
export 'src/extensions/velocity_extension.dart' show VelocityExtension;
export 'src/oklch/oklch.dart' show Oklch;
export 'src/telephony.dart' show Telephony;
export 'src/whatsapp.dart' show Whatsapp;
