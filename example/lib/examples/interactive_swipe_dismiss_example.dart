import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Shows a route with surface and handle-driven interactive dismissal.
class InteractiveSwipeDismissExample extends StatelessWidget {
  /// Creates the interactive swipe dismissal example.
  const InteractiveSwipeDismissExample({super.key});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const _DismissibleExampleRoute(),
          ),
        );
      },
      child: const Text('Open dismissible route'),
    );
  }
}

class _DismissibleExampleRoute extends StatelessWidget {
  const _DismissibleExampleRoute();

  @override
  Widget build(BuildContext context) {
    return InteractiveSwipeDismiss(
      onDismiss: () => Navigator.maybePop(context),
      child: Scaffold(
        body: Column(
          children: [
            InteractiveSwipeDismissHandle(
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 64,
                  child: Center(
                    child: Text(
                      'Drag anywhere in this header',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
              ),
            ),
            const Expanded(
              child: Center(
                child: Text('The surface and its header are interactive.'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
