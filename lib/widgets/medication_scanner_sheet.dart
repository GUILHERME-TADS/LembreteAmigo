import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/medication_scan_result.dart';
import '../services/medication_scanner_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';

/// Modal bottom sheet para escaneamento e reconhecimento de caixas de remédio por IA.
class MedicationScannerSheet extends StatefulWidget {
  final ValueChanged<MedicationScanResult>? onMedicationScanned;

  const MedicationScannerSheet({super.key, this.onMedicationScanned});

  static Future<MedicationScanResult?> show(BuildContext context) {
    return showModalBottomSheet<MedicationScanResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const MedicationScannerSheet(),
    );
  }

  @override
  State<MedicationScannerSheet> createState() => _MedicationScannerSheetState();
}

class _MedicationScannerSheetState extends State<MedicationScannerSheet>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  late AnimationController _laserController;

  bool _isAnalyzing = false;
  File? _imageFile;
  MedicationScanResult? _scanResult;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      TTSService.instance.falar(
        'Aponte a câmera para a caixa do remédio ou escolha uma foto.',
        caller: this,
      );
    });
  }

  @override
  void dispose() {
    _laserController.dispose();
    TTSService.instance.parar(caller: this);
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      HapticFeedback.mediumImpact();
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() {
        _imageFile = File(picked.path);
        _isAnalyzing = true;
        _scanResult = null;
      });

      await TTSService.instance.falar('Analisando a caixa do remédio com inteligência artificial...', caller: this);

      final result = await MedicationScannerService.instance.analyzeMedicationImage(picked.path);

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _scanResult = result;
        });

        if (result != null) {
          HapticFeedback.heavyImpact();
          final text = 'Reconheci ${result.tituloCompleto}. ${result.explicacaoSimples ?? ""}';
          await TTSService.instance.falar(text, caller: this);
        } else {
          await TTSService.instance.falar(
            'Não consegui ler o nome com clareza. Tente tirar a foto com mais luz.',
            caller: this,
          );
        }
      }
    } catch (e) {
      debugPrint('[MedicationScannerSheet] Erro ao capturar foto: $e');
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  void _confirmAndApply() {
    if (_scanResult == null) return;
    HapticFeedback.mediumImpact();
    if (widget.onMedicationScanned != null) {
      widget.onMedicationScanned!(_scanResult!);
    }
    Navigator.of(context).pop(_scanResult);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de arraste
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Título e Ícone
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reconhecer Remédio por IA',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      'Aponte para a caixa ou bula',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Área de visualização / Moldura de Escaneamento
          if (_imageFile == null)
            _buildCaptureGuide()
          else
            _buildImagePreview(),

          const SizedBox(height: 20),

          // Card de Resultado Reconhecido
          if (_scanResult != null) _buildResultCard(),

          const SizedBox(height: 16),

          // Botões de Ação
          if (_scanResult != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirmAndApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 22),
                label: const Text(
                  'USAR ESTE REMÉDIO',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            )
          else if (!_isAnalyzing)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    icon: const Icon(Icons.camera_alt_rounded, size: 20),
                    label: const Text(
                      'Tirar Foto 📸',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    icon: const Icon(Icons.photo_library_rounded, size: 20),
                    label: const Text(
                      'Galeria 🖼️',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCaptureGuide() {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: AppColors.outlineVariant,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.crop_free_rounded, size: 54, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            'Enquadre o nome na caixa do remédio',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'O Gemini Vision lerá o nome e a dose',
            style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Image.file(
            _imageFile!,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        if (_isAnalyzing)
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: AnimatedBuilder(
              animation: _laserController,
              builder: (context, child) {
                return Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 12),
                          const Text(
                            'Lendo com IA...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: _laserController.value * 160,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.sunsetAmber,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.sunsetAmber,
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildResultCard() {
    final res = _scanResult!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.vitalHealthyContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.vitalHealthy, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.medication_rounded,
                size: 36,
                color: AppColors.vitalHealthy,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      res.tituloCompleto,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.vitalHealthy,
                      ),
                    ),
                    if (res.dosagem != null)
                      Text(
                        'Dosagem identificada: ${res.dosagem}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Ouvir explicação',
                icon: Icon(Icons.volume_up_rounded, color: AppColors.vitalHealthy),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  TTSService.instance.falar(
                    '${res.tituloCompleto}. ${res.explicacaoSimples ?? ""}',
                    caller: this,
                  );
                },
              ),
            ],
          ),
          if (res.explicacaoSimples != null) ...[
            const SizedBox(height: 8),
            Text(
              res.explicacaoSimples!,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.onSurface,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
