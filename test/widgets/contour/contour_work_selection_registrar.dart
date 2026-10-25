import 'package:flutter/rendering.dart';

/// Enables selection registration without changing the fixture's painted text.
class ContourWorkSelectionRegistrar implements SelectionRegistrar {
  final _selectables = <Selectable>{};

  @override
  void add(Selectable selectable) => _selectables.add(selectable);

  @override
  void remove(Selectable selectable) => _selectables.remove(selectable);
}
