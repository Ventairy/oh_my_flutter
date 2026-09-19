part of 'morph.dart';

final class _MorphTagStatusListenable extends ChangeNotifier implements ValueListenable<MorphTagStatus> {
  new(this.observer, this.tag) : _lastValue = observer._tagStatusValue(tag);

  final MorphNavigatorObserver observer;
  final Object tag;
  MorphTagStatus _lastValue;

  @override
  MorphTagStatus get value => observer._tagStatusValue(tag);

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    observer._subscribedTagStatuses.add(this);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) observer._subscribedTagStatuses.remove(this);
  }

  void update() {
    final next = value;
    if (next == _lastValue) return;
    _lastValue = next;
    notifyListeners();
  }
}
