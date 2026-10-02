part of '../morph_group_test.dart';

class _GroupFlightHarness extends StatefulWidget {
  const new({
    super.key,
    this.reducedMotion = false,
    this.emptyDestination = false,
    this.nestedMorph = false,
    this.repaintBoundaryDepth = 1,
    this.relayoutDestination = false,
  });
  final bool reducedMotion;
  final bool emptyDestination;
  final bool nestedMorph;
  final int repaintBoundaryDepth;
  final bool relayoutDestination;

  @override
  State<_GroupFlightHarness> createState() => _GroupFlightHarnessState();
}

class _GroupFlightHarnessState extends State<_GroupFlightHarness> {
  late final _source = MorphTarget(
    tag: 'group',
    duration: const Duration(seconds: 1),
    watchDestination: !widget.relayoutDestination,
  );

  final _sourceGroup = GroupLink();
  final _destinationGroup = GroupLink();
  final _observer = MorphNavigatorObserver();
  final _sourceTitle = MorphTarget(
    tag: 'group-title',
    duration: const Duration(seconds: 1),
  );

  final GlobalKey _destinationPaddingKey = GlobalKey();
  final GlobalKey _captureKey = GlobalKey();
  bool expanded = false;
  Color color = const Color(0xff0000ff);
  int taps = 0;

  void show({required bool expanded}) {
    setState(() => this.expanded = expanded);
    if (expanded && widget.relayoutDestination) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        (_destinationPaddingKey.currentContext!.findRenderObject()! as RenderPadding).padding = const EdgeInsets.only(
          top: 30,
        );
      });
    }
  }

  void recolor() => setState(() => color = const Color(0xff00ff00));

  Widget endpoint({required bool destination}) {
    final link = destination ? _destinationGroup : _sourceGroup;
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        children: [
          Positioned.fill(
            child: Morph(
              targets: [_source],
              flightConfig: MorphFlightConfig.custom(_GroupFlightDelegate(link)),
              child: widget.emptyDestination && destination
                  ? const SizedBox.expand()
                  : Group(
                      link: link,
                      child: Padding(
                        key: destination ? _destinationPaddingKey : null,
                        padding: EdgeInsets.zero,
                        child: ColoredBox(color: destination ? color : const Color(0xffff0000)),
                      ),
                    ),
            ),
          ),
          if (!widget.emptyDestination || !destination)
            Positioned(
              top: 10,
              left: 10,
              width: 20,
              height: 20,
              child: Group(
                link: link,
                zIndex: 1,
                child: Semantics(
                  label: destination ? 'destination attachment' : 'source attachment',
                  child: GestureDetector(
                    onTap: () => taps++,
                    child: widget.nestedMorph ? _nestedTitle() : const ColoredBox(color: Color(0xffffffff)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _nestedTitle() {
    Widget title = Morph(
      targets: [_sourceTitle],
      child: const ColoredBox(color: Color(0xffffffff)),
    );
    for (var depth = 0; depth < widget.repaintBoundaryDepth; depth++) {
      title = RepaintBoundary(child: title);
    }
    return title;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorObservers: [_observer],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: widget.reducedMotion),
      child: child!,
    ),
    home: Scaffold(
      backgroundColor: Colors.black,
      body: RepaintBoundary(
        key: _captureKey,
        child: Stack(
          children: [
            Positioned(left: 20, top: 20, child: endpoint(destination: false)),
            if (expanded) Positioned(left: 200, top: 20, child: endpoint(destination: true)),
          ],
        ),
      ),
    ),
  );
}
