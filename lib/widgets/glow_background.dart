import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class GlowBackground extends StatelessWidget {
  final Widget child;

  const GlowBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: CustomPaint(
        painter: _GlowPainter(),
        size: Size.infinite,
        child: child,
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
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
            AppColors.neon.withOpacity(0.65),
            AppColors.neon.withOpacity(0.22),
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
            AppColors.neon.withOpacity(0.35),
            AppColors.neon.withOpacity(0.05),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect),
    );

    // Linha brilhante da onda
    canvas.drawPath(
      wave,
      Paint()
        ..color = AppColors.neon.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}