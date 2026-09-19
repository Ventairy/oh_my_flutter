part of '../morph_group_test.dart';

class _GroupFlightHarness extends StatefulWidget {
  const new({
    super.key,
    this.reducedMotion = false,
    this.emptyDestination = false,
    this.nestedMorph = false,
    this.relayoutDestination = false,
  });
  final bool reducedMotion;
  final bool emptyDestination;
  final bool nestedMorph;
  final bool relayoutDestination;

  @override
  State<_GroupFlightHarness> createState() => _GroupFlightHarnessState();
}

class _GroupFlightHarnessState extends State<_GroupFlightHarness> {
  final _source = MorphTarget(tag: 'group');
  final _destination = MorphTarget(tag: 'group');
  final _sourceGroup = GroupLink();
  final _destinationGroup = GroupLink();
  final _observer = MorphNavigatorObserver();
  final _sourceTitle = MorphTarget(tag: 'group-title');
  final _destinationTitle = MorphTarget(tag: 'group-title');
  final GlobalKey _destinationPaddingKey = GlobalKey();
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
              target: destination ? _destination : _source,
              duration: const Duration(seconds: 1),
              animateChildChanges: true,
              watchDestination: !widget.relayoutDestination,
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
                    child: widget.nestedMorph
                        ? RepaintBoundary(
                            child: Morph(
                              target: destination ? _destinationTitle : _sourceTitle,
                              duration: const Duration(seconds: 1),
                              animateChildChanges: true,
                              child: const ColoredBox(color: Color(0xffffffff)),
                            ),
                          )
                        : const ColoredBox(color: Color(0xffffffff)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorObservers: [_observer],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: widget.reducedMotion),
      child: child!,
    ),
    home: Scaffold(
      body: Stack(
        children: [
          Positioned(left: 20, top: 20, child: endpoint(destination: false)),
          if (expanded) Positioned(left: 200, top: 20, child: endpoint(destination: true)),
        ],
      ),
    ),
  );
}
