part of '../morph_group_test.dart';

class _WatchedGroupFlightHarness extends StatefulWidget {
  const new({super.key});

  static const frameKey = ValueKey<String>('watched-group-frame');
  static const titleColor = Color(0xffff0000);
  static const footerColor = Color(0xff00ff00);

  @override
  State<_WatchedGroupFlightHarness> createState() => _WatchedGroupFlightHarnessState();
}

class _WatchedGroupFlightHarnessState extends State<_WatchedGroupFlightHarness> with SingleTickerProviderStateMixin {
  final _target = MorphTarget(
    tag: 'watched-group',
    duration: const Duration(milliseconds: 600),
    curve: Curves.linear,
    watchDestination: true,
  );
  final _sourceGroup = GroupLink();
  final _destinationGroup = GroupLink();
  final _observer = MorphNavigatorObserver();

  bool _destinationVisible = false;
  bool _animatesDestinationInset = false;
  double _destinationBottomInset = 0;
  final capturedInsets = <double>[];
  final builtDestinationInsets = <double>[];
  late final AnimationController _destinationInsetController;

  @override
  void initState() {
    super.initState();
    _destinationInsetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  void showDestination() => setState(() => _destinationVisible = true);

  void showDestinationWithAnimatedInset() {
    setState(() {
      _animatesDestinationInset = true;
      _destinationVisible = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _destinationInsetController.forward();
    });
  }

  void resizeDestination() {
    setState(() => _destinationBottomInset = 20);
    setState(() => _destinationBottomInset = 40);
  }

  @override
  void dispose() {
    _destinationInsetController.dispose();
    super.dispose();
  }

  Widget _endpoint({required bool destination}) {
    if (destination && _animatesDestinationInset) {
      return AnimatedBuilder(
        animation: _destinationInsetController,
        builder: (context, child) => _buildEndpoint(destination: true),
      );
    }
    return _buildEndpoint(destination: destination);
  }

  Widget _buildEndpoint({required bool destination}) {
    final link = destination ? _destinationGroup : _sourceGroup;
    final height = destination ? 160.0 : 100.0;
    return Positioned(
      left: destination ? 200 : 20,
      top: 20,
      width: 100,
      height: height,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          viewInsets: EdgeInsets.only(
            bottom: destination ? _resolvedDestinationBottomInset : 0,
          ),
        ),
        child: Morph(
          key: ValueKey<bool>(destination),
          targets: [_target],
          flightConfig: .custom(
            _WatchedGroupFlightDelegate(
              link,
              capturedInsets.add,
              builtDestinationInsets.add,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Group(
                  link: link,
                  child: const ColoredBox(color: Color(0xff0000ff)),
                ),
              ),
              Positioned(
                left: 10,
                top: 10,
                width: 20,
                height: 20,
                child: Group(
                  link: link,
                  zIndex: 1,
                  child: const ColoredBox(color: _WatchedGroupFlightHarness.titleColor),
                ),
              ),
              Positioned(
                left: 10,
                bottom: 10 + (destination ? _resolvedDestinationBottomInset : 0),
                width: 40,
                height: 10,
                child: const ColoredBox(color: _WatchedGroupFlightHarness.footerColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double get _resolvedDestinationBottomInset =>
      _animatesDestinationInset ? _destinationInsetController.value * 40 : _destinationBottomInset;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _WatchedGroupFlightHarness.frameKey,
      child: MaterialApp(
        navigatorObservers: [_observer],
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              _endpoint(destination: false),
              if (_destinationVisible) _endpoint(destination: true),
            ],
          ),
        ),
      ),
    );
  }
}
