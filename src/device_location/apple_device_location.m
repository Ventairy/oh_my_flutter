#import "apple_device_location.h"

#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <math.h>

// Core Location can immediately deliver a cached fix after updates start.
static const NSTimeInterval OMFDeviceLocationMaximumCoordinateAge = 5.0;

typedef NS_ENUM(NSInteger, OMFDeviceLocationRequestMode) {
  OMFDeviceLocationRequestModePermission,
  OMFDeviceLocationRequestModeCoordinates,
};

@interface OMFDeviceLocationRequest : NSObject <CLLocationManagerDelegate>

@property(nonatomic, strong) CLLocationManager *manager;
@property(nonatomic, assign) OMFDeviceLocationRequestMode mode;
@property(nonatomic, assign) OMFDeviceLocationValueCallback valueCallback;
@property(nonatomic, assign)
    OMFDeviceLocationCoordinatesCallback coordinatesCallback;
@property(nonatomic, assign) BOOL coordinatesStarted;

+ (BOOL)hasUsageDescription;
+ (BOOL)isApplicationInForeground;
+ (int32_t)permissionValueForStatus:(CLAuthorizationStatus)status;
+ (void)retainRequest:(OMFDeviceLocationRequest *)request;

- (void)beginPermissionRequest;
- (void)beginCoordinatesRequest;
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
