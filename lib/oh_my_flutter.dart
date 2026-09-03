/// Focused, strongly typed utilities for Flutter applications.
///
/// Import this library to use every public utility:
///
/// ```dart
/// import 'package:oh_my_flutter/oh_my_flutter.dart';
/// ```
library;

export 'src/debouncer.dart' show Debouncer;
export 'src/device/device.dart' show Device;
export 'src/device/device_display/device_display.dart' show DeviceDisplay;
export 'src/device/device_location/device_location.dart' show DeviceLocation;
export 'src/device/device_location/device_location_address.dart' show DeviceLocationAddress;
export 'src/device/device_location/device_location_coordinates.dart' show DeviceLocationCoordinates;
export 'src/device/device_location/device_location_permission_status.dart' show DeviceLocationPermissionStatus;
export 'src/dio_interceptors/offline_error_dio_interceptor.dart' show OfflineErrorDioInterceptor;
export 'src/exceptions/debouncer_canceled_exception.dart' show DebouncerCanceledException;
export 'src/exceptions/device_location_exception.dart' show DeviceLocationException;
export 'src/exceptions/device_location_exception_reason.dart' show DeviceLocationExceptionReason;
export 'src/exceptions/offline_connection_dio_exception.dart' show OfflineConnectionDioException;
export 'src/extensions/color_extension.dart' show ColorExtension;
export 'src/extensions/date_time_extension/date_time_extension.dart' show DateTimeExtension, TimeAgoFallback;
export 'src/extensions/object_extension.dart' show ObjectExtension;
export 'src/extensions/oklch_extension.dart' show OklchExtension;
export 'src/extensions/velocity_extension.dart' show VelocityExtension;
export 'src/oklch/oklch.dart' show Oklch;
export 'src/telephony.dart' show Telephony;
export 'src/whatsapp.dart' show Whatsapp;
export 'src/widgets/controlled_visibility/controlled_visibility.dart' show ControlledVisibility, VisibilityController;
export 'src/widgets/interactive_swipe_dismiss/interactive_swipe_dismiss.dart'
    show
        InteractiveSwipeDismiss,
        InteractiveSwipeDismissDirection,
        InteractiveSwipeDismissDragConfig,
        InteractiveSwipeDismissHandle;
export 'src/widgets/marquee/marquee.dart' show Marquee;
export 'src/widgets/marquee/marquee_direction.dart' show MarqueeDirection;
export 'src/widgets/maybe_safe_area/maybe_safe_area.dart' show MaybeSafeArea, MaybeSafeAreaBehavior;
export 'src/widgets/morph/morph.dart'
    show Morph, MorphDescendant, MorphEndpoint, MorphEndpointContext, MorphFlight, MorphFlightDelegate, MorphSibling;
export 'src/widgets/morph/morph_descendant_flight_behavior.dart' show MorphDescendantFlightBehavior;
export 'src/widgets/morph/morph_flight_kind.dart' show MorphFlightKind;
export 'src/widgets/motion/motion.dart'
    show
        FadeInMotionEffect,
        FloatingMotionEffect,
        Motion,
        MotionController,
        MotionEffect,
        MotionEffectBounds,
        MotionEffectTransform,
        MotionPlayback,
        MotionStartup,
        MoveMotionEffect,
        ScaleInMotionEffect,
        ScaleOutMotionEffect,
        ShakeMotionEffect,
        TextMotion;
export 'src/widgets/pause_animations/pause_animations.dart' show PauseAnimations;
export 'src/widgets/route_settled/route_settled.dart' show RouteSettled;
export 'src/widgets/sequence/sequence.dart' show Sequence, SequenceController, SequenceTransitionBuilder;
export 'src/widgets/skeleton/skeleton.dart'
    show
        Skeleton,
        SkeletonAnimatedEffectBase,
        SkeletonDescendant,
        SkeletonDescendantBehavior,
        SkeletonEffect,
        SkeletonFadeEffect,
        SkeletonShimmerEffect,
        SkeletonStaticEffectBase,
        SkeletonStyle;
