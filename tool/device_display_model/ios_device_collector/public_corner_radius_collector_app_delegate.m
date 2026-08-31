#import "public_corner_radius_collector_app_delegate.h"
#import "collector_source_hash.h"

@implementation PublicCornerRadiusCollectorAppDelegate

- (BOOL)application:(UIApplication*)application
    didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
  if (@available(iOS 26.0, *)) {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    self.window.backgroundColor = UIColor.clearColor;
    [self.window makeKeyAndVisible];

    UIView* probe = [[UIView alloc] initWithFrame:self.window.bounds];
    probe.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    probe.backgroundColor = UIColor.clearColor;
    probe.opaque = NO;
    probe.userInteractionEnabled = NO;
    probe.cornerConfiguration = [UICornerConfiguration
        configurationWithRadius:[UICornerRadius containerConcentricRadius]];
    [self.window insertSubview:probe atIndex:0];

    dispatch_async(dispatch_get_main_queue(), ^{
      [self.window layoutIfNeeded];
      NSString* nonce = NSProcessInfo.processInfo.environment[
          @"OMF_DEVICE_DISPLAY_COLLECTOR_NONCE"];
      if (nonce.length == 0) {
        return;
      }
      UIScreen* screen = self.window.screen;
      CGFloat scale = screen.scale;
      CGSize displaySize = screen.bounds.size;
      CGSize viewSize = self.window.bounds.size;
      UIEdgeInsets safeArea = self.window.safeAreaInsets;
      NSDictionary* record = @{
        @"protocolVersion" : @1,
        @"protocolSourceHash" : OMF_DEVICE_DISPLAY_COLLECTOR_SOURCE_HASH,
        @"platform" : @"ios",
        @"sourceKind" : @"ios26_connected_public_uikit_concentric_corner",
        @"nonce" : nonce,
        @"physicalWidth" : @(displaySize.width * scale),
        @"physicalHeight" : @(displaySize.height * scale),
        @"viewPhysicalWidth" : @(viewSize.width * scale),
        @"viewPhysicalHeight" : @(viewSize.height * scale),
        @"devicePixelRatio" : @(scale),
        @"viewPaddingLeftPhysical" : @(safeArea.left * scale),
        @"viewPaddingTopPhysical" : @(safeArea.top * scale),
        @"viewPaddingRightPhysical" : @(safeArea.right * scale),
        @"viewPaddingBottomPhysical" : @(safeArea.bottom * scale),
        @"topLeftRadiusPhysical" :
            @([probe effectiveRadiusForCorner:UIRectCornerTopLeft] * scale),
        @"topRightRadiusPhysical" :
            @([probe effectiveRadiusForCorner:UIRectCornerTopRight] * scale),
        @"bottomRightRadiusPhysical" :
            @([probe effectiveRadiusForCorner:UIRectCornerBottomRight] * scale),
        @"bottomLeftRadiusPhysical" :
            @([probe effectiveRadiusForCorner:UIRectCornerBottomLeft] * scale),
      };
      NSData* data = [NSJSONSerialization
          dataWithJSONObject:record
                     options:NSJSONWritingSortedKeys
                       error:nil];
      NSURL* documents = [[NSFileManager defaultManager]
          URLForDirectory:NSDocumentDirectory
                 inDomain:NSUserDomainMask
        appropriateForURL:nil
                   create:YES
                    error:nil];
      [data writeToURL:[documents URLByAppendingPathComponent:@"record.json"]
              atomically:YES];
    });
  }
  return YES;
}

@end
