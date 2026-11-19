import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../utils/formatters.dart';

class BalanceCard extends StatefulWidget {
  final int balanceCents;
  final String title;

  const BalanceCard({
    super.key,
    required this.balanceCents,
    this.title = 'Saldo atual',
  });

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  bool _isVisible = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 124),
      decoration: BoxDecoration(
        color: AppColors.of(context).fieldFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.of(context).outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Mantém o desenho atrás do texto e do botão.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _BalanceGlowPainter(
                  AppColors.of(context).neon,
                  Theme.of(context).brightness == Brightness.light,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: GoogleFonts.poppins(
                          color: AppColors.of(context).dashboardText,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _isVisible ? 'Ocultar saldo' : 'Mostrar saldo',
                      onPressed: () {
                        setState(() {
                          _isVisible = !_isVisible;
                        });
                      },
                      icon: Icon(
                        _isVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.of(context).textSecondary,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // Evita que o valor ultrapasse o card.
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _isVisible
                          ? formatCentsBRL(widget.balanceCents)
                          : 'R\$ ••••••',
                      style: GoogleFonts.poppins(
                        color: AppColors.of(context).dashboardText,
                        fontSize: 34,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Desenha uma aproximação do brilho verde da referência.
class _BalanceGlowPainter extends CustomPainter {
  final Color accent;
  final bool light;
  _BalanceGlowPainter(this.accent, this.light);
  // No tema claro a decoração é suave para preservar o contraste dos valores.
  double get strength => light ? 0.12 : 1;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;

    // Iluminação suave concentrada no canto inferior direito.
    final backgroundGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(1, 1),
        radius: 1.05,
        colors: [
          accent.withValues(alpha: 0.46 * strength),
          accent.withValues(alpha: 0.10 * strength),
          accent.withValues(alpha: 0),
        ],
        stops: const [0, 0.50, 1],
      ).createShader(bounds);

    canvas.drawRect(bounds, backgroundGlow);

    // A curva sobe na lateral direita do card.
    final wave = Path()
      ..moveTo(0, size.height)
      ..cubicTo(
        size.width * 0.28,
        size.height * 1.05,
        size.width * 0.46,
        size.height * 0.65,
        size.width * 0.66,
        size.height * 0.82,
      )
      ..cubicTo(
        size.width * 0.84,
        size.height * 0.98,
        size.width * 0.94,
        size.height * 0.65,
        size.width,
        size.height * 0.38,
      )
      ..lineTo(size.width, size.height)
      ..close();

    // Desenha uma luz difusa ao redor da onda.
    final waveGlow = Paint()
      ..color = accent.withValues(alpha: 0.42 * strength)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

    canvas.drawPath(wave, waveGlow);

    final waveFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          accent.withValues(alpha: 0.90 * strength),
          accent.withValues(alpha: 0.08 * strength),
        ],
      ).createShader(bounds);

    canvas.drawPath(wave, waveFill);
  }

  @override
  bool shouldRepaint(covariant _BalanceGlowPainter oldDelegate) {
    return oldDelegate.accent != accent || oldDelegate.light != light;
  }
}
