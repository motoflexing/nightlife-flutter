import 'dart:async';

import 'package:flutter/material.dart';

class SecretSuperAdminUnlockGate extends StatefulWidget {
  const SecretSuperAdminUnlockGate({
    super.key,
    required this.child,
    required this.userKey,
    required this.venueKey,
    required this.onUnlock,
    this.enabled = true,
    this.holdDuration = const Duration(milliseconds: 1500),
  });

  final Widget child;
  final GlobalKey userKey;
  final GlobalKey venueKey;
  final VoidCallback onUnlock;
  final bool enabled;
  final Duration holdDuration;

  @override
  State<SecretSuperAdminUnlockGate> createState() =>
      _SecretSuperAdminUnlockGateState();
}

class _SecretSuperAdminUnlockGateState
    extends State<SecretSuperAdminUnlockGate> {
  Timer? _holdTimer;
  Offset? _startPosition;
  bool _tracking = false;
  bool _holdSatisfied = false;
  bool _draggedTowardUser = false;
  bool _unlockedForPointer = false;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabled) return;
    final venueRect = _globalRectFor(widget.venueKey);
    if (venueRect == null || !venueRect.contains(event.position)) return;

    _holdTimer?.cancel();
    _startPosition = event.position;
    _tracking = true;
    _holdSatisfied = false;
    _draggedTowardUser = false;
    _unlockedForPointer = false;
    _holdTimer = Timer(widget.holdDuration, () {
      if (mounted && _tracking) {
        _holdSatisfied = true;
      }
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_tracking || !_holdSatisfied || _unlockedForPointer) return;

    final start = _startPosition;
    final userRect = _globalRectFor(widget.userKey);
    final venueRect = _globalRectFor(widget.venueKey);
    if (start == null || userRect == null || venueRect == null) return;

    final horizontalTravel = start.dx - event.position.dx;
    final verticalDrift = (event.position.dy - start.dy).abs();
    final dragFloor = venueRect.width * 0.45;
    final allowedDrift = venueRect.height * 1.45;
    final targetRect = userRect.inflate(userRect.width * 0.18);

    _draggedTowardUser =
        horizontalTravel >= dragFloor && verticalDrift <= allowedDrift;

    if (_draggedTowardUser && targetRect.contains(event.position)) {
      _unlockedForPointer = true;
      widget.onUnlock();
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    _holdTimer?.cancel();
    _tracking = false;
    _holdSatisfied = false;
    _draggedTowardUser = false;
    _unlockedForPointer = false;
    _startPosition = null;
  }

  Rect? _globalRectFor(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerEnd,
      child: widget.child,
    );
  }
}
