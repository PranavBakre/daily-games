import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

/// A drag surface that wins the gesture arena immediately, so a board inside a
/// scrolling screen never hands its gesture to the scroll view. Taps arrive as
/// a drag with no movement.
class DragSurface extends StatelessWidget {
  const DragSurface({
    required this.child,
    this.onStart,
    this.onUpdate,
    this.onEnd,
    this.onCancel,
    super.key,
  });

  final Widget child;
  final void Function(DragStartDetails details)? onStart;
  final void Function(DragUpdateDetails details)? onUpdate;
  final void Function()? onEnd;
  final void Function()? onCancel;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        _EagerPanRecognizer:
            GestureRecognizerFactoryWithHandlers<_EagerPanRecognizer>(
              _EagerPanRecognizer.new,
              (recognizer) {
                recognizer.onStart = onStart;
                recognizer.onUpdate = onUpdate;
                recognizer.onEnd = (_) {
                  onEnd?.call();
                };
                recognizer.onCancel = onCancel ?? () {};
              },
            ),
      },
      child: child,
    );
  }
}

class _EagerPanRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
