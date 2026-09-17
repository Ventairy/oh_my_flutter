part of '../group_golden_test.dart';

class _GroupGoldenHarness extends StatefulWidget {
  const _GroupGoldenHarness({super.key});
  @override
  State<_GroupGoldenHarness> createState() => _GroupGoldenHarnessState();
}

class _GroupGoldenHarnessState extends State<_GroupGoldenHarness> {
  final GroupLink link = GroupLink();
  final GlobalKey reference = GlobalKey();
  GroupSnapshot? snapshot;

  Future<void> capture() async {
    final value = await link.capture(relativeTo: reference.currentContext!, pixelRatio: 1);
    setState(() => snapshot = value);
  }

  @override
  void dispose() {
    snapshot?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: const Color(0xffffffff),
      child: Column(
        children: [
          SizedBox(
            key: reference,
            width: 160,
            height: 100,
            child: Stack(
              children: [
                Positioned(
                  left: 10,
                  top: 10,
                  width: 90,
                  height: 70,
                  child: Group(
                    link: link,
                    zIndex: 1,
                    child: const ColoredBox(color: Color(0xffee8844)),
                  ),
                ),
                Positioned(
                  left: 60,
                  top: 40,
                  width: 90,
                  height: 50,
                  child: Group(
                    link: link,
                    child: const ColoredBox(color: Color(0xff4477cc)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (snapshot case final value?)
            SizedBox.fromSize(
              size: value.size,
              child: CustomPaint(painter: _GroupGoldenPainter(value)),
            ),
        ],
      ),
    ),
  );
}
