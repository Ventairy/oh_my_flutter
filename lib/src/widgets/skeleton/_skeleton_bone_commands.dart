part of 'skeleton.dart';

class _SkeletonBoneCommands {
  List<_SkeletonBoneCommand> _commands = <_SkeletonBoneCommand>[];
  bool _hasBones = false;

  bool get isEmpty => _commands.isEmpty;
  bool get hasBones => _hasBones;
  int get length => _commands.length;

  void add(_SkeletonBoneCommand command) => _commands.add(command);

  void addBone(_SkeletonBoneCommand command) {
    _commands.add(command);
    _hasBones = true;
  }

  void clear() {
    // Discard the backing store as well as its elements. A large skeleton can
    // otherwise leave every retained segment holding its peak command-buffer
    // capacity after the built-in picture has been compiled.
    _commands = <_SkeletonBoneCommand>[];
    _hasBones = false;
  }

  void replay(Canvas canvas, Paint paint) {
    for (final command in _commands) {
      command.replay(canvas, paint);
    }
  }
}
