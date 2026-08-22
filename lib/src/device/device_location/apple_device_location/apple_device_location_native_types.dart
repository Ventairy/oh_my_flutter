part of 'apple_device_location_platform.dart';

typedef _AppleValueCallbackNative = Void Function(Int32 value, Int32 failure);

typedef _AppleValueResult = ({int value, int failure});

typedef _AppleCoordinatesCallbackNative = Void Function(
  Double latitude,
  Double longitude,
  Double accuracy,
  Int32 failure,
);

typedef _AppleCoordinatesResult = ({
  double latitude,
  double longitude,
  double accuracy,
  int failure,
});
