import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'frame_report.dart';
import 'menu_readiness.dart';
import 'record_buffer.dart';
import 'scenario.dart';
import 'view_readiness.dart';

const bool _enforceFrameBudget = bool.fromEnvironment(
  'NATIVE_SELECTABLE_TEXT_ENFORCE_FRAME_BUDGET',
);

const int _warmupFrameCount = int.fromEnvironment(
  'NATIVE_SELECTABLE_TEXT_WARMUP_FRAMES',
  defaultValue: 180,
);
const int _measuredFrameCount = int.fromEnvironment(
  'NATIVE_SELECTABLE_TEXT_MEASURED_FRAMES',
  defaultValue: 600,
);
const int _itemCount = int.fromEnvironment(
  'NATIVE_SELECTABLE_TEXT_ITEM_COUNT',
  defaultValue: 240,
);
const String _scenarioName = String.fromEnvironment(
  'NATIVE_SELECTABLE_TEXT_SCENARIO',
  defaultValue: 'selection',
);
const String _widgetName = String.fromEnvironment(
  'NATIVE_SELECTABLE_TEXT_WIDGET',
  defaultValue: 'native',
);
const String _textCaseName = String.fromEnvironment(
  'NATIVE_SELECTABLE_TEXT_TEXT_CASE',
  defaultValue: 'paragraph',
);
const String _rendererName = String.fromEnvironment(
  'NATIVE_SELECTABLE_TEXT_RENDERER',
  defaultValue: 'unspecified',
);
const String _runId = String.fromEnvironment(
  'NATIVE_SELECTABLE_TEXT_RUN_ID',
  defaultValue: 'unspecified',
);

const String _shortSelectionText =
    'Copy this native selection '
    'without dropping a frame.';
const String _paragraphSelectionText =
    'Native selectable text keeps Flutter layout, rendering, selection, '
    'semantics, handles, and magnification while the operating system presents '
    'the available commands. This deliberately long paragraph makes every '
    'selection update exercise realistic glyph and endpoint calculations.';
const String _longSelectionText =
    '$_paragraphSelectionText $_paragraphSelectionText '
    '$_paragraphSelectionText $_paragraphSelectionText';
const TextSpan _richSelectionText = TextSpan(
  children: <TextSpan>[
    TextSpan(
      text: 'Native selectable text ',
      style: TextStyle(fontWeight: FontWeight.w700),
    ),
    TextSpan(text: 'keeps Flutter layout, rendering, and selection '),
    TextSpan(
      text: 'fast ',
      style: TextStyle(fontStyle: FontStyle.italic),
    ),
    TextSpan(text: 'while the operating system presents the available '),
    TextSpan(
      text: 'commands.',
      style: TextStyle(decoration: TextDecoration.underline),
    ),
  ],
);

enum _BenchmarkWidget {
  native,
  selectable;

  static _BenchmarkWidget parse(String value) {
    return switch (value) {
      'native' => native,
      'selectable' => selectable,
      _ => throw ArgumentError.value(
        value,
        'widget',
        'must be native or selectable',
      ),
    };
  }
}

enum _BenchmarkTextCase {
  short,
  paragraph,
  long,
  rich;

  static _BenchmarkTextCase parse(String value) {
    return switch (value) {
      'short' => short,
      'paragraph' => paragraph,
      'long' => long,
      'rich' => rich,
      _ => throw ArgumentError.value(
        value,
        'textCase',
        'must be short, paragraph, long, or rich',
      ),
    };
  }
}

/// Runs profile-mode scrolling and active-selection workloads.
class NativeSelectableTextBenchmark extends StatefulWidget {
  /// Creates the benchmark application.
  const NativeSelectableTextBenchmark({super.key});

  @override
  State<NativeSelectableTextBenchmark> createState() {
    return _NativeSelectableTextBenchmarkState();
  }
}

// The formatter keeps this declaration on one line at its 120-column width.
// ignore: lines_longer_than_80_chars
class _NativeSelectableTextBenchmarkState extends State<NativeSelectableTextBenchmark>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const int _trialCount = 2;
  static const Duration _timingsTimeout = Duration(minutes: 2);
  static const Duration _viewReadinessTimeout = Duration(seconds: 30);
  static const Duration _menuPresentationSettleDuration = Duration(
    milliseconds: 250,
  );

  final GlobalKey _selectionKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  final List<ui.FrameTiming> _windowFrames = <ui.FrameTiming>[];
  final List<String> _failedTrialPaths = <String>[];
  late final NativeSelectableTextBenchmarkScenario _scenario;
  late final _BenchmarkWidget _benchmarkWidget;
  late final _BenchmarkTextCase _textCase;
  late final String _plainText;
  late final TextSpan? _richText;
  late final Ticker _ticker;
  late final NativeSelectableTextBenchmarkRecordBuffer _recordBuffer;
  late EditableTextState _editableTextState;
  Completer<void>? _startupLifecycleChanged;
  Completer<void>? _windowFramesReady;
  NativeSelectableTextBenchmarkViewReadiness? _readyView;
  NativeSelectableTextBenchmarkViewReadiness? _startupObservation;
  int? _windowStartMicros;
  int _windowTargetFrames = 0;
  int _workloadStep = 0;
  int _startupReadinessFrameCount = 0;
  double _scrollOffset = 0;
  double _scrollDirection = 1;
  bool _windowIsActive = false;
  bool _isInteractive = true;

  @override
  void initState() {
    super.initState();
    _scenario = NativeSelectableTextBenchmarkScenario.parse(_scenarioName);
    _benchmarkWidget = _BenchmarkWidget.parse(_widgetName);
    _textCase = _BenchmarkTextCase.parse(_textCaseName);
    final content = switch (_textCase) {
      _BenchmarkTextCase.short => (_shortSelectionText, null),
      _BenchmarkTextCase.paragraph => (_paragraphSelectionText, null),
      _BenchmarkTextCase.long => (_longSelectionText, null),
      _BenchmarkTextCase.rich => (
        _richSelectionText.toPlainText(),
        _richSelectionText,
      ),
    };
    _plainText = content.$1;
    _richText = content.$2;
    _recordBuffer = NativeSelectableTextBenchmarkRecordBuffer(
      (message) => debugPrint(message, wrapWidth: 4000),
    );
    _ticker = createTicker(_handleWorkloadTick);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isInteractive = lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance
      ..addObserver(this)
      ..addTimingsCallback(_handleTimings)
      ..addPostFrameCallback((_) => unawaited(_run()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isInteractive = state == AppLifecycleState.resumed;
    _signalStartupLifecycleChanged();
  }

  @override
  void dispose() {
    _signalStartupLifecycleChanged();
    WidgetsBinding.instance
      ..removeObserver(this)
      ..removeTimingsCallback(_handleTimings);
    _ticker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    var benchmarkFailed = false;
    var passed = false;
    try {
      _validateStaticConfiguration();
      _readyView = await _waitForReadyView();
      _validateReadyView();
      await _prepareWorkload();
      _printEnvironment();
      for (var trial = 1; trial <= _trialCount; trial += 1) {
        await _collectGuardedFrames(
          _warmupFrameCount,
          window: 'trial $trial warmup window',
        );
        final frames = await _collectGuardedFrames(
          _measuredFrameCount,
          window: 'trial $trial measured window',
        );
        _printTrial(trial, frames);
      }
      passed = _failedTrialPaths.isEmpty;
      _print(<String, Object>{
        'path': 'acceptance',
        'run_id': _runId,
        'scenario': _scenario.id,
        'widget': _benchmarkWidget.name,
        'text_case': _textCase.name,
        'passed': passed,
        'enforced': _enforceFrameBudget,
        'failed_trial_paths': _failedTrialPaths,
        'trials': _trialCount,
        'frames_per_trial': _measuredFrameCount,
      });
    } on Object catch (error, stackTrace) {
      benchmarkFailed = true;
      _print(<String, Object>{
        'path': 'error',
        'run_id': _runId,
        'error': error.toString(),
        'stack_trace': stackTrace.toString(),
      });
    } finally {
      WidgetsBinding.instance.removeTimingsCallback(_handleTimings);
      _recordBuffer.flush();
      await debugPrintDone;
      SchedulerBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await SystemNavigator.pop();
        final budgetFailed = _enforceFrameBudget && !passed;
        exit(benchmarkFailed || budgetFailed ? 1 : 0);
      });
    }
  }

  void _validateStaticConfiguration() {
    if (!kProfileMode) {
      throw StateError('The benchmark must run in profile mode.');
    }
    if (_runId.trim().isEmpty || _runId == 'unspecified') {
      throw StateError('Set NATIVE_SELECTABLE_TEXT_RUN_ID to a fresh value.');
    }
    if (_rendererName.trim().isEmpty || _rendererName == 'unspecified') {
      throw StateError(
        'Set NATIVE_SELECTABLE_TEXT_RENDERER after verifying startup logs.',
      );
    }
    if (_warmupFrameCount < 1 || _measuredFrameCount < 1) {
      throw StateError('Warmup and measured frame counts must be positive.');
    }
    if (_itemCount < 1) {
      throw StateError('NATIVE_SELECTABLE_TEXT_ITEM_COUNT must be positive.');
    }
  }

  Future<NativeSelectableTextBenchmarkViewReadiness> _waitForReadyView() async {
    try {
      return await _waitLoop().timeout(
        _viewReadinessTimeout,
      );
    } on TimeoutException {
      final observation = _startupObservation;
      final diagnostic = observation?.diagnostic ?? 'no observation';
      throw TimeoutException(
        'The benchmark view was not ready after '
        '${_viewReadinessTimeout.inSeconds} seconds and '
        '$_startupReadinessFrameCount requested frame(s). '
        'Last observation: $diagnostic.',
        _viewReadinessTimeout,
      );
    }
  }

  Future<NativeSelectableTextBenchmarkViewReadiness> _waitLoop() async {
    while (mounted) {
      final observation = _readViewReadiness();
      _startupObservation = observation;
      if (observation.isReady) {
        return observation;
      }
      if (observation.lifecycleState != AppLifecycleState.resumed) {
        await _waitForStartupLifecycleChange();
        continue;
      }
      _startupReadinessFrameCount += 1;
      SchedulerBinding.instance.scheduleFrame();
      await SchedulerBinding.instance.endOfFrame;
    }
    throw StateError('The benchmark was disposed before its view was ready.');
  }

  Future<void> _waitForStartupLifecycleChange() async {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      return;
    }
    final changed = Completer<void>();
    _startupLifecycleChanged = changed;
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _startupLifecycleChanged = null;
      return;
    }
    try {
      await changed.future;
    } finally {
      if (identical(_startupLifecycleChanged, changed)) {
        _startupLifecycleChanged = null;
      }
    }
  }

  void _signalStartupLifecycleChanged() {
    final changed = _startupLifecycleChanged;
    if (changed == null || changed.isCompleted) return;
    changed.complete();
  }

  NativeSelectableTextBenchmarkViewReadiness _readViewReadiness() {
    final view = View.of(context);
    return NativeSelectableTextBenchmarkViewReadiness(
      lifecycleState: WidgetsBinding.instance.lifecycleState,
      logicalSize: MediaQuery.sizeOf(context),
      physicalSize: view.physicalSize,
      devicePixelRatio: view.devicePixelRatio,
      refreshRate: view.display.refreshRate,
    );
  }

  void _validateReadyView() {
    final readyView = _readyView;
    if (readyView == null || !readyView.isReady) {
      throw StateError(
        'The benchmark did not capture a resumed view with finite, '
        'positive metrics.',
      );
    }
  }

  Future<void> _prepareWorkload() async {
    await SchedulerBinding.instance.endOfFrame;
    if (_scenario.updatesScrollPosition) {
      if (!_scrollController.hasClients) {
        throw StateError('The scrolling workload has no scroll position.');
      }
      if (_scrollController.position.maxScrollExtent <= 0) {
        throw StateError(
          'The scrolling workload did not produce a scroll extent.',
        );
      }
      return;
    }
    if (!_scenario.opensMenu) {
      throw StateError('The selected workload does not open a menu.');
    }

    final editableTextState = _findEditableTextState();
    _editableTextState = editableTextState;
    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(
        selection: const TextSelection(baseOffset: 0, extentOffset: 12),
      ),
      SelectionChangedCause.longPress,
    );
    await SchedulerBinding.instance.endOfFrame;
    if (!editableTextState.showToolbar()) {
      throw StateError('The selection workload could not show its toolbar.');
    }
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(_menuPresentationSettleDuration);
    SchedulerBinding.instance.scheduleFrame();
    await SchedulerBinding.instance.endOfFrame;
    _requireNativeMenu('after the presentation settle interval');
  }

  EditableTextState _findEditableTextState() {
    final root = _selectionKey.currentContext;
    if (root == null) {
      throw StateError('The selection workload was not mounted.');
    }
    EditableTextState? result;
    void visit(Element element) {
      if (result != null) {
        return;
      }
      if (element is StatefulElement) {
        final state = element.state;
        if (state is EditableTextState) {
          result = state;
          return;
        }
      }
      element.visitChildElements(visit);
    }

    root.visitChildElements(visit);
    return result ?? (throw StateError('No EditableTextState was found.'));
  }

  Future<List<ui.FrameTiming>> _collectFrames(int targetFrames) async {
    if (!_isInteractive) {
      throw StateError('The benchmark view is not interactive.');
    }
    await _flushReportedTimings();
    if (_windowIsActive) {
      throw StateError('A benchmark frame window is already active.');
    }

    final started = Completer<void>();
    _windowFrames.clear();
    _windowTargetFrames = targetFrames;
    _windowStartMicros = null;
    _windowFramesReady = Completer<void>();
    _windowIsActive = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (!_windowIsActive) return;
      final scheduler = SchedulerBinding.instance;
      _windowStartMicros = scheduler.currentSystemFrameTimeStamp.inMicroseconds;
      _ticker.start();
      started.complete();
    });
    SchedulerBinding.instance.scheduleFrame();

    try {
      await started.future.timeout(_timingsTimeout);
      await _windowFramesReady!.future.timeout(_timingsTimeout);
      if (!_isInteractive) {
        throw StateError(
          'The benchmark lost lifecycle focus during a frame window.',
        );
      }
      return List<ui.FrameTiming>.of(_windowFrames, growable: false);
    } finally {
      _ticker.stop();
      _windowIsActive = false;
      _windowStartMicros = null;
      _windowTargetFrames = 0;
      _windowFramesReady = null;
    }
  }

  Future<List<ui.FrameTiming>> _collectGuardedFrames(
    int targetFrames, {
    required String window,
  }) async {
    _requireNativeMenu('before the $window');
    final frames = await _collectFrames(targetFrames);
    _requireNativeMenu('after the $window');
    return frames;
  }

  void _requireNativeMenu(String checkpoint) {
    if (_benchmarkWidget != _BenchmarkWidget.native || !_scenario.opensMenu) {
      return;
    }
    NativeSelectableTextBenchmarkMenuReadiness.inspect(
      context as Element,
    ).requireNativeMenu(checkpoint: checkpoint);
  }

  void _handleWorkloadTick(Duration _) {
    if (!_windowIsActive) return;
    if (_scenario.updatesScrollPosition) {
      _stepScrollWorkload();
    } else if (_scenario.updatesSelection) {
      _stepSelectionWorkload();
    }
    _workloadStep += 1;
  }

  void _stepScrollWorkload() {
    final position = _scrollController.position;
    const logicalPixelsPerFrame = 28.0;
    _scrollOffset += logicalPixelsPerFrame * _scrollDirection;
    if (_scrollOffset >= position.maxScrollExtent) {
      _scrollOffset = position.maxScrollExtent;
      _scrollDirection = -1;
    } else if (_scrollOffset <= position.minScrollExtent) {
      _scrollOffset = position.minScrollExtent;
      _scrollDirection = 1;
    }
    _scrollController.jumpTo(_scrollOffset);
  }

  void _stepSelectionWorkload() {
    final editableTextState = _editableTextState;
    final maximumExtent = _plainText.length - 1;
    final extent = 2 + (_workloadStep % (maximumExtent - 1));
    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(
        selection: TextSelection(baseOffset: 0, extentOffset: extent),
      ),
      SelectionChangedCause.drag,
    );
  }

  void _handleTimings(List<ui.FrameTiming> timings) {
    if (!_windowIsActive) return;
    final windowStart = _windowStartMicros;
    if (windowStart == null) return;
    for (final timing in timings) {
      final buildStart = timing.timestampInMicroseconds(
        ui.FramePhase.buildStart,
      );
      if (buildStart < windowStart) continue;
      if (_windowFrames.length >= _windowTargetFrames) break;
      _windowFrames.add(timing);
      if (_windowFrames.length == _windowTargetFrames) {
        final completer = _windowFramesReady;
        if (completer != null && !completer.isCompleted) {
          completer.complete();
        }
      }
    }
  }

  Future<void> _flushReportedTimings() async {
    SchedulerBinding.instance.scheduleFrame();
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 32));
  }

  void _printEnvironment() {
    final readyView = _readyView!;
    final refreshRate = readyView.refreshRate;
    final frameBudgetMicros = _frameBudgetMicros(refreshRate);
    var activeWidgetCount = 1;
    if (_scenario.updatesScrollPosition) {
      activeWidgetCount = _itemCount;
    }
    _print(<String, Object>{
      'path': 'environment',
      'run_id': _runId,
      'mode': 'profile',
      'platform': defaultTargetPlatform.name,
      'operating_system': Platform.operatingSystemVersion,
      'renderer': _rendererName,
      'renderer_source': 'manually verified startup or device logs',
      'scenario': _scenario.id,
      'widget': _benchmarkWidget.name,
      'text_case': _textCase.name,
      'text_code_units': _plainText.length,
      'inline_span_count': _richText?.children?.length ?? 1,
      'refresh_rate_hz': refreshRate,
      'frame_budget_us': frameBudgetMicros,
      'logical_size': <String, double>{
        'width': readyView.logicalSize.width,
        'height': readyView.logicalSize.height,
      },
      'physical_size': <String, double>{
        'width': readyView.physicalSize.width,
        'height': readyView.physicalSize.height,
      },
      'device_pixel_ratio': readyView.devicePixelRatio,
      'warmup_frames': _warmupFrameCount,
      'measured_frames': _measuredFrameCount,
      'trials': _trialCount,
      'configured_item_count': _itemCount,
      'active_widget_count': activeWidgetCount,
      'frame_budget_enforced': _enforceFrameBudget,
    });
  }

  void _printTrial(int trial, List<ui.FrameTiming> frames) {
    final refreshRate = _readyView!.refreshRate;
    final frameBudgetMicros = _frameBudgetMicros(refreshRate);
    final report = NativeSelectableTextBenchmarkFrameReport.fromFrames(
      frames: frames,
      frameBudgetMicros: frameBudgetMicros,
    );
    final path = 'trial.$trial';
    if (!report.workP99WithinBudget) {
      _failedTrialPaths.add(path);
    }
    _print(<String, Object>{
      'path': path,
      'run_id': _runId,
      'scenario': _scenario.id,
      'widget': _benchmarkWidget.name,
      'text_case': _textCase.name,
      'trial': trial,
      'valid': true,
      'gate': true,
      ...report.toJson(),
      'frame_budget_us': frameBudgetMicros,
    });
  }

  int _frameBudgetMicros(double refreshRate) {
    return (Duration.microsecondsPerSecond / refreshRate).floor();
  }

  void _print(Map<String, Object> record) {
    _recordBuffer.add(record);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: _buildWorkload(),
        ),
      ),
    );
  }

  Widget _buildWorkload() {
    if (_scenario.updatesScrollPosition) {
      return _buildScrollWorkload();
    }
    return _buildSelectionWorkload();
  }

  Widget _buildScrollWorkload() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _itemCount,
      itemExtent: 72,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _richText == null
              ? _buildSelectable(
                  text: 'Selectable row $index: $_plainText',
                )
              : _buildSelectable(
                  textSpan: TextSpan(
                    children: <TextSpan>[
                      TextSpan(text: 'Selectable row $index: '),
                      _richText,
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSelectionWorkload() {
    return Center(
      child: SizedBox(
        key: _selectionKey,
        width: 320,
        child: _buildSelectable(text: _plainText, textSpan: _richText),
      ),
    );
  }

  Widget _buildSelectable({String? text, TextSpan? textSpan}) {
    if (textSpan != null) {
      return switch (_benchmarkWidget) {
        _BenchmarkWidget.native => NativeSelectableText.rich(textSpan),
        _BenchmarkWidget.selectable => SelectableText.rich(
          textSpan,
          contextMenuBuilder: (_, _) => const SizedBox.shrink(),
        ),
      };
    }
    final plainText =
        text ??
        (throw StateError(
          'A benchmark text representation is required.',
        ));
    return switch (_benchmarkWidget) {
      _BenchmarkWidget.native => NativeSelectableText(plainText),
      _BenchmarkWidget.selectable => SelectableText(
        plainText,
        contextMenuBuilder: (_, _) => const SizedBox.shrink(),
      ),
    };
  }
}
