import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Moldura com cantos amarelos e a linha de leitura, como no esboço.
class ScanFrame extends StatefulWidget {
  const ScanFrame({super.key, required this.size, this.animate = true});

  final double size;

  /// Falso para parar a linha (câmera parada ou animações desligadas).
  final bool animate;

  static const double _cornerLength = 28;
  static const double _cornerWidth = 4;
  static const double _linePadding = 12;

  @override
  State<ScanFrame> createState() => _ScanFrameState();
}

class _ScanFrameState extends State<ScanFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  bool _running = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ScanFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final shouldRun =
        widget.animate && !MediaQuery.disableAnimationsOf(context);
    if (shouldRun == _running) return;
    _running = shouldRun;
    if (shouldRun) {
      _animation.repeat(reverse: true);
    } else {
      _animation.value = 0.5;
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    const pad = ScanFrame._linePadding;
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CornersPainter(
                  color: AppColors.scanFrame,
                  length: ScanFrame._cornerLength,
                  strokeWidth: ScanFrame._cornerWidth,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) => Positioned(
                left: pad,
                right: pad,
                top: pad + (size - 2 * pad - 3) * _animation.value,
                child: const SizedBox(
                  height: 3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.scanLine,
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornersPainter extends CustomPainter {
  _CornersPainter({
    required this.color,
    required this.length,
    required this.strokeWidth,
  });

  final Color color;
  final double length;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final h = strokeWidth / 2;
    final w = size.width - h;
    final b = size.height - h;

    final path = Path()
      ..moveTo(h, h + length)
      ..lineTo(h, h)
      ..lineTo(h + length, h)
      ..moveTo(w - length, h)
      ..lineTo(w, h)
      ..lineTo(w, h + length)
      ..moveTo(w, b - length)
      ..lineTo(w, b)
      ..lineTo(w - length, b)
      ..moveTo(h + length, b)
      ..lineTo(h, b)
      ..lineTo(h, b - length);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornersPainter old) =>
      old.color != color ||
      old.length != length ||
      old.strokeWidth != strokeWidth;
}
