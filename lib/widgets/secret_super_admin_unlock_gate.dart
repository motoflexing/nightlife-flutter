import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class SecretSuperAdminUnlockGate extends StatefulWidget {
  const SecretSuperAdminUnlockGate({
    super.key,
    required this.child,
    required this.userKey,
    required this.venueKey,
    required this.onUnlock,
    this.enabled = true,
    this.holdDuration = const Duration(seconds: 3),
    this.onTrackingChanged,
    this.onHoldSatisfied,
  });

  final Widget child;
  final GlobalKey userKey;
  final GlobalKey venueKey;
  final VoidCallback onUnlock;
  final bool enabled;
  final Duration holdDuration;
  final ValueChanged<bool>? onTrackingChanged;
  final VoidCallback? onHoldSatisfied;

  @override
  State<SecretSuperAdminUnlockGate> createState() =>
      _SecretSuperAdminUnlockGateState();
}

class _SecretSuperAdminUnlockGateState
    extends State<SecretSuperAdminUnlockGate> {
  Timer? _holdTimer;
  Offset? _startPosition;
  Offset? _currentPosition;
  bool _tracking = false;
  bool _holdSatisfied = false;
  bool _unlockTriggered = false;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabled) return;
    final venueRect = _globalRectFor(widget.venueKey);
    if (venueRect == null || !venueRect.inflate(30).contains(event.position)) {
      return;
    }

    _reset(notify: false);
    setState(() {
      _tracking = true;
      _startPosition = event.position;
      _currentPosition = event.position;
    });
    widget.onTrackingChanged?.call(true);

    _holdTimer = Timer(widget.holdDuration, () {
      if (!mounted || !_tracking) return;
      setState(() => _holdSatisfied = true);
      widget.onHoldSatisfied?.call();
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_tracking) setState(() => _currentPosition = event.position);
    if (!_tracking || !_holdSatisfied || _unlockTriggered) return;

    final userRect = _globalRectFor(widget.userKey);
    if (userRect == null) return;

    if (userRect.inflate(80).contains(event.position)) {
      _unlockTriggered = true;
      widget.onUnlock();
      _reset();
    }
  }

  void _handlePointerEnd(PointerEvent event) => _reset();

  void _reset({bool notify = true}) {
    _holdTimer?.cancel();
    _tracking = false;
    _holdSatisfied = false;
    _unlockTriggered = false;
    _startPosition = null;
    _currentPosition = null;
    if (notify) widget.onTrackingChanged?.call(false);
    if (mounted) setState(() {});
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
      child: Stack(
        children: [
          widget.child,
          if (_tracking && _startPosition != null && _currentPosition != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _SecretGesturePainter(
                    start: _startPosition!,
                    current: _currentPosition!,
                    armed: _holdSatisfied,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SecretGesturePainter extends CustomPainter {
  const _SecretGesturePainter({
    required this.start,
    required this.current,
    required this.armed,
  });

  final Offset start;
  final Offset current;
  final bool armed;

  @override
  void paint(Canvas canvas, Size size) {
    final color = armed ? AppTheme.neonLime : AppTheme.accentPink;
    final pulsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = armed ? 2.2 : 1.4
      ..color = color.withValues(alpha: armed ? 0.72 : 0.42)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(start, armed ? 34 : 24, pulsePaint);

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(
        (start.dx + current.dx) / 2,
        math.min(start.dy, current.dy) - 38,
        current.dx,
        current.dy,
      );
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = armed ? 2.4 : 1.4
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          AppTheme.accentPink.withValues(alpha: 0.08),
          AppTheme.neonViolet.withValues(alpha: 0.72),
          AppTheme.neonLime.withValues(alpha: armed ? 0.85 : 0.12),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, linePaint);

    final nodePaint = Paint()
      ..color = color.withValues(alpha: 0.84)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(current, armed ? 7 : 5, nodePaint);
  }

  @override
  bool shouldRepaint(covariant _SecretGesturePainter oldDelegate) {
    return oldDelegate.start != start ||
        oldDelegate.current != current ||
        oldDelegate.armed != armed;
  }
}
