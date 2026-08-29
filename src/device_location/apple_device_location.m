#import "apple_device_location.h"

#import <Contacts/Contacts.h>
#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>
#import <math.h>
#import <stdlib.h>
#import <string.h>

// Core Location can immediately deliver a cached fix after updates start.
static const NSTimeInterval OMFDeviceLocationMaximumCoordinateAge = 5.0;
static const int64_t OMFDeviceLocationMaximumAddressTimeoutMilliseconds =
    120000;

typedef NS_ENUM(NSInteger, OMFDeviceLocationRequestMode) {
  OMFDeviceLocationRequestModePermission,
  OMFDeviceLocationRequestModeCoordinates,
  OMFDeviceLocationRequestModeAddress,
};

static NSString *OMFDeviceLocationNormalizedString(NSString *value) {
  if (![value isKindOfClass:NSString.class]) {
    return nil;
  }
  NSString *normalized =
      [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  return normalized.length == 0 ? nil : normalized;
}

static void OMFDeviceLocationAddAddressValue(
    NSMutableDictionary<NSString *, NSString *> *values,
    NSString *key,
    NSString *value) {
  NSString *normalized = OMFDeviceLocationNormalizedString(value);
  if (normalized != nil) {
    values[key] = normalized;
  }
}

static BOOL OMFDeviceLocationIsASCIICountryCode(NSString *value) {
  if (value.length != 2) {
    return NO;
  }
  for (NSUInteger index = 0; index < value.length; index += 1) {
    unichar character = [value characterAtIndex:index];
    BOOL isUppercase = character >= 'A' && character <= 'Z';
    BOOL isLowercase = character >= 'a' && character <= 'z';
    if (!isUppercase && !isLowercase) {
      return NO;
    }
  }
  return YES;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
static NSDictionary<NSString *, NSString *> *
OMFDeviceLocationAddressValues(CLPlacemark *placemark,
                               NSString *formattedAddress,
                               NSString *name) {
  NSMutableDictionary<NSString *, NSString *> *values =
      [NSMutableDictionary dictionary];
  NSString *resolvedFormattedAddress = formattedAddress;
  if (resolvedFormattedAddress == nil && placemark.postalAddress != nil) {
    resolvedFormattedAddress = [CNPostalAddressFormatter
        stringFromPostalAddress:placemark.postalAddress
                           style:CNPostalAddressFormatterStyleMailingAddress];
  }
  OMFDeviceLocationAddAddressValue(values, @"formattedAddress",
                                   resolvedFormattedAddress);
  OMFDeviceLocationAddAddressValue(values, @"name",
                                   name != nil ? name : placemark.name);
  OMFDeviceLocationAddAddressValue(values, @"street", placemark.thoroughfare);
  OMFDeviceLocationAddAddressValue(values, @"streetNumber",
                                   placemark.subThoroughfare);
  OMFDeviceLocationAddAddressValue(values, @"neighborhood",
                                   placemark.subLocality);
  OMFDeviceLocationAddAddressValue(values, @"district",
                                   placemark.subAdministrativeArea);
  OMFDeviceLocationAddAddressValue(values, @"city", placemark.locality);
  OMFDeviceLocationAddAddressValue(values, @"state",
                                   placemark.administrativeArea);
  OMFDeviceLocationAddAddressValue(values, @"postalCode",
                                   placemark.postalCode);
  OMFDeviceLocationAddAddressValue(values, @"country", placemark.country);
  NSString *countryCode =
      OMFDeviceLocationNormalizedString(placemark.ISOcountryCode);
  if (OMFDeviceLocationIsASCIICountryCode(countryCode)) {
    values[@"countryCode"] = countryCode.uppercaseString;
  }
  return values;
}
#pragma clang diagnostic pop

@interface OMFDeviceLocationRequest : NSObject <CLLocationManagerDelegate>

@property(nonatomic, strong) CLLocationManager *manager;
@property(nonatomic, assign) OMFDeviceLocationRequestMode mode;
@property(nonatomic, assign) OMFDeviceLocationValueCallback valueCallback;
@property(nonatomic, assign)
    OMFDeviceLocationCoordinatesCallback coordinatesCallback;
@property(nonatomic, assign) OMFDeviceLocationAddressCallback addressCallback;
@property(nonatomic, assign) BOOL coordinatesStarted;
@property(nonatomic, strong) CLLocation *addressLocation;
@property(nonatomic, strong) NSLocale *preferredLocale;
@property(nonatomic, assign) int64_t addressTimeoutMilliseconds;
@property(nonatomic, strong) id reverseGeocodingRequest;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@property(nonatomic, strong) CLGeocoder *geocoder;
#pragma clang diagnostic pop

+ (BOOL)hasUsageDescription;
+ (BOOL)isApplicationInForeground;
+ (int32_t)permissionValueForStatus:(CLAuthorizationStatus)status;
+ (void)retainRequest:(OMFDeviceLocationRequest *)request;

- (void)beginPermissionRequest;
- (void)beginCoordinatesRequest;
- (void)beginAddressRequest;
- (void)observeApplicationLifecycle;

@end

static NSMutableSet<OMFDeviceLocationRequest *> *OMFDeviceLocationRequests;

@implementation OMFDeviceLocationRequest

+ (void)initialize {
  if (self == OMFDeviceLocationRequest.class) {
    OMFDeviceLocationRequests = [NSMutableSet set];
  }
}

+ (BOOL)hasUsageDescription {
  id value = [NSBundle.mainBundle
      objectForInfoDictionaryKey:@"NSLocationWhenInUseUsageDescription"];
  return [value isKindOfClass:NSString.class] &&
         ((NSString *)value).length > 0;
}

+ (BOOL)isApplicationInForeground {
  return UIApplication.sharedApplication.applicationState !=
         UIApplicationStateBackground;
}

+ (int32_t)permissionValueForStatus:(CLAuthorizationStatus)status {
  switch (status) {
    case kCLAuthorizationStatusNotDetermined:
      return 0;
    case kCLAuthorizationStatusDenied:
      return 1;
    case kCLAuthorizationStatusRestricted:
      return 2;
    case kCLAuthorizationStatusAuthorizedWhenInUse:
      return 3;
    case kCLAuthorizationStatusAuthorizedAlways:
      return 4;
    default:
      return -1;
  }
}

+ (void)retainRequest:(OMFDeviceLocationRequest *)request {
  [OMFDeviceLocationRequests addObject:request];
}

- (void)finishValue:(int32_t)value failure:(OMFDeviceLocationFailure)failure {
  OMFDeviceLocationValueCallback callback = self.valueCallback;
  self.valueCallback = NULL;
  [NSNotificationCenter.defaultCenter removeObserver:self];
  [self.manager stopUpdatingLocation];
  self.manager.delegate = nil;
  self.manager = nil;
  [OMFDeviceLocationRequests removeObject:self];
  if (callback != NULL) {
    callback(value, failure);
  }
}

- (void)finishCoordinatesWithLatitude:(double)latitude
                            longitude:(double)longitude
                             accuracy:(double)accuracy
                              failure:(OMFDeviceLocationFailure)failure {
  OMFDeviceLocationCoordinatesCallback callback = self.coordinatesCallback;
  self.coordinatesCallback = NULL;
  [NSNotificationCenter.defaultCenter removeObserver:self];
  [self.manager stopUpdatingLocation];
  self.manager.delegate = nil;
  self.manager = nil;
  [OMFDeviceLocationRequests removeObject:self];
  if (callback != NULL) {
    callback(latitude, longitude, accuracy, failure);
  }
}

- (void)finishAddressWithValues:
            (NSDictionary<NSString *, NSString *> *)values
                         failure:(OMFDeviceLocationFailure)failure {
  OMFDeviceLocationAddressCallback callback = self.addressCallback;
  self.addressCallback = NULL;
  [NSNotificationCenter.defaultCenter removeObserver:self];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  [self.geocoder cancelGeocode];
#pragma clang diagnostic pop
  self.geocoder = nil;
  if (@available(iOS 26.0, *)) {
    [(MKReverseGeocodingRequest *)self.reverseGeocodingRequest cancel];
  }
  self.reverseGeocodingRequest = nil;
  self.addressLocation = nil;
  self.preferredLocale = nil;
  [OMFDeviceLocationRequests removeObject:self];

  char *addressJSON = NULL;
  if (failure == OMFDeviceLocationFailureNone && values.count > 0) {
    NSError *serializationError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:values
                                                   options:0
                                                     error:&serializationError];
    if (data == nil || serializationError != nil) {
      failure = OMFDeviceLocationFailureOperationUnavailable;
    } else {
      addressJSON = malloc(data.length + 1);
      if (addressJSON == NULL) {
        failure = OMFDeviceLocationFailureOperationUnavailable;
      } else {
        memcpy(addressJSON, data.bytes, data.length);
        addressJSON[data.length] = '\0';
      }
    }
  } else if (failure == OMFDeviceLocationFailureNone) {
    failure = OMFDeviceLocationFailureOperationUnavailable;
  }
  if (callback != NULL) {
    callback(addressJSON, failure);
  } else {
    free(addressJSON);
  }
}

- (void)beginPermissionRequest {
  [self observeApplicationLifecycle];
  [self.manager requestWhenInUseAuthorization];
}

- (void)beginCoordinatesRequest {
  if (self.coordinatesStarted) {
    return;
  }
  self.coordinatesStarted = YES;
  [self observeApplicationLifecycle];
  [self.manager startUpdatingLocation];
}

- (void)beginAddressRequest {
  [self observeApplicationLifecycle];
  __weak OMFDeviceLocationRequest *weakSelf = self;
  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW,
                    self.addressTimeoutMilliseconds * NSEC_PER_MSEC),
      dispatch_get_main_queue(), ^{
        OMFDeviceLocationRequest *request = weakSelf;
        if (request == nil || request.addressCallback == NULL) {
          return;
        }
        [request finishAddressWithValues:nil
                                 failure:OMFDeviceLocationFailureOperationUnavailable];
      });
  if (@available(iOS 26.0, *)) {
    MKReverseGeocodingRequest *request =
        [[MKReverseGeocodingRequest alloc] initWithLocation:self.addressLocation];
    if (request == nil) {
      [self finishAddressWithValues:nil
                            failure:OMFDeviceLocationFailureOperationUnavailable];
      return;
    }
    request.preferredLocale = self.preferredLocale;
    self.reverseGeocodingRequest = request;
    [request getMapItemsWithCompletionHandler:^(NSArray<MKMapItem *> *mapItems,
                                                NSError *error) {
      dispatch_async(dispatch_get_main_queue(), ^{
        if (self.addressCallback == NULL) {
          return;
        }
        MKMapItem *item = mapItems.firstObject;
        if (item == nil || error != nil) {
          [self finishAddressWithValues:nil
                                failure:OMFDeviceLocationFailureOperationUnavailable];
          return;
        }
        NSString *formattedAddress = [item.addressRepresentations
            fullAddressIncludingRegion:YES
                             singleLine:NO];
        if (formattedAddress == nil) {
          formattedAddress = item.address.fullAddress;
        }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        CLPlacemark *placemark = item.placemark;
#pragma clang diagnostic pop
        NSDictionary<NSString *, NSString *> *values =
            OMFDeviceLocationAddressValues(placemark, formattedAddress,
                                           item.name);
        [self finishAddressWithValues:values
                              failure:OMFDeviceLocationFailureNone];
      });
    }];
    return;
  }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  CLGeocoder *geocoder = [CLGeocoder new];
  self.geocoder = geocoder;
  [geocoder reverseGeocodeLocation:self.addressLocation
                   preferredLocale:self.preferredLocale
                 completionHandler:^(NSArray<CLPlacemark *> *placemarks,
                                     NSError *error) {
    dispatch_async(dispatch_get_main_queue(), ^{
      if (self.addressCallback == NULL) {
        return;
      }
      CLPlacemark *placemark = placemarks.firstObject;
      if (placemark == nil || error != nil) {
        [self finishAddressWithValues:nil
                              failure:OMFDeviceLocationFailureOperationUnavailable];
        return;
      }
      NSDictionary<NSString *, NSString *> *values =
          OMFDeviceLocationAddressValues(placemark, nil, placemark.name);
      [self finishAddressWithValues:values
                            failure:OMFDeviceLocationFailureNone];
    });
  }];
#pragma clang diagnostic pop
}

- (void)observeApplicationLifecycle {
  [NSNotificationCenter.defaultCenter
      addObserver:self
         selector:@selector(applicationDidEnterBackground:)
             name:UIApplicationDidEnterBackgroundNotification
           object:nil];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
  if (self.mode == OMFDeviceLocationRequestModePermission) {
    [self finishValue:0 failure:OMFDeviceLocationFailureOperationUnavailable];
    return;
  }
  if (self.mode == OMFDeviceLocationRequestModeAddress) {
    [self finishAddressWithValues:nil
                          failure:OMFDeviceLocationFailureOperationUnavailable];
    return;
  }
  [self finishCoordinatesWithLatitude:0
                            longitude:0
                             accuracy:0
                              failure:OMFDeviceLocationFailureCoordinatesUnavailable];
}

- (void)completeAuthorization:(CLAuthorizationStatus)status {
  if (status == kCLAuthorizationStatusNotDetermined) {
    return;
  }

  if (self.mode == OMFDeviceLocationRequestModePermission) {
    [self finishValue:[OMFDeviceLocationRequest
                          permissionValueForStatus:status]
              failure:OMFDeviceLocationFailureNone];
    return;
  }

  switch (status) {
    case kCLAuthorizationStatusAuthorizedAlways:
    case kCLAuthorizationStatusAuthorizedWhenInUse:
      [self beginCoordinatesRequest];
      return;
    case kCLAuthorizationStatusDenied:
      [self finishCoordinatesWithLatitude:0
                                longitude:0
                                 accuracy:0
                                  failure:OMFDeviceLocationFailurePermissionPermanentlyDenied];
      return;
    case kCLAuthorizationStatusRestricted:
      [self finishCoordinatesWithLatitude:0
                                longitude:0
                                 accuracy:0
                                  failure:OMFDeviceLocationFailurePermissionPermanentlyDenied];
      return;
    case kCLAuthorizationStatusNotDetermined:
      return;
    default:
      [self finishCoordinatesWithLatitude:0
                                longitude:0
                                 accuracy:0
                                  failure:OMFDeviceLocationFailureCoordinatesUnavailable];
      return;
  }
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
  [self completeAuthorization:manager.authorizationStatus];
}

- (void)locationManager:(CLLocationManager *)manager
      didUpdateLocations:(NSArray<CLLocation *> *)locations {
  CLLocation *location = locations.lastObject;
  if (location == nil) {
    return;
  }
  NSTimeInterval age = -[location.timestamp timeIntervalSinceNow];
  if (age > OMFDeviceLocationMaximumCoordinateAge) {
    return;
  }
  if (!CLLocationCoordinate2DIsValid(location.coordinate) ||
      !isfinite(location.horizontalAccuracy) ||
      location.horizontalAccuracy < 0) {
    [self finishCoordinatesWithLatitude:0
                              longitude:0
                               accuracy:0
                                failure:OMFDeviceLocationFailureCoordinatesUnavailable];
    return;
  }
  [self finishCoordinatesWithLatitude:location.coordinate.latitude
                            longitude:location.coordinate.longitude
                             accuracy:location.horizontalAccuracy
                              failure:OMFDeviceLocationFailureNone];
}

- (void)locationManager:(CLLocationManager *)manager
        didFailWithError:(NSError *)error {
  if ([error.domain isEqualToString:kCLErrorDomain] &&
      error.code == kCLErrorLocationUnknown) {
    return;
  }
  CLAuthorizationStatus status = manager.authorizationStatus;
  if (status == kCLAuthorizationStatusRestricted) {
    [self finishCoordinatesWithLatitude:0
                              longitude:0
                               accuracy:0
                                failure:OMFDeviceLocationFailurePermissionPermanentlyDenied];
    return;
  }
  if ([error.domain isEqualToString:kCLErrorDomain] &&
      error.code == kCLErrorDenied) {
    dispatch_async(
        dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
          BOOL servicesEnabled = CLLocationManager.locationServicesEnabled;
          dispatch_async(dispatch_get_main_queue(), ^{
            if (self.coordinatesCallback == NULL) {
              return;
            }
            OMFDeviceLocationFailure failure =
                OMFDeviceLocationFailureCoordinatesUnavailable;
            if (!servicesEnabled) {
              failure = OMFDeviceLocationFailureServicesDisabled;
            } else if (status == kCLAuthorizationStatusDenied) {
              failure = OMFDeviceLocationFailurePermissionPermanentlyDenied;
            }
            [self finishCoordinatesWithLatitude:0
                                      longitude:0
                                       accuracy:0
                                        failure:failure];
          });
        });
    return;
  }
  [self finishCoordinatesWithLatitude:0
                            longitude:0
                             accuracy:0
                              failure:OMFDeviceLocationFailureCoordinatesUnavailable];
}

@end

__attribute__((visibility("default")))
void omf_device_location_is_service_enabled(
    OMFDeviceLocationValueCallback callback) {
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    BOOL servicesEnabled = CLLocationManager.locationServicesEnabled;
    dispatch_async(dispatch_get_main_queue(), ^{
      callback(servicesEnabled ? 1 : 0, OMFDeviceLocationFailureNone);
    });
  });
}

__attribute__((visibility("default")))
void omf_device_location_check_permission(
    OMFDeviceLocationValueCallback callback) {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (![OMFDeviceLocationRequest hasUsageDescription]) {
      callback(0, OMFDeviceLocationFailureConfigurationMissing);
      return;
    }
    CLLocationManager *manager = [CLLocationManager new];
    CLAuthorizationStatus status = manager.authorizationStatus;
    callback([OMFDeviceLocationRequest permissionValueForStatus:status],
             OMFDeviceLocationFailureNone);
  });
}

__attribute__((visibility("default")))
void omf_device_location_request_permission(
    OMFDeviceLocationValueCallback callback) {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (![OMFDeviceLocationRequest hasUsageDescription]) {
      callback(0, OMFDeviceLocationFailureConfigurationMissing);
      return;
    }

    CLLocationManager *manager = [CLLocationManager new];
    CLAuthorizationStatus status = manager.authorizationStatus;
    if (status != kCLAuthorizationStatusNotDetermined) {
      callback([OMFDeviceLocationRequest permissionValueForStatus:status],
               OMFDeviceLocationFailureNone);
      return;
    }
    if (![OMFDeviceLocationRequest isApplicationInForeground]) {
      callback(0, OMFDeviceLocationFailureOperationUnavailable);
      return;
    }

    OMFDeviceLocationRequest *request = [OMFDeviceLocationRequest new];
    request.mode = OMFDeviceLocationRequestModePermission;
    request.valueCallback = callback;
    request.manager = manager;
    manager.delegate = request;
    [OMFDeviceLocationRequest retainRequest:request];
    [request beginPermissionRequest];
  });
}

__attribute__((visibility("default")))
void omf_device_location_request_coordinates(
    OMFDeviceLocationCoordinatesCallback callback) {
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    BOOL servicesEnabled = CLLocationManager.locationServicesEnabled;
    dispatch_async(dispatch_get_main_queue(), ^{
      if (![OMFDeviceLocationRequest hasUsageDescription]) {
        callback(0, 0, 0, OMFDeviceLocationFailureConfigurationMissing);
        return;
      }
      if (!servicesEnabled) {
        callback(0, 0, 0, OMFDeviceLocationFailureServicesDisabled);
        return;
      }
      if (![OMFDeviceLocationRequest isApplicationInForeground]) {
        callback(0, 0, 0, OMFDeviceLocationFailureCoordinatesUnavailable);
        return;
      }

      CLLocationManager *manager = [CLLocationManager new];
      CLAuthorizationStatus status = manager.authorizationStatus;
      switch (status) {
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
          break;
        case kCLAuthorizationStatusDenied:
          callback(0, 0, 0,
                   OMFDeviceLocationFailurePermissionPermanentlyDenied);
          return;
        case kCLAuthorizationStatusRestricted:
          callback(0, 0, 0,
                   OMFDeviceLocationFailurePermissionPermanentlyDenied);
          return;
        case kCLAuthorizationStatusNotDetermined:
          callback(0, 0, 0, OMFDeviceLocationFailurePermissionDenied);
          return;
        default:
          callback(0, 0, 0, OMFDeviceLocationFailureCoordinatesUnavailable);
          return;
      }

      OMFDeviceLocationRequest *request = [OMFDeviceLocationRequest new];
      request.mode = OMFDeviceLocationRequestModeCoordinates;
      request.coordinatesCallback = callback;
      request.manager = manager;
      manager.delegate = request;
      manager.desiredAccuracy = kCLLocationAccuracyBest;
      manager.distanceFilter = kCLDistanceFilterNone;
      [OMFDeviceLocationRequest retainRequest:request];
      [request beginCoordinatesRequest];
    });
  });
}

__attribute__((visibility("default")))
void omf_device_location_request_address(
    double latitude,
    double longitude,
    const char *locale_identifier,
    int64_t timeout_milliseconds,
    OMFDeviceLocationAddressCallback callback) {
  NSString *localeIdentifier = locale_identifier == NULL
                                   ? nil
                                   : [NSString stringWithUTF8String:locale_identifier];
  NSLocale *preferredLocale = localeIdentifier.length == 0
                                  ? nil
                                  : [[NSLocale alloc]
                                        initWithLocaleIdentifier:localeIdentifier];
  dispatch_async(dispatch_get_main_queue(), ^{
    CLLocationCoordinate2D coordinate =
        CLLocationCoordinate2DMake(latitude, longitude);
    if (!CLLocationCoordinate2DIsValid(coordinate) ||
        timeout_milliseconds <= 0 ||
        timeout_milliseconds >
            OMFDeviceLocationMaximumAddressTimeoutMilliseconds ||
        ![OMFDeviceLocationRequest isApplicationInForeground]) {
      callback(NULL, OMFDeviceLocationFailureOperationUnavailable);
      return;
    }

    OMFDeviceLocationRequest *request = [OMFDeviceLocationRequest new];
    request.mode = OMFDeviceLocationRequestModeAddress;
    request.addressCallback = callback;
    request.addressLocation =
        [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
    request.preferredLocale = preferredLocale;
    request.addressTimeoutMilliseconds = timeout_milliseconds;
    [OMFDeviceLocationRequest retainRequest:request];
    [request beginAddressRequest];
  });
}

__attribute__((visibility("default")))
void *omf_device_location_allocate(intptr_t size) {
  if (size <= 0) {
    return NULL;
  }
  return malloc((size_t)size);
}

__attribute__((visibility("default")))
void omf_device_location_free(void *value) {
  free(value);
}

__attribute__((visibility("default")))
void omf_device_location_open_settings(
    OMFDeviceLocationValueCallback callback) {
  dispatch_async(dispatch_get_main_queue(), ^{
    NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if (url == nil) {
      callback(0, OMFDeviceLocationFailureOperationUnavailable);
      return;
    }
    [UIApplication.sharedApplication openURL:url
                                     options:@{}
                           completionHandler:^(BOOL success) {
                             callback(success ? 1 : 0,
                                      OMFDeviceLocationFailureNone);
                           }];
  });
}
