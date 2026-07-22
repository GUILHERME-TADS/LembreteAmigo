import 'package:flutter/material.dart';

class GoogleLogoPainter extends CustomPainter {
  const GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    final double sx = width / 24.0;
    final double sy = height / 24.0;

    canvas.scale(sx, sy);

    // Blue section (#4285F4)
    final Path bluePath = Path()
      ..moveTo(23.745, 12.27)
      ..cubicTo(23.745, 11.46, 23.675, 10.68, 23.54, 9.92)
      ..lineTo(12, 9.92)
      ..lineTo(12, 14.63)
      ..lineTo(18.58, 14.63)
      ..cubicTo(18.3, 16.14, 17.44, 17.42, 16.15, 18.28)
      ..lineTo(16.15, 21.32)
      ..lineTo(20.08, 21.32)
      ..cubicTo(22.38, 19.2, 23.745, 16.03, 23.745, 12.27);
    canvas.drawPath(bluePath, Paint()..color = const Color(0xFF4285F4));

    // Green section (#34A853)
    final Path greenPath = Path()
      ..moveTo(12, 24)
      ..cubicTo(15.24, 24, 17.96, 22.92, 19.98, 21.06)
      ..lineTo(16.15, 18.09)
      ..cubicTo(15.08, 18.81, 13.67, 19.26, 12, 19.26)
      ..cubicTo(8.87, 19.26, 6.22, 17.15, 5.27, 14.29)
      ..lineTo(1.24, 14.29)
      ..lineTo(1.24, 17.41)
      ..cubicTo(3.26, 21.42, 7.37, 24, 12, 24);
    canvas.drawPath(greenPath, Paint()..color = const Color(0xFF34A853));

    // Yellow section (#FBBC05)
    final Path yellowPath = Path()
      ..moveTo(5.27, 14.29)
      ..cubicTo(5.03, 13.57, 4.89, 12.8, 4.89, 12)
      ..cubicTo(4.89, 11.2, 5.03, 10.43, 5.27, 9.71)
      ..lineTo(5.27, 6.59)
      ..lineTo(1.24, 6.59)
      ..cubicTo(0.45, 8.16, 0, 9.94, 0, 12)
      ..cubicTo(0, 14.06, 0.45, 15.84, 1.24, 17.41)
      ..lineTo(5.27, 14.29);
    canvas.drawPath(yellowPath, Paint()..color = const Color(0xFFFBBC05));

    // Red section (#EA4335)
    final Path redPath = Path()
      ..moveTo(12, 4.75)
      ..cubicTo(13.76, 4.75, 15.34, 5.36, 16.59, 6.55)
      ..lineTo(20.07, 3.07)
      ..cubicTo(17.95, 1.1, 15.24, 0, 12, 0)
      ..cubicTo(7.37, 0, 3.26, 2.58, 1.24, 6.59)
      ..lineTo(5.27, 9.71)
      ..cubicTo(6.22, 6.85, 8.87, 4.75, 12, 4.75);
    canvas.drawPath(redPath, Paint()..color = const Color(0xFFEA4335));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GoogleLogoWidget extends StatelessWidget {
  final double size;

  const GoogleLogoWidget({super.key, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(
        painter: GoogleLogoPainter(),
      ),
    );
  }
}

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final double height;
  final double fontSize;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.label = 'Entrar com Google',
    this.height = 56.0,
    this.fontSize = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F1F1F),
          side: const BorderSide(color: Color(0xFF747775), width: 1.5),
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GoogleLogoWidget(size: fontSize + 6),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F1F1F),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
