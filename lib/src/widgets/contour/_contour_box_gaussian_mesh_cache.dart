part of 'contour.dart';

class _ContourBoxGaussianMeshCache {
  static final _meshes = <(double, double, double), _ContourBoxGaussianMesh>{};
  static int bytes = 0;
  static int retainedBytes = 0;
  static int retainedEntries = 0;
  static int builds = 0;
  static int hits = 0;
  static int generationMicroseconds = 0;
  static int coefficientMicroseconds = 0;
  static int arrayMicroseconds = 0;
  static int nativeVerticesMicroseconds = 0;
  static int get entries => _meshes.length;
  static int get activeBytes => bytes - retainedBytes;
  static int get activeEntries => entries - retainedEntries;

  static _ContourBoxGaussianMesh? obtain(Float32List values, double halfHeight, double radius) {
    final key = (values[3], halfHeight, radius);
    final cached = _meshes.remove(key);
    if (cached != null) {
      _meshes[key] = cached;
      if (cached.references == 0) {
        retainedBytes -= cached.bytes;
        retainedEntries--;
      }
      cached.references++;
      hits++;
      return cached;
    }
    final columns = ((values[3] + 4.5) * 4).ceil();
    final rows = ((halfHeight + 4.5) * 4).ceil();
    final count = (columns + 1) * (rows + 1);
    final requiredBytes = count * 12 + (rows * (columns + 1) * 2 + (rows - 1) * 2) * 2;
    if (count > 16384 || requiredBytes > 512 * 1024) return null;
    while (bytes + requiredBytes > 2 * 1024 * 1024) {
      if (!_evictUnused()) return null;
    }
    final mesh = _ContourBoxGaussianMesh(values, halfHeight)
      ..cacheKey = key
      ..references = 1;
    _meshes[key] = mesh;
    bytes += mesh.bytes;
    builds++;
    generationMicroseconds += mesh.generationMicroseconds;
    coefficientMicroseconds += mesh.coefficientMicroseconds;
    arrayMicroseconds += mesh.arrayMicroseconds;
    nativeVerticesMicroseconds += mesh.nativeVerticesMicroseconds;
    return mesh;
  }

  static void release(_ContourBoxGaussianMesh mesh) {
    mesh.references--;
    assert(mesh.references >= 0, 'Every mesh lease must be released once.');
    if (mesh.references != 0) return;
    retainedBytes += mesh.bytes;
    retainedEntries++;
    _meshes.remove(mesh.cacheKey);
    _meshes[mesh.cacheKey] = mesh;
    while (retainedEntries > 16 || retainedBytes > 512 * 1024) {
      if (!_evictUnused()) break;
    }
  }

  static bool _evictUnused() {
    (double, double, double)? unusedKey;
    for (final entry in _meshes.entries) {
      if (entry.value.references == 0) {
        unusedKey = entry.key;
        break;
      }
    }
    if (unusedKey == null) return false;
    final removed = _meshes.remove(unusedKey)!;
    bytes -= removed.bytes;
    retainedBytes -= removed.bytes;
    retainedEntries--;
    removed.vertices.dispose();
    return true;
  }
}
