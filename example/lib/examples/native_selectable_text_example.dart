import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Shows native selection menus for plain and styled Flutter text.
class NativeSelectableTextExample extends StatelessWidget {
  /// Creates the native selectable text example.
  const NativeSelectableTextExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Long-press or right-click either sample to select it.'),
            SizedBox(height: 16),
            NativeSelectableText(
              'Plain text with emoji stays rendered by Flutter. 👋',
            ),
            Divider(height: 32),
            NativeSelectableText.rich(
              TextSpan(
                text: 'Styled text uses a ',
                children: [
                  TextSpan(
                    text: 'native selection menu',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ' when the platform supports one.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
