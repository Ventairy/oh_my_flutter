part of 'contour_composite_source_io.dart';

class _ContourCompositeLayout {
  new({required this.width, required this.height, required this.offsets});
  final int width;
  final int height;
  final List<(int, int)> offsets;

  static _ContourCompositeLayout? pack(List<_ContourCompositeRequest> jobs) {
    final area = jobs.fold<int>(0, (sum, job) => sum + job.width * job.height);
    final order = List<int>.generate(jobs.length, (index) => index)
      ..sort((a, b) => jobs[b].height.compareTo(jobs[a].height));
    final minWidth = jobs.map((job) => job.width).reduce(math.max);
    _ContourCompositeLayout? best;
    for (var limit = ((minWidth + 31) ~/ 32) * 32; limit <= 4096; limit += 32) {
      var x = 0;
      var y = 0;
      var shelf = 0;
      var actual = 0;
      final offsets = List<(int, int)>.filled(jobs.length, (0, 0));
      for (final index in order) {
        final job = jobs[index];
        if (x + job.width > limit) {
          y += shelf;
          x = 0;
          shelf = 0;
        }
        offsets[index] = (x, y);
        x += job.width;
        actual = math.max(actual, x);
        shelf = math.max(shelf, job.height);
      }
      final height = y + shelf;
      final pixels = actual * height;
      if (height > 4096 || pixels > area * 2 || pixels > 4 * 1024 * 1024) continue;
      if (best == null || pixels < best.width * best.height) {
        best = _ContourCompositeLayout(width: actual, height: height, offsets: offsets);
      }
      if (limit > math.max(minWidth, math.sqrt(area) * 2)) break;
    }
    return best;
  }
}
