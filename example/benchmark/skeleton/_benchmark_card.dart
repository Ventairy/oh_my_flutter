part of 'skeleton_benchmark.dart';

class _BenchmarkCard extends StatelessWidget {
  const _BenchmarkCard({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 124,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  child: Icon(Icons.work_outline),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Loading opportunity number $index',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Nearby work with realistic descriptive content',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 16),
                          SizedBox(width: 4),
                          Text('2.4 km away'),
                          Spacer(),
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CustomPaint(painter: _PaintProbePainter()),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
