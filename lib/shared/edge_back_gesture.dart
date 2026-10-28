import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Adds back navigation only to drags that begin at the left screen edge.
class EdgeBackGesture extends StatefulWidget {
  const EdgeBackGesture({super.key, required this.onBack, required this.child});

  final AsyncCallback onBack;
  final Widget child;

  @override
  State<EdgeBackGesture> createState() => _EdgeBackGestureState();
}

class _EdgeBackGestureState extends State<EdgeBackGesture> {
  double _distance = 0;
  bool _handlingBack = false;

  bool _canStart(PointerDownEvent event) {
    if (_handlingBack) return false;
    final box = context.findRenderObject()! as RenderBox;
    final position = box.globalToLocal(event.position);
    return position.dx >= 0 &&
        position.dx <= 24 + MediaQuery.paddingOf(context).left;
  }

  void _onEnd(DragEndDetails details) {
    final width = (context.findRenderObject()! as RenderBox).size.width;
    final threshold = (width * .2).clamp(64.0, 120.0);
    final velocity = details.primaryVelocity ?? 0;
    final shouldBack =
        velocity >= 0 &&
        (_distance >= threshold || (_distance >= 24 && velocity >= 600));
    _distance = 0;
    if (shouldBack && !_handlingBack) unawaited(_back());
  }

  Future<void> _back() async {
    _handlingBack = true;
    try {
      await widget.onBack();
    } finally {
      _handlingBack = false;
    }
  }

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    behavior: HitTestBehavior.translucent,
    gestures: {
      _EdgeDragRecognizer:
          GestureRecognizerFactoryWithHandlers<_EdgeDragRecognizer>(
            () => _EdgeDragRecognizer(debugOwner: this),
            (recognizer) => recognizer
              ..canStart = _canStart
              ..dragStartBehavior = DragStartBehavior.down
              ..onStart = (_) {
                _distance = 0;
              }
              ..onUpdate = (details) {
                _distance += details.primaryDelta ?? 0;
              }
              ..onEnd = _onEnd
              ..onCancel = () => _distance = 0,
          ),
    },
    child: widget.child,
  );
}

class _EdgeDragRecognizer extends HorizontalDragGestureRecognizer {
  _EdgeDragRecognizer({super.debugOwner});

  late bool Function(PointerDownEvent) canStart;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      event is PointerDownEvent &&
      canStart(event) &&
      super.isPointerAllowed(event);
}
