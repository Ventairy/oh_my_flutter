part of 'interactive_swipe_dismiss_benchmark.dart';

class _InteractiveSwipeDismissBenchmarkHeavyChild extends StatelessWidget {
  const _InteractiveSwipeDismissBenchmarkHeavyChild({
    required this.handleKey,
    required this.scrollController,
  });

  final GlobalKey handleKey;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8F7F3),
      borderRadius: const BorderRadius.all(Radius.circular(42)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InteractiveSwipeDismissHandle(
            key: handleKey,
            child: const SizedBox(
              width: double.infinity,
              height: _InteractiveSwipeDismissBenchmarkState._headerHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFF8D8D8D),
                      borderRadius: BorderRadius.all(Radius.circular(99)),
                    ),
                    child: SizedBox(width: 50, height: 7),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Interactive job header',
                    style: TextStyle(
                      color: Color(0xFF242321),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: _InteractiveSwipeDismissBenchmarkState._heavyRowCount,
              itemExtent: 92,
              itemBuilder: (context, index) {
                final tone = 235 - (index % 5) * 7;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, tone, tone - 2, tone - 7),
                    border: const Border(
                      bottom: BorderSide(color: Color(0x1F000000)),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color.fromARGB(
                              255,
                              54 + (index % 4) * 18,
                              92 + (index % 3) * 16,
                              126 + (index % 5) * 12,
                            ),
                            borderRadius: const BorderRadius.all(
                              Radius.circular(18),
                            ),
                          ),
                          child: const SizedBox.square(dimension: 56),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Static job detail ${index + 1}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 7),
                              FractionallySizedBox(
                                widthFactor: 0.72,
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0x22000000),
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
