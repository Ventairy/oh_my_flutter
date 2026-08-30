import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Builds independently projected controls for multi-foreground benchmarks.
final class MorphBenchmarkMultiForegroundWorkload extends StatelessWidget {
  /// Creates a static workload or one whose last control repaints live.
  const MorphBenchmarkMultiForegroundWorkload({
    required this.count,
    required this.mixed,
    required this.livePainter,
    super.key,
  }) : assert(count > 0, 'count must be at least one');

  /// Number of independently projected controls.
  final int count;

  /// Whether the last control uses [livePainter].
  final bool mixed;

  /// Paint-only animation used by the live control.
  final CustomPainter livePainter;

  @override
  Widget build(BuildContext context) {
    final liveIndex = mixed ? count - 1 : -1;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (var index = 0; index < count; index += 1)
          MorphSibling(
            tag: 'benchmark-multi-foreground',
            child: _buildControl(live: index == liveIndex),
          ),
      ],
    );
  }

  Widget _buildControl({required bool live}) {
    const control = SizedBox(
      width: 150,
      height: 60,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(30)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 24,
            ),
          ],
        ),
        child: Material(
          color: Color(0xFFFFFFFF),
          borderRadius: BorderRadius.all(Radius.circular(30)),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: <Widget>[
              SizedBox(width: 16),
              Icon(Icons.search, size: 17, color: Color(0xFF30343B)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Address',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF737A86),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
    if (!live) return control;
    return CustomPaint(foregroundPainter: livePainter, child: control);
  }
}
