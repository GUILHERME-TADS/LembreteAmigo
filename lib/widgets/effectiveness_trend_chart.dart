import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../models/effectiveness_metrics.dart';

class EffectivenessTrendChart extends StatelessWidget {
  final List<DailyEffectiveness> dailyTrend;

  const EffectivenessTrendChart({super.key, required this.dailyTrend});

  @override
  Widget build(BuildContext context) {
    final validDays = dailyTrend.where((d) => d.score >= 0).toList();
    if (validDays.isEmpty) {
      return Center(
        child: Text(
          'Sem dados suficientes',
          style: TextStyle(color: AppColors.outline),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: CustomPaint(
        size: Size.infinite,
        painter: _TrendPainter(validDays: validDays),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<DailyEffectiveness> validDays;

  _TrendPainter({required this.validDays});

  @override
  void paint(Canvas canvas, Size size) {
    if (validDays.isEmpty) return;

    final maxScore = 100.0;
    final stepX =
        size.width / (validDays.length - 1).clamp(1, validDays.length);
    final padding = 20.0;
    final chartHeight = size.height - padding * 2;

    final points = <Offset>[];
    for (int i = 0; i < validDays.length; i++) {
      final x = padding + i * stepX;
      final y =
          padding + chartHeight - (validDays[i].score / maxScore) * chartHeight;
      points.add(
        Offset(
          x.clamp(padding, size.width - padding),
          y.clamp(padding, size.height - padding),
        ),
      );
    }

    final linePaint = Paint()
      ..color = AppColors.info
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.info.withValues(alpha: 0.3),
          AppColors.info.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    if (points.isEmpty) return;
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, linePaint);

    final fillPath = Path.from(path);
    fillPath.lineTo(points.last.dx, padding + chartHeight);
    fillPath.lineTo(points.first.dx, padding + chartHeight);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    for (final point in points) {
      canvas.drawCircle(point, 3, Paint()..color = AppColors.info);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.validDays != validDays;
}
