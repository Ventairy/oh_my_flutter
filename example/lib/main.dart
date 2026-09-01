import 'package:flutter/material.dart';

import 'package:oh_my_flutter_example/examples/controlled_visibility_example.dart';
import 'package:oh_my_flutter_example/examples/device_display_example.dart';
import 'package:oh_my_flutter_example/examples/device_location_example.dart';
import 'package:oh_my_flutter_example/examples/interactive_swipe_dismiss_example.dart';
import 'package:oh_my_flutter_example/examples/marquee_example.dart';
import 'package:oh_my_flutter_example/examples/maybe_safe_area_example.dart';
import 'package:oh_my_flutter_example/examples/morph_example.dart';
import 'package:oh_my_flutter_example/examples/motion_example.dart';
import 'package:oh_my_flutter_example/examples/relative_time_example.dart';
import 'package:oh_my_flutter_example/examples/route_settled_example.dart';
import 'package:oh_my_flutter_example/examples/sequence_example.dart';
import 'package:oh_my_flutter_example/examples/skeleton_example.dart';
import 'package:oh_my_flutter_example/examples/text_motion_example.dart';

void main() => runApp(const UtilityExample());

/// A small gallery for the public utility APIs.
class UtilityExample extends StatelessWidget {
  /// Creates the utility example.
  const UtilityExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Device display', style: _sectionStyle),
                        SizedBox(height: 12),
                        DeviceDisplayExample(),
                        SizedBox(height: 32),
                        Text('Device location', style: _sectionStyle),
                        SizedBox(height: 12),
                        DeviceLocationExample(),
                        SizedBox(height: 32),
                        Text('Relative time', style: _sectionStyle),
                        SizedBox(height: 12),
                        RelativeTimeExample(),
                        SizedBox(height: 32),
                        Text('Motion', style: _sectionStyle),
                        SizedBox(height: 12),
                        MotionExample(),
                        SizedBox(height: 32),
                        Text('TextMotion', style: _sectionStyle),
                        SizedBox(height: 12),
                        TextMotionExample(),
                        SizedBox(height: 32),
                        Text('Marquee', style: _sectionStyle),
                        SizedBox(height: 12),
                        MarqueeExample(),
                        SizedBox(height: 32),
                        Text('Skeleton', style: _sectionStyle),
                        SizedBox(height: 12),
                        SkeletonExample(),
                        SizedBox(height: 32),
                        Text('ControlledVisibility', style: _sectionStyle),
                        SizedBox(height: 12),
                        ControlledVisibilityExample(),
                        SizedBox(height: 32),
                        Text('InteractiveSwipeDismiss', style: _sectionStyle),
                        SizedBox(height: 12),
                        InteractiveSwipeDismissExample(),
                        SizedBox(height: 32),
                        Text('Morph', style: _sectionStyle),
                        SizedBox(height: 12),
                        MorphExample(),
                        SizedBox(height: 32),
                        Text('Sequence', style: _sectionStyle),
                        SizedBox(height: 12),
                        SequenceExample(),
                        SizedBox(height: 32),
                        Text('RouteSettled', style: _sectionStyle),
                        SizedBox(height: 12),
                        RouteSettledExample(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              top: 0,
              right: 24,
              child: MaybeSafeAreaExample(),
            ),
          ],
        ),
      ),
    );
  }

  static const _sectionStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );
}
