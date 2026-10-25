import 'dart:ffi';
import 'dart:io';

/// Applies process-local Android affinity for a controlled benchmark run.
abstract final class ContourBenchmarkCpuAffinity {
  /// Pins every current thread and records the kernel-reported result.
  static Map<String, Object?> apply(
    String hexadecimalMask, {
    required void Function(Map<String, Object?> thread) onThread,
  }) {
    if (!Platform.isAndroid) return {'supported': false, 'reason': 'Android only'};
    final mask = int.tryParse(hexadecimalMask.replaceFirst(RegExp('^0[xX]'), ''), radix: 16);
    if (mask == null || mask <= 0) return {'applied': false, 'reason': 'No positive hexadecimal mask'};
    final library = DynamicLibrary.open('libc.so');
    final malloc = library.lookupFunction<Pointer<Void> Function(IntPtr), Pointer<Void> Function(int)>('malloc');
    final free = library.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('free');
    final setAffinity = library
        .lookupFunction<Int Function(Int, IntPtr, Pointer<Void>), int Function(int, int, Pointer<Void>)>(
          'sched_setaffinity',
        );
    final errno = library.lookupFunction<Pointer<Int> Function(), Pointer<Int> Function()>('__errno');
    final memory = malloc(128);
    if (memory == nullptr) return {'applied': false, 'reason': 'Allocation failed'};
    final bytes = memory.cast<Uint8>().asTypedList(128)..fillRange(0, 128, 0);
    for (var index = 0; index < 8; index++) {
      bytes[index] = (mask >> (index * 8)) & 255;
    }
    final allowedCpuCounts = <String, int>{};
    var threadCount = 0;
    var failures = 0;
    var restricted = 0;
    try {
      for (final task in Directory('/proc/self/task').listSync()) {
        final id = int.tryParse(task.path.split('/').last);
        if (id == null) continue;
        final before = _status(task.path);
        final result = setAffinity(id, 128, memory);
        final error = result == 0 ? 0 : errno().value;
        final after = _status(task.path);
        threadCount++;
        if (result != 0) failures++;
        final allowed = after['allowed_cpus'];
        allowedCpuCounts.update(allowed ?? 'unknown', (count) => count + 1, ifAbsent: () => 1);
        if (_isRestricted(allowed, mask)) restricted++;
        onThread({'tid': id, 'before': before, 'after': after, 'result': result, 'errno': error});
      }
    } finally {
      free(memory);
    }
    return {
      'supported': true,
      'requested_mask_hex': hexadecimalMask,
      'thread_count': threadCount,
      'syscall_failures': failures,
      'all_threads_restricted': threadCount > 0 && restricted == threadCount,
      'allowed_cpu_counts': allowedCpuCounts,
    };
  }

  /// Records affinity of current threads, including threads created later.
  static Map<String, Object?> inspect(
    String hexadecimalMask, {
    required void Function(Map<String, Object?> thread) onThread,
  }) {
    if (!Platform.isAndroid) return {'supported': false};
    final mask = int.tryParse(hexadecimalMask.replaceFirst(RegExp('^0[xX]'), ''), radix: 16) ?? 0;
    final allowedCpuCounts = <String, int>{};
    var threadCount = 0;
    var restricted = 0;
    for (final task in Directory('/proc/self/task').listSync()) {
      final status = _status(task.path);
      final allowed = status['allowed_cpus'];
      threadCount++;
      allowedCpuCounts.update(allowed ?? 'unknown', (count) => count + 1, ifAbsent: () => 1);
      if (_isRestricted(allowed, mask)) restricted++;
      onThread({'tid': task.path.split('/').last, ...status});
    }
    return {
      'supported': true,
      'requested_mask_hex': hexadecimalMask,
      'thread_count': threadCount,
      'all_threads_restricted': threadCount > 0 && restricted == threadCount,
      'allowed_cpu_counts': allowedCpuCounts,
    };
  }

  static bool _isRestricted(String? allowed, int mask) {
    if (allowed == null || allowed.isEmpty || mask <= 0) return false;
    for (final range in allowed.split(',')) {
      final limits = range.split('-');
      final first = int.tryParse(limits.first);
      final last = int.tryParse(limits.last);
      if (first == null || last == null || first < 0 || last >= 63) return false;
      for (var cpu = first; cpu <= last; cpu++) {
        if ((mask & (1 << cpu)) == 0) return false;
      }
    }
    return true;
  }

  static Map<String, String?> _status(String path) {
    try {
      final lines = File('$path/status').readAsLinesSync();
      String? value(String field) {
        for (final line in lines) {
          if (line.startsWith('$field:')) return line.substring(field.length + 1).trim();
        }
        return null;
      }

      return {'name': value('Name'), 'allowed_cpus': value('Cpus_allowed_list')};
    } on FileSystemException {
      return {'name': null, 'allowed_cpus': null};
    }
  }
}
