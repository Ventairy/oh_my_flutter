part of 'sequence.dart';

/// Controls and observes the selected child of a [Sequence].
///
/// A controller can be attached to one sequence at a time. Navigation methods
/// throw a [StateError] before attachment and after detachment.
class SequenceController extends ChangeNotifier {
  /// Creates a sequence controller whose initial [index] is `0`.
  SequenceController();

  Object? _owner;
  VoidCallback? _onNext;
  VoidCallback? _onPrevious;
  void Function(int index)? _onGoTo;
  int _index = 0;

  /// Index selected by the attached [Sequence].
  ///
  /// Listeners are notified when navigation starts and changes this value.
  int get index => _index;

  /// Selects the next child, or does nothing at the end of the sequence.
  void next() => _requireAttached(_onNext).call();

  /// Selects the previous child, or does nothing at the start of the sequence.
  void previous() => _requireAttached(_onPrevious).call();

  /// Selects the child at [index].
  ///
  /// The attached sequence throws a [RangeError] when [index] is outside its
  /// children. Selecting the current index does nothing.
  void goTo(int index) => _requireAttached(_onGoTo).call(index);

  T _requireAttached<T extends Function>(T? callback) {
    if (callback == null) {
      throw StateError('SequenceController is not attached to a Sequence.');
    }
    return callback;
  }

  void _attach({
    required Object owner,
    required int index,
    required VoidCallback onNext,
    required VoidCallback onPrevious,
    required void Function(int index) onGoTo,
  }) {
    if (_owner != null) {
      throw StateError(
        'SequenceController is already attached to a Sequence.',
      );
    }

    _owner = owner;
    _onNext = onNext;
    _onPrevious = onPrevious;
    _onGoTo = onGoTo;
    _setIndex(index);
  }

  void _detach(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _onNext = null;
    _onPrevious = null;
    _onGoTo = null;
  }

  void _setIndex(int index) {
    if (_index == index) return;
    _index = index;
    notifyListeners();
  }

  @override
  void dispose() {
    _owner = null;
    _onNext = null;
    _onPrevious = null;
    _onGoTo = null;
    super.dispose();
  }
}
