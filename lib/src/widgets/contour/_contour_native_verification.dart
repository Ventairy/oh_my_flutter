part of 'contour.dart';

class _ContourNativeVerification {
  static Future<Map<String, int>> check(
    Uint8List rgba,
    int width,
    int height,
    double ratio,
    Uint8List original,
    int originalWidth,
    int originalHeight,
    int padding,
  ) async {
    final tolerance = (ratio * .5).ceil();
    final components = await _components(rgba, width, height, ratio);
    final componentExpandedAlpha = List<int>.filled(components.fillAlpha.length, 0);
    final componentMissing = List<int>.filled(components.fillAlpha.length, 0);
    var colored = 0;
    var baseDistant = 0;
    var extra = 0;
    var missing = 0;
    var thinOpaque = 0;
    var thinInteriorOpaque = 0;
    var fillOpaque = 0;
    var thinAlpha = 0;
    var fillAlpha = 0;
    var expandedAlpha = 0;
    var boundary = 0;
    final panelBytes = width * height * 4;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = (y * width + x) * 4;
        final alpha = rgba[pixel + 3];
        final thin = rgba[panelBytes * 2 + pixel + 3];
        final recolored = panelBytes * 4 + pixel;
        final redAlpha = rgba[recolored + 3];
        // Color fonts can ignore both stroke and foreground paint. A red-fill
        // probe rejects even a tiny white bitmap attached to a large glyph,
        // without granting it another component's tolerance budget. Glyph AA
        // coverage depends on paint luminance, so compare hue/premultiplication
        // rather than requiring equal white and red fringe alpha values.
        if ((alpha >= 8 || redAlpha >= 8) &&
            ((alpha >= 128 && redAlpha < 8) ||
                (rgba[recolored] - redAlpha).abs() > 2 ||
                rgba[recolored + 1] > 1 ||
                rgba[recolored + 2] > 1)) {
          colored++;
        }
        fillAlpha += alpha;
        thinAlpha += thin;
        final expanded = rgba[panelBytes + pixel + 3];
        expandedAlpha += expanded;
        final component = components.labels[y * width + x];
        componentExpandedAlpha[component] += expanded;
        if (alpha >= 128) fillOpaque++;
        if (thin >= 128) {
          thinOpaque++;
          final inside = alpha >= 128;
          var edge = false;
          for (var dy = -tolerance; dy <= tolerance && !edge; dy++) {
            final ny = y + dy;
            if (ny < 0 || ny >= height) continue;
            for (var dx = -tolerance; dx <= tolerance; dx++) {
              if (dx * dx + dy * dy > tolerance * tolerance) continue;
              final nx = x + dx;
              if (nx < 0 || nx >= width) continue;
              if ((rgba[(ny * width + nx) * 4 + 3] >= 128) != inside) {
                edge = true;
                break;
              }
            }
          }
          if (!edge) thinInteriorOpaque++;
        }
        for (final panel in const [0, 1]) {
          final index = panelBytes * panel + pixel;
          final a = rgba[index + 3];
          if (a >= 8 &&
              ((rgba[index] - a).abs() > 2 || (rgba[index + 1] - a).abs() > 2 || (rgba[index + 2] - a).abs() > 2)) {
            colored++;
          }
          if ((x == 0 || y == 0 || x == width - 1 || y == height - 1) && a >= 8) boundary++;
          final inside = a >= 128;
          final expected = panel == 0
              ? _sourceAlpha(original, originalWidth, originalHeight, x - padding, y - padding)
              : rgba[panelBytes * 3 + pixel + 3];
          if (inside == (expected >= 128)) continue;
          var nearby = false;
          for (var dy = -tolerance; dy <= tolerance && !nearby; dy++) {
            final ny = y + dy;
            if (ny < 0 || ny >= height) continue;
            for (var dx = -tolerance; dx <= tolerance; dx++) {
              if (dx * dx + dy * dy > tolerance * tolerance) continue;
              final nx = x + dx;
              if (nx < 0 || nx >= width) continue;
              final neighbor = panel == 0
                  ? _sourceAlpha(original, originalWidth, originalHeight, nx - padding, ny - padding)
                  : rgba[panelBytes * 3 + (ny * width + nx) * 4 + 3];
              if ((neighbor >= 128) == inside) {
                nearby = true;
                break;
              }
            }
          }
          if (!nearby) {
            if (panel == 0) {
              baseDistant++;
            } else if (inside) {
              extra++;
            } else {
              missing++;
              componentMissing[component]++;
            }
          }
        }
      }
      if (kIsWeb && y % 16 == 0) await Future<void>.delayed(Duration.zero);
    }
    // The native glyph is the appearance target. The reconstruction can close
    // a few tiny holes/valleys earlier. Permit sparse backing retreat while
    // rejecting new protrusions and any mismatch against the actual source.
    final missingBudget = math.max((ratio * ratio).ceil(), (fillOpaque * .01).ceil());
    var rejectedComponents = componentMissing[0] == 0 ? 0 : 1;
    final opacityFloor = (_ContourTracer._minimumOpacity * 255).ceil();
    final minimumAlphaArea = _ContourTracer._minimumVisibleArea * 255 * ratio * ratio;
    for (var component = 1; component < components.fillAlpha.length; component++) {
      final peak = components.peak[component];
      final alpha = components.fillAlpha[component];
      if (peak < opacityFloor || (peak < 128 && alpha < minimumAlphaArea)) continue;
      final opaque = components.fillOpaque[component];
      final localMissingBudget = math.max((ratio * ratio).ceil(), (opaque * .01).ceil());
      // Font fallback can mix a tiny bitmap glyph with a large vector paragraph.
      // Each visible component must honor stroke independently; a neighboring
      // word must not hide an unchanged bitmap inside a paragraph-wide budget.
      if (components.thinOpaque[component] * 100 > opaque ||
          components.thinAlpha[component] * 16 >= alpha ||
          componentExpandedAlpha[component] <= alpha ||
          componentMissing[component] > localMissingBudget) {
        rejectedComponents++;
      }
    }
    return {
      'accepted':
          rejectedComponents == 0 &&
              colored == 0 &&
              baseDistant == 0 &&
              extra == 0 &&
              missing <= missingBudget &&
              boundary == 0 &&
              fillOpaque >= 4 &&
              thinOpaque * 100 <= fillOpaque &&
              thinInteriorOpaque == 0 &&
              thinAlpha * 16 < fillAlpha &&
              expandedAlpha > fillAlpha
          ? 1
          : 0,
      'rejectedComponents': rejectedComponents,
      'baseDistant': baseDistant,
      'extra': extra,
      'missing': missing,
      'missingBudget': missingBudget,
      'colored': colored,
      'boundary': boundary,
      'thinOpaque': thinOpaque,
      'thinInteriorOpaque': thinInteriorOpaque,
      'fillOpaque': fillOpaque,
      'thinAlpha': thinAlpha,
      'fillAlpha': fillAlpha,
      'expandedAlpha': expandedAlpha,
    };
  }

  static Future<
    ({
      Int32List labels,
      List<int> fillAlpha,
      List<int> fillOpaque,
      List<int> thinAlpha,
      List<int> thinOpaque,
      List<int> peak,
    })
  >
  _components(Uint8List rgba, int width, int height, double ratio) async {
    final pixels = width * height;
    final panelBytes = pixels * 4;
    final labels = Int32List(pixels);
    final queue = Uint32List(pixels);
    final fillAlpha = <int>[0];
    final fillOpaque = <int>[0];
    final thinAlpha = <int>[0];
    final thinOpaque = <int>[0];
    final peak = <int>[0];
    var processed = 0;
    for (var start = 0; start < pixels; start++) {
      if (kIsWeb && start % 4096 == 0) await Future<void>.delayed(Duration.zero);
      if (labels[start] != 0 || rgba[start * 4 + 3] == 0) continue;
      final component = fillAlpha.length;
      fillAlpha.add(0);
      fillOpaque.add(0);
      thinAlpha.add(0);
      thinOpaque.add(0);
      peak.add(0);
      labels[start] = component;
      queue[0] = start;
      var count = 1;
      for (var head = 0; head < count; head++) {
        final index = queue[head];
        final alpha = rgba[index * 4 + 3];
        final thin = rgba[panelBytes * 2 + index * 4 + 3];
        fillAlpha[component] += alpha;
        thinAlpha[component] += thin;
        if (alpha >= 128) fillOpaque[component]++;
        if (thin >= 128) thinOpaque[component]++;
        peak[component] = math.max(peak[component], alpha);
        final x = index % width;
        final y = index ~/ width;
        for (var dy = -1; dy <= 1; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= height) continue;
          for (var dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            if (nx < 0 || nx >= width) continue;
            final neighbor = ny * width + nx;
            if (labels[neighbor] != 0 || rgba[neighbor * 4 + 3] == 0) continue;
            labels[neighbor] = component;
            queue[count++] = neighbor;
          }
        }
        if (kIsWeb && ++processed % 4096 == 0) await Future<void>.delayed(Duration.zero);
      }
    }

    // Assign the nearby canonical expansion to its original component. A
    // bounded, simultaneous flood keeps neighboring letters from claiming all
    // of a small component's growth or missing-pixel allowance.
    var count = 0;
    for (var index = 0; index < pixels; index++) {
      if (labels[index] != 0) queue[count++] = index;
    }
    var head = 0;
    for (var distance = 0; distance < (ratio * 2).ceil() && head < count; distance++) {
      final end = count;
      while (head < end) {
        final index = queue[head++];
        final x = index % width;
        final y = index ~/ width;
        for (var dy = -1; dy <= 1; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= height) continue;
          for (var dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            if (nx < 0 || nx >= width) continue;
            final neighbor = ny * width + nx;
            if (labels[neighbor] != 0) continue;
            labels[neighbor] = labels[index];
            queue[count++] = neighbor;
          }
        }
        if (kIsWeb && head % 4096 == 0) await Future<void>.delayed(Duration.zero);
      }
    }
    return (
      labels: labels,
      fillAlpha: fillAlpha,
      fillOpaque: fillOpaque,
      thinAlpha: thinAlpha,
      thinOpaque: thinOpaque,
      peak: peak,
    );
  }

  static int _sourceAlpha(Uint8List original, int width, int height, int x, int y) =>
      x < 0 || y < 0 || x >= width || y >= height ? 0 : original[(y * width + x) * 4 + 3];
}
