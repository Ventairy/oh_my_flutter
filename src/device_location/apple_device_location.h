#ifndef OMF_APPLE_DEVICE_LOCATION_H_
#define OMF_APPLE_DEVICE_LOCATION_H_

#include <stdint.h>

#if defined(__APPLE__)
#define OMF_DEVICE_LOCATION_IOS_15 \
  __attribute__((availability(ios, introduced = 15.0)))
#else
#define OMF_DEVICE_LOCATION_IOS_15
#endif

#if defined(__cplusplus)
extern "C" {
#endif

typedef void (*OMFDeviceLocationValueCallback)(int32_t value, int32_t failure);

typedef void (*OMFDeviceLocationCoordinatesCallback)(double latitude,
                                                     double longitude,
                                                     double accuracy,
                                                     int32_t failure);

typedef int32_t OMFDeviceLocationFailure;

enum {
  OMFDeviceLocationFailureNone = 0,
  OMFDeviceLocationFailureServicesDisabled = 1,
  OMFDeviceLocationFailurePermissionDenied = 2,
  OMFDeviceLocationFailurePermissionPermanentlyDenied = 3,
  OMFDeviceLocationFailureConfigurationMissing = 4,
  OMFDeviceLocationFailureOperationUnavailable = 5,
  OMFDeviceLocationFailureCoordinatesUnavailable = 6,
};

void omf_device_location_is_service_enabled(
    OMFDeviceLocationValueCallback callback) OMF_DEVICE_LOCATION_IOS_15;

void omf_device_location_check_permission(
    OMFDeviceLocationValueCallback callback) OMF_DEVICE_LOCATION_IOS_15;

void omf_device_location_request_permission(
    OMFDeviceLocationValueCallback callback) OMF_DEVICE_LOCATION_IOS_15;

void omf_device_location_request_coordinates(
    OMFDeviceLocationCoordinatesCallback callback) OMF_DEVICE_LOCATION_IOS_15;

void omf_device_location_open_settings(
    OMFDeviceLocationValueCallback callback) OMF_DEVICE_LOCATION_IOS_15;

#if defined(__cplusplus)
}  // extern "C"
#endif

#undef OMF_DEVICE_LOCATION_IOS_15

#endif  // OMF_APPLE_DEVICE_LOCATION_H_
