import 'package:flutter/material.dart';

import '../core/app_colors.dart';

class GlowBackground extends StatelessWidget {
  final Widget child;

  const GlowBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.of(context).background,
      child: CustomPaint(
        painter: _GlowPainter(
          AppColors.of(context).neon,
          Theme.of(context).brightness == Brightness.light,
        ),
        size: Size.infinite,
        child: child,
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  final Color accent;
  final bool light;
  _GlowPainter(this.accent, this.light);
  // No tema claro a decoração é suave para preservar o contraste dos valores.
  double get strength => light ? 0.12 : 1;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width;
    final h = size.height;

    // Brilho no canto superior esquerdo
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-1.1, -1.05),
          radius: 0.85,
          colors: [
            accent.withValues(alpha: 0.65 * strength),
            accent.withValues(alpha: 0.22 * strength),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rect),
    );

    // Curva da onda (parte de baixo)
    final wave = Path()
      ..moveTo(0, h * 0.80)
      ..cubicTo(w * 0.35, h * 0.84, w * 0.65, h * 0.80, w, h * 0.58);

    // Preenchimento abaixo da onda
    final fill = Path.from(wave)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            accent.withValues(alpha: 0.35 * strength),
            accent.withValues(alpha: 0.05 * strength),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect),
    );

    // Linha brilhante da onda
    canvas.drawPath(
      wave,
      Paint()
        ..color = accent.withValues(alpha: 0.5 * strength)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25),
    );
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.light != light;
}
