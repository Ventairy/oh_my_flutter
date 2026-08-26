import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Shows a known content layout as a neutral loading skeleton.
class SkeletonExample extends StatelessWidget {
  /// Creates the Skeleton example.
  const SkeletonExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const Skeleton(
      style: SkeletonStyle(
        effect: SkeletonShimmerEffect(),
        radius: Radius.circular(6),
      ),
      child: ListTile(
        leading: CircleAvatar(child: Icon(Icons.person)),
        title: Text('Loading profile'),
        subtitle: Text('Loading profile details'),
      ),
    );
  }
}
