# Motion effects

- Always apply effects to the current visual state. On each frame, evaluate
  effects in declaration order and operations within an effect in call order.
  When a delayed effect starts, apply it to the visual state produced by the
  preceding operations on that frame.
- When disintegration starts, break apart the current appearance.
