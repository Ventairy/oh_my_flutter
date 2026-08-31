#import "corner_radius_collector_app_delegate.h"

@implementation CornerRadiusCollectorAppDelegate

- (BOOL)application:(UIApplication*)application
    didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
  self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
  self.window.rootViewController = [[UIViewController alloc] init];
  self.window.backgroundColor = UIColor.clearColor;
  [self.window makeKeyAndVisible];

  UIView* probe = [[UIView alloc] initWithFrame:self.window.bounds];
  probe.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  probe.backgroundColor = UIColor.clearColor;
  probe.opaque = NO;
  probe.userInteractionEnabled = NO;
  if (@available(iOS 26.0, *)) {
    probe.cornerConfiguration =
        [UICornerConfiguration configurationWithRadius:[UICornerRadius containerConcentricRadius]];
  }
  [self.window insertSubview:probe atIndex:0];

  dispatch_async(dispatch_get_main_queue(), ^{
    [self.window layoutIfNeeded];
    UIScreen* screen = self.window.screen;
    CGFloat scale = screen.scale;
    CGSize size = screen.bounds.size;
    UIEdgeInsets safeArea = self.window.safeAreaInsets;
    CGFloat topRadius = -1.0;
    CGFloat bottomRadius = -1.0;
    NSString* sourceKind = nil;
    if (@available(iOS 26.0, *)) {
      topRadius = ([probe effectiveRadiusForCorner:UIRectCornerTopLeft] +
                   [probe effectiveRadiusForCorner:UIRectCornerTopRight]) /
                  2.0;
      bottomRadius = ([probe effectiveRadiusForCorner:UIRectCornerBottomLeft] +
                      [probe effectiveRadiusForCorner:UIRectCornerBottomRight]) /
                     2.0;
      sourceKind = @"ios26_public_uikit_concentric_corner";
    } else {
      CGFloat legacyRadius = [self legacyDisplayCornerRadiusForScreen:screen];
      topRadius = legacyRadius;
      bottomRadius = legacyRadius;
      sourceKind = @"ios_legacy_private_display_corner_selector";
    }
    if (topRadius < 0 || bottomRadius < 0) {
      return;
    }

    NSDictionary* record = @{
      @"platform" : @"ios",
      @"sourceKind" : sourceKind,
      @"physicalWidth" : @(size.width * scale),
      @"physicalHeight" : @(size.height * scale),
      @"viewPhysicalWidth" : @(self.window.bounds.size.width * scale),
      @"viewPhysicalHeight" : @(self.window.bounds.size.height * scale),
      @"devicePixelRatio" : @(scale),
      @"viewPaddingLeftPhysical" : @(safeArea.left * scale),
      @"viewPaddingTopPhysical" : @(safeArea.top * scale),
      @"viewPaddingRightPhysical" : @(safeArea.right * scale),
      @"viewPaddingBottomPhysical" : @(safeArea.bottom * scale),
      @"topRadiusPhysical" : @(topRadius * scale),
      @"bottomRadiusPhysical" : @(bottomRadius * scale),
    };
    NSData* data = [NSJSONSerialization dataWithJSONObject:record options:NSJSONWritingSortedKeys error:nil];
    NSURL* documents = [[NSFileManager defaultManager]
        URLForDirectory:NSDocumentDirectory
               inDomain:NSUserDomainMask
      appropriateForURL:nil
                 create:YES
                  error:nil];
    [data writeToURL:[documents URLByAppendingPathComponent:@"record.json"] atomically:YES];
  });
  return YES;
}

- (CGFloat)legacyDisplayCornerRadiusForScreen:(UIScreen*)screen {
  SEL selector = NSSelectorFromString(@"_displayCornerRadius");
  if (![screen respondsToSelector:selector]) {
    return -1.0;
  }
  NSMethodSignature* signature = [screen methodSignatureForSelector:selector];
  if (signature == nil || signature.methodReturnLength != sizeof(CGFloat)) {
    return -1.0;
  }
  NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:signature];
  invocation.selector = selector;
  invocation.target = screen;
  [invocation invoke];
  CGFloat radius = -1.0;
  [invocation getReturnValue:&radius];
  return radius;
}

@end
