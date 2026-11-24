import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// The four board drawings that sit in the home-screen colour blocks. They are
/// painted rather than bundled so they stay sharp at any size.
class GameIcon extends StatelessWidget {
  const GameIcon(this.game, {this.size = 48, super.key});

  final String game;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (game == 'merge') {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Palette.card,
          border: Border.all(color: Palette.ink, width: 2),
        ),
        child: Text(
          '2 + 2',
          style: AppType.serif(14, height: 1).copyWith(letterSpacing: 0),
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GameIconPainter(game)),
    );
  }
}

class _GameIconPainter extends CustomPainter {
  _GameIconPainter(this.game);

  final String game;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 48;
    canvas.save();
    canvas.scale(scale);

    final ink = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final hair = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final white = Paint()..color = Palette.card;

    final board = RRect.fromRectAndRadius(
      const Rect.fromLTWH(5, 5, 38, 38),
      Radius.zero,
    );
    canvas.drawRRect(board, white);
    canvas.drawRRect(board, ink);

    switch (game) {
      case 'zip':
        for (final x in [17.7, 30.3]) {
          canvas.drawLine(Offset(x, 5), Offset(x, 43), hair);
        }
        for (final y in [17.7, 30.3]) {
          canvas.drawLine(Offset(5, y), Offset(43, y), hair);
        }
        final path = Path()
          ..moveTo(11.3, 36.7)
          ..lineTo(11.3, 24)
          ..lineTo(24, 24)
          ..lineTo(24, 11.3)
          ..lineTo(36.7, 11.3)
          ..lineTo(36.7, 36.7);
        canvas.drawPath(
          path,
          Paint()
            ..color = Palette.ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round,
        );
        final dot = Paint()..color = Palette.ink;
        canvas.drawCircle(const Offset(11.3, 36.7), 4.6, dot);
        canvas.drawCircle(const Offset(36.7, 36.7), 4.6, dot);
      case 'tango':
        canvas.drawLine(const Offset(24, 5), const Offset(24, 43), hair);
        canvas.drawLine(const Offset(5, 24), const Offset(43, 24), hair);
        _sun(canvas, const Offset(14.5, 14.5), 4, 1.8);
        _moon(canvas, const Offset(33.5, 33.5), 4.6);
        _sun(canvas, const Offset(38.2, 16.2), 3.4, 1.2);
        _moon(canvas, const Offset(12.8, 35.2), 3.4);
      case 'sudoku':
        for (final x in [17.7, 30.3]) {
          canvas.drawLine(Offset(x, 5), Offset(x, 43), hair);
        }
        for (final y in [17.7, 30.3]) {
          canvas.drawLine(Offset(5, y), Offset(43, y), hair);
        }
        _digit(canvas, '4', const Offset(11.3, 15));
        _digit(canvas, '1', const Offset(36.7, 15));
        _digit(canvas, '6', const Offset(24, 27.6));
        _digit(canvas, '2', const Offset(11.3, 40.2));
        _digit(canvas, '5', const Offset(36.7, 40.2));
    }

    canvas.restore();
  }

  void _sun(Canvas canvas, Offset center, double radius, double rayWidth) {
    final fill = Paint()..color = Palette.ink;
    if (radius > 0) {
      canvas.drawCircle(center, radius, fill);
      if (rayWidth > 0) {
        final rays = Paint()
          ..color = Palette.ink
          ..strokeWidth = rayWidth
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 4; i++) {
          final angle = i * math.pi / 2;
          final from = center + Offset(math.cos(angle), math.sin(angle)) * 7;
          final to = center + Offset(math.cos(angle), math.sin(angle)) * 8.6;
          canvas.drawLine(from, to, rays);
        }
      }
    }
  }

  void _moon(Canvas canvas, Offset center, double radius) {
    final outer = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    final cut = Path()
      ..addOval(
        Rect.fromCircle(center: center + const Offset(-3.2, -3.2), radius: radius),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, outer, cut),
      Paint()..color = Palette.ink,
    );
  }

  void _digit(Canvas canvas, String text, Offset center) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: AppType.serif(10, height: 1).copyWith(color: Palette.ink),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _GameIconPainter oldDelegate) =>
      oldDelegate.game != game;
}
