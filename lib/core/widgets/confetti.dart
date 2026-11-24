import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Fires a one-shot confetti burst over the current screen.
/// Pure CustomPainter — no dependencies, no state kept afterwards.
void showConfetti(BuildContext context) {
  if (MediaQuery.disableAnimationsOf(context)) return;

  final monochrome = context.appStyle.isDigital;
  final overlay = OverlayEntry(
    builder: (_) => _ConfettiView(monochrome: monochrome),
  );
  Overlay.of(context, rootOverlay: true).insert(overlay);
  Future.delayed(const Duration(milliseconds: 2400), () {
    if (overlay.mounted) overlay.remove();
  });
}

class _ConfettiView extends StatefulWidget {
  const _ConfettiView({required this.monochrome});

  final bool monochrome;

  @override
  State<_ConfettiView> createState() => _ConfettiViewState();
}

class _ConfettiViewState extends State<_ConfettiView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Piece> _pieces;

  static const _colors = [
    Color(0xFF22C55E),
    Color(0xFF1B6CFF),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
  ];

  static const _monoColors = [
    Color(0xFFFFFFFF),
    Color(0xFFC9C9D2),
    Color(0xFF9A9AA5),
    Color(0xFF6C6C76),
    Color(0xFFF5F5F7),
  ];

  @override
  void initState() {
    super.initState();
    final random = Random();
    final palette = widget.monochrome ? _monoColors : _colors;
    _pieces = List.generate(80, (_) {
      return _Piece(
        angle: random.nextDouble() * 2 * pi,
        speed: 140 + random.nextDouble() * 340,
        size: 5 + random.nextDouble() * 7,
        spin: (random.nextDouble() * 8 - 4) * 2 * pi,
        color: palette[random.nextInt(palette.length)],
        circle: random.nextBool(),
      );
    });
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: MediaQuery.sizeOf(context),
            painter: _ConfettiPainter(
              pieces: _pieces,
              progress: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.angle,
    required this.speed,
    required this.size,
    required this.spin,
    required this.color,
    required this.circle,
  });

  final double angle;
  final double speed;
  final double size;
  final double spin;
  final Color color;
  final bool circle;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.pieces, required this.progress});

  final List<_Piece> pieces;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.32);
    const gravity = 1500.0;
    final seconds = progress * 2.2;

    final opacity = progress < 0.65
        ? 1.0
        : (1 - (progress - 0.65) / 0.35).clamp(0.0, 1.0);

    for (final piece in pieces) {
      final vx = cos(piece.angle) * piece.speed;
      final vy = sin(piece.angle) * piece.speed * 0.6 - 420;
      final x = origin.dx + vx * seconds;
      final y = origin.dy + vy * seconds + 0.5 * gravity * seconds * seconds;
      if (y > size.height + 24 || x < -24 || x > size.width + 24) continue;

      final paint = Paint()..color = piece.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(piece.spin * progress);
      if (piece.circle) {
        canvas.drawCircle(Offset.zero, piece.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: piece.size,
            height: piece.size * 0.6,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}