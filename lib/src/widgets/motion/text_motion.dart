part of 'motion.dart';

/// Applies one or more [MotionEffect]s to each visible character in [child].
///
/// [TextMotion] accepts a standard plain [Text] and preserves its supported
/// text configuration. Unicode grapheme clusters, such as emoji and combined
/// accents, animate as one character. Whitespace and invisible formatting
/// controls remain static paragraph spans rather than receiving effects.
///
/// Use [TextMotion.list] to apply multiple effects to every character.
/// Text motion also respects reduced-motion preferences and [TickerMode].
/// Every effect exposes the same visual operations used by [Motion].
///
/// ```dart
/// TextMotion(
///   effect: const MoveMotionEffect(
///     begin: Offset(0, 8),
///     end: Offset.zero,
///   ),
///   stagger: const Duration(milliseconds: 30),
///   child: const Text('Welcome'),
/// )
/// ```
///
/// Per-character rendering cannot retain cross-character shaping.
/// This widget is intended for short display text where losing ligatures,
/// kerning, contextual shaping, identical line wrapping, and text selection is
/// acceptable. Rich text created with [Text.rich] is not supported.
class TextMotion extends StatefulWidget {
  /// Creates text that applies one [effect] to each visible character.
  const TextMotion({
    required this.effect,
    required this.child,
    this.stagger = const Duration(milliseconds: 30),
    this.interactive = false,
    super.key,
  }) : effects = null;

  /// Creates text that applies [effects] to each visible character.
  ///
  /// Each effect keeps its own delay, duration, curve, playback, and lifecycle
  /// callbacks. The first effect is applied first and each following effect
  /// composes around the result. The list must contain at least one effect and
  /// must not be mutated after being passed to this constructor.
  const TextMotion.list({
    required this.effects,
    required this.child,
    this.stagger = const Duration(milliseconds: 30),
    this.interactive = false,
    super.key,
  }) : effect = null;

  /// Single effect supplied to the default constructor.
  ///
  /// This is null when the widget was created with [TextMotion.list].
  final MotionEffect? effect;

  /// Effects supplied to the multi-effect constructor.
  ///
  /// This is null when the widget was created with the default constructor.
  final List<MotionEffect>? effects;

  /// Delay between the start of neighboring visible characters.
  ///
  /// This defaults to 30 milliseconds and must not be negative. For one-shot
  /// effects, the complete duration is the effect duration plus one stagger
  /// for every visible character after the first. For looping effects,
  /// [stagger] offsets character phases without changing the effect's cycle
  /// duration.
  final Duration stagger;

  /// Whether the rendered text accepts pointer interaction during playback.
  ///
  /// This has the same lifecycle behavior as [Motion.interactive].
  final bool interactive;

  /// Plain Flutter text whose visible characters receive the effects.
  ///
  /// The text must be created with [Text.new]. [Text.rich] is not supported.
  final Text child;

  @override
  State<TextMotion> createState() => _TextMotionState();
}

class _TextMotionState extends State<TextMotion> {
  late _TextMotionTransition _transition;
  late List<_TextMotionEffect> _adaptedEffects;

  @override
  void initState() {
    super.initState();
    _validateInput();
    _transition = _TextMotionTransition.initial(widget.child);
    _adaptedEffects = _createAdaptedEffects();
  }

  @override
  void didUpdateWidget(covariant TextMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    _validateInput();
    final oldCharacterCount = _transition.animatedCharacterCount;
    if (oldWidget.child.data != widget.child.data) {
      _transition = _TextMotionTransition.initial(widget.child);
    } else if (!identical(oldWidget.child, widget.child)) {
      _transition = _transition.withText(widget.child);
    }
    final effectsChanged =
        !identical(oldWidget.effect, widget.effect) ||
        !identical(oldWidget.effects, widget.effects) ||
        oldWidget.stagger != widget.stagger ||
        oldCharacterCount != _transition.animatedCharacterCount;
    if (effectsChanged) {
      _adaptedEffects = _createAdaptedEffects();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_transition.animatedCharacterCount == 0) {
      return widget.child;
    }
    return _MotionAnimationHost(
      controller: null,
      effects: _adaptedEffects,
      interactive: widget.interactive,
      transitionBuilder: _buildTransition,
    );
  }

  void _validateInput() {
    if (widget.stagger.isNegative) {
      throw ArgumentError.value(
        widget.stagger,
        'stagger',
        'must not be negative',
      );
    }
    if (widget.child.data == null) {
      throw ArgumentError.value(
        widget.child,
        'child',
        'must be created with Text.new; Text.rich is not supported',
      );
    }
    if (widget.effect == null && widget.effects == null) {
      throw ArgumentError(
        'TextMotion requires an effect or a list of effects.',
      );
    }
    _MotionEffectValidator.validateAll(
      widget.effect == null ? widget.effects! : <MotionEffect>[widget.effect!],
    );
  }

  Widget _buildTransition(List<_MotionApplication> applications) {
    return _transition.withApplications(
      List<_TextMotionApplication>.generate(
        applications.length,
        (index) {
          final application = applications[index];
          final effect = application.effect as _TextMotionEffect;
          return (
            animation: application.animation,
            effect: effect.effect,
            stagger: effect.stagger,
            timelineDuration: effect.duration,
          );
        },
        growable: false,
      ),
    );
  }

  List<_TextMotionEffect> _createAdaptedEffects() {
    final effect = widget.effect;
    if (effect != null) {
      return <_TextMotionEffect>[
        _TextMotionEffect(
          effect: effect,
          stagger: widget.stagger,
          characterCount: _transition.animatedCharacterCount,
        ),
      ];
    }

    return widget.effects!
        .map(
          (effect) => _TextMotionEffect(
            effect: effect,
            stagger: widget.stagger,
            characterCount: _transition.animatedCharacterCount,
          ),
        )
        .toList(growable: false);
  }
}
