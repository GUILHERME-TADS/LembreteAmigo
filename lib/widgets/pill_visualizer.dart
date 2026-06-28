import 'dart:io';
import 'package:flutter/material.dart';

class PillVisualizer extends StatelessWidget {
  final String? forma;
  final String? cor;
  final double size;
  final String? fotoPath;

  const PillVisualizer({
    super.key,
    required this.forma,
    required this.cor,
    this.size = 64.0,
    this.fotoPath,
  });

  Color _getColor() {
    switch (cor) {
      case 'vermelho':
        return const Color(0xFFE57373);
      case 'azul':
        return const Color(0xFF64B5F6);
      case 'verde':
        return const Color(0xFF81C784);
      case 'amarelo':
        return const Color(0xFFFFD54F);
      case 'branco':
        return const Color(0xFFEEEEEE);
      default:
        return const Color(0xFFB0BEC5); // cinza/default
    }
  }

  @override
  Widget build(BuildContext context) {
    if (fotoPath != null && fotoPath!.isNotEmpty) {
      final isAsset = fotoPath!.startsWith('assets/') || fotoPath!.startsWith('images/');
      return ClipRRect(
        borderRadius: BorderRadius.circular(size),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black26, width: 2),
          ),
          child: ClipOval(
            child: isAsset
                ? Image.asset(
                    fotoPath!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                  )
                : Image.file(
                    File(fotoPath!),
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildGeometricVisualizer();
                    },
                  ),
          ),
        ),
      );
    }
    return _buildGeometricVisualizer();
  }

  Widget _buildGeometricVisualizer() {
    final pillColor = _getColor();

    switch (forma) {
      case 'capsula':
        return Container(
          width: size * 0.9,
          height: size * 0.55,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size),
            border: Border.all(color: Colors.black26, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(size),
                      bottomLeft: Radius.circular(size),
                    ),
                    color: pillColor,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(size),
                      bottomRight: Radius.circular(size),
                    ),
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );

      case 'comprimido':
        return Container(
          width: size * 0.8,
          height: size * 0.8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: pillColor,
            border: Border.all(color: Colors.black26, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: size * 0.8,
              height: 2,
              color: Colors.black12,
            ),
          ),
        );

      case 'gotas':
        return Icon(
          Icons.water_drop,
          size: size,
          color: pillColor,
          shadows: const [
            Shadow(
              color: Colors.black12,
              offset: Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        );

      case 'pomada':
        return Icon(
          Icons.healing,
          size: size * 0.9,
          color: pillColor,
          shadows: const [
            Shadow(
              color: Colors.black12,
              offset: Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        );

      default:
        return Icon(
          Icons.medical_services,
          size: size * 0.8,
          color: pillColor,
        );
    }
  }
}
