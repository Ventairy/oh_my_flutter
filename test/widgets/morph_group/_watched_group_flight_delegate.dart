part of '../morph_group_test.dart';

@immutable
final class _WatchedGroupFlightProperties {
  const new({required this.size, required this.snapshot, required this.footerBottomInset});

  final Size size;
  final Widget snapshot;
  final double footerBottomInset;
}

final class _WatchedGroupFlightDelegate extends MorphFlightDelegate<_WatchedGroupFlightProperties> {
  const new(this.link, this.onProperties, this.onBuiltDestination);

  final GroupLink link;
  final ValueChanged<double> onProperties;
  final ValueChanged<double> onBuiltDestination;

  @override
  Iterable<GroupLink> get contentGroups => [link];

  @override
  _WatchedGroupFlightProperties properties(MorphEndpointContext endpoint) {
    final size = endpoint.localSize;
    final footerBottomInset = MediaQuery.viewInsetsOf(endpoint.context).bottom;
    onProperties(footerBottomInset);
    return _WatchedGroupFlightProperties(
      size: size,
      footerBottomInset: footerBottomInset,
      snapshot: SizedBox.fromSize(
        size: size,
        child: FittedBox(
          fit: BoxFit.fill,
          child: endpoint.groupSnapshot(link),
        ),
      ),
    );
  }

  @override
  _WatchedGroupFlightProperties lerpProperties(
    _WatchedGroupFlightProperties source,
    _WatchedGroupFlightProperties destination,
    MorphFlightProgress progress,
  ) {
    return _WatchedGroupFlightProperties(
      size: Size.lerp(source.size, destination.size, progress.curvedProgress)!,
      snapshot: progress.curvedProgress < .5 ? source.snapshot : destination.snapshot,
      footerBottomInset: ui.lerpDouble(
        source.footerBottomInset,
        destination.footerBottomInset,
        progress.curvedProgress,
      )!,
    );
  }

  @override
  Widget buildFlight(
    BuildContext context,
    MorphFlight<_WatchedGroupFlightProperties> flight,
  ) {
    return AnimatedBuilder(
      animation: flight.curvedAnimation,
      builder: (context, child) {
        onBuiltDestination(flight.destination.properties.footerBottomInset);
        final properties = flight.properties;
        return SizedBox.fromSize(
          size: properties.size,
          child: Stack(
            children: [
              Positioned.fill(child: properties.snapshot),
              Positioned(
                left: 10,
                bottom: 10 + properties.footerBottomInset,
                width: 40,
                height: 10,
                child: const ColoredBox(color: _WatchedGroupFlightHarness.footerColor),
              ),
            ],
          ),
        );
      },
    );
  }
}
