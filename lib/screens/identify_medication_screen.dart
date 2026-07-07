import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/medication_identifier_service.dart';

class IdentifyMedicationScreen extends StatefulWidget {
  const IdentifyMedicationScreen({super.key});

  @override
  State<IdentifyMedicationScreen> createState() =>
      _IdentifyMedicationScreenState();
}

class _IdentifyMedicationScreenState
    extends State<IdentifyMedicationScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  String? _fotoPath;
  bool _isProcessing = false;
  MedicationIdentifierResult? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Identificar Remédio'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tire uma foto do comprimido ou da embalagem.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'A inteligência artificial vai identificar o medicamento automaticamente.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Center(
                child: _fotoPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(_fotoPath!),
                          height: 300,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image, size: 64),
                        ),
                      )
                    : GestureDetector(
                        onTap: _tirarFoto,
                        child: Container(
                          height: 300,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.outlineVariant,
                              width: 2,
                            ),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt,
                                size: 80,
                                color: AppColors.primary,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'TIRAR FOTO',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            if (_result != null) _buildResultCard(),
            const SizedBox(height: 24),
            SizedBox(
              height: 64,
              child: ElevatedButton(
                onPressed:
                    _fotoPath != null && !_isProcessing ? _identificar : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isProcessing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Analisando imagem...',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _result != null
                            ? 'TIRAR NOVA FOTO'
                            : 'IDENTIFICAR REMÉDIO',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            if (_result != null && _result!.success) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 64,
                child: ElevatedButton.icon(
                  onPressed: _confirmarResultado,
                  icon: const Icon(Icons.check_circle, size: 28),
                  label: const Text(
                    'CONFIRMAR E CRIAR LEMBRETE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _tirarFoto() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (image != null && mounted) {
        setState(() {
          _fotoPath = image.path;
          _result = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao tirar foto: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _identificar() async {
    if (_fotoPath == null) return;

    setState(() => _isProcessing = true);

    try {
      final bytes = await File(_fotoPath!).readAsBytes();
      final base64Image = base64Encode(bytes);

      final result = await MedicationIdentifierService.instance
          .identify(imageBase64: base64Image);

      if (mounted) {
        setState(() {
          _result = result;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = MedicationIdentifierResult(
            erro: 'Erro ao processar imagem: $e',
          );
          _isProcessing = false;
        });
      }
    }
  }

  Widget _buildResultCard() {
    final result = _result!;
    if (result.hasError) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.error, color: AppColors.error, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                result.erro,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.tertiaryFixedDim,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle,
                  color: Color(0xFF2E7D32), size: 28),
              SizedBox(width: 8),
              Text(
                'Medicamento Identificado!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _detailRow('Nome', result.nome),
          _detailRow('Dosagem', result.dosagem),
          _detailRow('Forma', _formaLabel(result.forma)),
          _detailRow('Cor', result.cor),
          _detailRow('Intervalo sugerido', result.intervaloSugerido),
          if (result.observacoes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              result.observacoes,
              style: const TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formaLabel(String forma) {
    switch (forma.toLowerCase()) {
      case 'comprimido':
        return 'Comprimido';
      case 'capsula':
        return 'Cápsula';
      case 'gotas':
        return 'Gotas';
      case 'pomada':
        return 'Pomada';
      default:
        return forma;
    }
  }

  void _confirmarResultado() {
    final result = _result;
    if (result == null || !result.success) return;
    Navigator.pop(context, {
      'titulo': result.nome,
      'dosagem': result.dosagem,
      'forma': result.forma,
      'cor': result.cor,
      'intervaloSugerido': result.intervaloSugerido,
      'fotoPath': _fotoPath,
      'observacoes': result.observacoes,
    });
  }
}
