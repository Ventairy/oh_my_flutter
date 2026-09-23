part of 'morph.dart';

final class _MorphTargetStatusListenable extends ChangeNotifier implements ValueListenable<MorphTagStatus> {
  new(this.target);

  final MorphTarget target;
  WeakReference<MorphNavigatorObserver>? _observer;
  MorphTagStatus _lastValue = MorphTagStatus.idle;

  @override
  MorphTagStatus get value => _observer?.target?._tagStatusValue(target) ?? _lastValue;

  void update(MorphNavigatorObserver observer) {
    if (!identical(_observer?.target, observer)) return;
    final next = value;
    if (next == _lastValue) return;
    _lastValue = next;
    notifyListeners();
  }
}
