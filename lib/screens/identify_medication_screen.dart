import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/medication_identifier_service.dart';
import '../services/prescription_parser_service.dart';
import '../services/tts_service.dart';

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
  bool _isReceitaMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Identificar Remédio',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Identificar Remédio'),
                    selected: !_isReceitaMode,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: !_isReceitaMode
                          ? Colors.white
                          : AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _isReceitaMode = false;
                          _result = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('Ler Receita Médica'),
                    selected: _isReceitaMode,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _isReceitaMode
                          ? Colors.white
                          : AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _isReceitaMode = true;
                          _result = null;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                _isReceitaMode
                    ? 'Tire uma foto nítida da receita médica.'
                    : 'Tire uma foto do comprimido ou da embalagem.',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isReceitaMode
                    ? 'A inteligência artificial vai ler a receita e extrair os lembretes.'
                    : 'A inteligência artificial vai identificar o medicamento automaticamente.',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _mostrarDicasFoto,
                  icon: const Icon(Icons.tips_and_updates, color: AppColors.primary, size: 20),
                  label: const Text(
                    'Dicas para uma foto perfeita com IA',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: _fotoPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(_fotoPath!),
                          height: 300,
                          fit: BoxFit.contain,
                          errorBuilder: (_, error, stackTrace) =>
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
                                Icons.add_a_photo,
                                size: 72,
                                color: AppColors.primary,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'ADICIONAR FOTO',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Câmera ou Galeria',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
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
                      _fotoPath != null && !_isProcessing
                          ? (_result != null ? _tirarFoto : _identificar)
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isProcessing
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _isReceitaMode
                                  ? 'Analisando receita...'
                                  : 'Analisando imagem...',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          _result != null
                              ? 'TIRAR NOVA FOTO'
                              : (_isReceitaMode
                                  ? 'LER RECEITA MÉDICA'
                                  : 'IDENTIFICAR REMÉDIO'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              if (_result != null && _result!.success && !_isReceitaMode) ...[
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
        ),
      ),
    );
  }

  Future<void> _tirarFoto() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Adicionar Imagem',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_camera, color: AppColors.primary, size: 28),
                title: const Text('Tirar Foto com a Câmera', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhotoSource(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primary, size: 28),
                title: const Text('Escolher da Galeria', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhotoSource(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPhotoSource(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() {
          _fotoPath = image.path;
          _result = null;
        });
        _identificar();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao selecionar foto: $e'),
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

      if (_isReceitaMode) {
        final result = await PrescriptionParserService.instance
            .parse(imageBase64: base64Image);

        if (mounted) {
          setState(() => _isProcessing = false);
          if (result.success) {
            final saved = await Navigator.pushNamed(
              context,
              '/medication-bulk-confirmation',
              arguments: result.lembretes,
            );
            if (saved == true && mounted) {
              Navigator.pop(context, true);
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  result.erro.isNotEmpty
                      ? result.erro
                      : 'Nenhum medicamento encontrado na receita.',
                ),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      } else {
        final result = await MedicationIdentifierService.instance
            .identify(imageBase64: base64Image);

        if (mounted) {
          setState(() {
            _result = result;
            _isProcessing = false;
          });
        }
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
    if (!result.success) {
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
                result.hasError ? result.erro : 'Nenhum medicamento reconhecido na imagem. Tente tirar outra foto.',
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 26),
                  SizedBox(width: 8),
                  Text(
                    'Identificado!',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _ouvirResultado,
                icon: const Icon(Icons.volume_up, size: 18),
                label: const Text('Ouvir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _detailRow('Nome', result.nome, onEdit: () => _editarCampo('nome', result.nome)),
          _detailRow('Dosagem', result.dosagem, onEdit: () => _editarCampo('dosagem', result.dosagem)),
          _detailRow('Intervalo sugerido', result.intervaloSugerido, onEdit: () => _editarCampo('intervalo', result.intervaloSugerido)),
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

  void _ouvirResultado() {
    final result = _result;
    if (result == null) return;
    TTSService.instance.parar();
    final texto = 'Identifiquei o medicamento ${result.nome}, dosagem ${result.dosagem}. Sugestão de uso: ${result.intervaloSugerido}. ${result.observacoes}';
    TTSService.instance.falar(texto);
  }

  void _editarCampo(String campo, String valorAtual) {
    final controller = TextEditingController(text: valorAtual);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar ${campo.toUpperCase()}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: campo,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                if (_result != null) {
                  if (campo == 'nome') {
                    _result = MedicationIdentifierResult(
                      nome: controller.text.trim(),
                      dosagem: _result!.dosagem,
                      intervaloSugerido: _result!.intervaloSugerido,
                      observacoes: _result!.observacoes,
                    );
                  } else if (campo == 'dosagem') {
                    _result = MedicationIdentifierResult(
                      nome: _result!.nome,
                      dosagem: controller.text.trim(),
                      intervaloSugerido: _result!.intervaloSugerido,
                      observacoes: _result!.observacoes,
                    );
                  } else if (campo == 'intervalo') {
                    _result = MedicationIdentifierResult(
                      nome: _result!.nome,
                      dosagem: _result!.dosagem,
                      intervaloSugerido: controller.text.trim(),
                      observacoes: _result!.observacoes,
                    );
                  }
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDicasFoto() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.tips_and_updates, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Dicas para Boa Foto'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.light_mode, color: Colors.amber),
              title: Text('Boa iluminação', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Tire a foto em um local bem iluminado para evitar sombras sobre o texto.'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.center_focus_strong, color: AppColors.primary),
              title: Text('Foco no texto principal', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Foque bem no nome do remédio e na dosagem (ex: 50mg ou 10ml).'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.flash_off, color: Colors.orange),
              title: Text('Cuidado com reflexos', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Evite que o flash da câmera reflita no plástico ou vidro da embalagem.'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {VoidCallback? onEdit}) {
    if (value.isEmpty && onEdit == null) return const SizedBox.shrink();
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
              value.isEmpty ? '(Não identificado)' : value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(left: 8),
              onPressed: onEdit,
              tooltip: 'Editar $label',
            ),
        ],
      ),
    );
  }


  void _confirmarResultado() {
    final result = _result;
    if (result == null || !result.success) return;
    Navigator.pop(context, {
      'titulo': result.nome,
      'dosagem': result.dosagem,
      'intervaloSugerido': result.intervaloSugerido,
      'fotoPath': _fotoPath,
      'observacoes': result.observacoes,
    });
  }
}
