import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter_example/examples/controlled_visibility_example.dart';
import 'package:oh_my_flutter_example/examples/device_display_example.dart';
import 'package:oh_my_flutter_example/examples/device_location_example.dart';
import 'package:oh_my_flutter_example/examples/group_example.dart';
import 'package:oh_my_flutter_example/examples/group_morph_example.dart';
import 'package:oh_my_flutter_example/examples/interactive_swipe_dismiss_example.dart';
import 'package:oh_my_flutter_example/examples/marquee_example.dart';
import 'package:oh_my_flutter_example/examples/maybe_safe_area_example.dart';
import 'package:oh_my_flutter_example/examples/morph_example.dart';
import 'package:oh_my_flutter_example/examples/morph_local_example.dart';
import 'package:oh_my_flutter_example/examples/motion_example.dart';
import 'package:oh_my_flutter_example/examples/native_selectable_text_example.dart';
import 'package:oh_my_flutter_example/examples/relative_time_example.dart';
import 'package:oh_my_flutter_example/examples/route_settled_example.dart';
import 'package:oh_my_flutter_example/examples/sequence_example.dart';
import 'package:oh_my_flutter_example/examples/skeleton_example.dart';
import 'package:oh_my_flutter_example/examples/snap_list_example.dart';
import 'package:oh_my_flutter_example/examples/text_motion_example.dart';

void main() => runApp(const UtilityExample());

/// A small gallery for the public utility APIs.
class UtilityExample extends StatefulWidget {
  /// Creates the utility example.
  const new({super.key});

  @override
  State<UtilityExample> createState() => _UtilityExampleState();
}

class _UtilityExampleState extends State<UtilityExample> {
  final _morphObserver = MorphNavigatorObserver();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [_morphObserver],
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
                        Text('Group', style: _sectionStyle),
                        SizedBox(height: 12),
                        GroupExample(),
                        SizedBox(height: 24),
                        GroupMorphExample(),
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
                        Text('NativeSelectableText', style: _sectionStyle),
                        SizedBox(height: 12),
                        NativeSelectableTextExample(),
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
                        MorphLocalExample(),
                        SizedBox(height: 24),
                        MorphExample(),
                        SizedBox(height: 32),
                        Text('SnapList', style: _sectionStyle),
                        SizedBox(height: 12),
                        SnapListExample(),
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
            const Positioned(top: 0, right: 24, child: MaybeSafeAreaExample()),
          ],
        ),
      ),
    );
  }

  static const _sectionStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
}
