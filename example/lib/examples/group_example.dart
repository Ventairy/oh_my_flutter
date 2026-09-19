// dart format width=80
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Measures and captures separately positioned pieces of a card.
class GroupExample extends StatefulWidget {
  /// Creates the Group example.
  const new({super.key});

  @override
  State<GroupExample> createState() => _GroupExampleState();
}

class _GroupExampleState extends State<GroupExample> {
  final _link = GroupLink();
  final GlobalKey _reference = GlobalKey();
  ui.Image? _image;
  String _measurement = 'Capture the card and badge together.';
  bool _capturing = false;

  Future<void> _capture() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    final context = _reference.currentContext!;
    final bounds = _link.measure(relativeTo: context);
    final snapshot = await _link.capture(relativeTo: context);
    ui.Image? image;
    try {
      image = await snapshot?.toImage();
    } finally {
      snapshot?.dispose();
    }
    if (!mounted) {
      image?.dispose();
      return;
    }
    final previous = _image;
    setState(() {
      _image = image;
      _capturing = false;
      _measurement = image == null
          ? 'Capture unavailable.'
          : '${bounds!.width.round()} × ${bounds.height.round()} '
                'logical pixels';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => previous?.dispose());
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        key: _reference,
        width: 240,
        height: 130,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 20,
              width: 220,
              height: 110,
              child: Group(
                link: _link,
                child: const ColoredBox(
                  color: Color(0xffe8f1ff),
                  child: Center(child: Text('Card')),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Group(
                link: _link,
                zIndex: 1,
                child: const Chip(label: Text('Attached badge')),
              ),
            ),
          ],
        ),
      ),
      TextButton(
        onPressed: _capturing ? null : _capture,
        child: const Text('Capture group'),
      ),
      Text(_measurement),
      if (_image != null)
        RawImage(image: _image, width: 240, height: 130, fit: BoxFit.contain),
    ],
  );
}
