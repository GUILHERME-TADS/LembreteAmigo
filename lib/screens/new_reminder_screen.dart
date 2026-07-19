import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../widgets/supervisor_bottom_nav.dart';
import '../widgets/custom_time_picker.dart';
import '../widgets/supervisor_drawer.dart';

class NewReminderScreen extends StatefulWidget {
  final Lembrete? lembrete;
  const NewReminderScreen({super.key, this.lembrete});

  @override
  State<NewReminderScreen> createState() => _NewReminderScreenState();
}

class _NewReminderScreenState extends State<NewReminderScreen> {
  int _activeStep = 1;
  String? _selectedCategory;
  final _titleController = TextEditingController();

  bool _validateStep1() {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione uma categoria para o lembrete.'),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    final titulo = _titleController.text.trim();
    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, digite o que lembrar'),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }
    return true;
  }

  void _goToStep(int step) {
    if (step == 1) {
      setState(() => _activeStep = 1);
    } else if (step == 2) {
      if (_validateStep1()) {
        setState(() => _activeStep = 2);
      }
    } else if (step == 3) {
      if (_validateStep1() && _validateStep2()) {
        setState(() => _activeStep = 3);
      }
    }
  }
  TimeOfDay? _selectedTime;
  String? _audioPath;
  String? _fotoPath;
  final ImagePicker _imagePicker = ImagePicker();
  List<int> _selectedDiasSemana = [];
  bool _isSaving = false;
  bool _isCapturingPhoto = false;
  bool _isUsoContinuo = true;
  DateTime _dataInicio = DateTime.now();
  DateTime? _dataFim;
  DateTime? _selectedSingleDate;
  bool? _gerarAudioIA;
  String? _medicamentoInstrucoes;
  String? _medicamentoAudioTexto;

  @override
  void initState() {
    super.initState();
    if (widget.lembrete != null) {
      final l = widget.lembrete!;
      _selectedCategory = l.categoria;
      _titleController.text = l.titulo;
      _selectedTime = TimeOfDay(hour: l.horarioHour, minute: l.horarioMinute);
      _selectedDiasSemana = List<int>.from(l.diasSemana);
      _selectedSingleDate = l.lembreteUnico ? l.dataInicio : null;
      _isUsoContinuo = l.isUsoContinuo;
      _dataInicio = l.dataInicio ?? DateTime.now();
      _dataFim = l.dataFim;
      _audioPath = l.audioPath == 'ia_generated' ? null : l.audioPath;
      _fotoPath = l.medicamentoFotoPath;
      _medicamentoInstrucoes = l.medicamentoInstrucoes;
      _medicamentoAudioTexto = l.medicamentoAudioTexto;
      _gerarAudioIA = l.audioPath == null
          ? null
          : l.audioPath == 'ia_generated';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _capturarFotoRemedio() async {
    if (_fotoPath != null) {
      setState(() => _fotoPath = null);
      return;
    }
    if (_isCapturingPhoto) return;
    setState(() => _isCapturingPhoto = true);

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;

      setState(() => _fotoPath = image.path);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto do remédio vinculada com sucesso!'),
          backgroundColor: AppColors.tertiaryFixedDim,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível tirar a foto: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCapturingPhoto = false);
      }
    }
  }

  Widget _buildMedicationPhotoPreview() {
    final path = _fotoPath!;
    final image = kIsWeb || path.startsWith('http://') || path.startsWith('https://')
        ? Image.network(
            path,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.check_circle,
              color: AppColors.onTertiaryFixedVariant,
              size: 36,
            ),
          )
        : Image.file(
            File(path),
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.check_circle,
              color: AppColors.onTertiaryFixedVariant,
              size: 36,
            ),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: image,
    );
  }

  String _getRecurrenceDescription() {
    if (_selectedTime == null) {
      return 'Selecione o horário e os dias.';
    }
    final timeStr = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

    if (_selectedSingleDate != null) {
      final dateStr = '${_selectedSingleDate!.day.toString().padLeft(2, '0')}/${_selectedSingleDate!.month.toString().padLeft(2, '0')}/${_selectedSingleDate!.year}';
      return 'Toca uma única vez em $dateStr às $timeStr.';
    }

    if (_selectedDiasSemana.isEmpty) {
      final now = DateTime.now();
      final reminderTime = DateTime(now.year, now.month, now.day, _selectedTime!.hour, _selectedTime!.minute);
      if (reminderTime.isAfter(now)) {
        return 'Toca uma única vez hoje às $timeStr.';
      } else {
        return 'Toca uma única vez amanhã às $timeStr.';
      }
    }

    if (_selectedDiasSemana.length == 7) {
      return 'Toca diariamente às $timeStr.';
    }
    final Map<int, String> dayNames = {
      1: 'Segunda',
      2: 'Terça',
      3: 'Quarta',
      4: 'Quinta',
      5: 'Sexta',
      6: 'Sábado',
      7: 'Domingo',
    };
    final sortedDays = List<int>.from(_selectedDiasSemana)
      ..sort((a, b) {
        final valA = a == 7 ? 0 : a;
        final valB = b == 7 ? 0 : b;
        return valA.compareTo(valB);
      });
    final days = sortedDays.map((d) => dayNames[d] ?? '').toList();
    return 'Toca toda(o) ${days.join(", ")} às $timeStr.';
  }

  String _getStep1Summary() {
    if (_selectedCategory == null) return 'Nenhuma categoria selecionada';
    final Map<String, String> names = {
      'medicacao': 'Medicação',
      'refeicoes': 'Refeições',
      'exercicio': 'Exercício',
      'hidratacao': 'Hidratação',
      'personalizado': 'Personalizado',
    };
    return 'Categoria: ${names[_selectedCategory] ?? _selectedCategory}';
  }

  String _getStep2Summary() {
    final titulo = _titleController.text.trim();
    if (_selectedTime == null) {
      return titulo.isEmpty ? 'Nenhum horário selecionado' : titulo;
    }
    final timeStr = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';
    if (titulo.isEmpty) return 'Horário: $timeStr';
    return '$titulo às $timeStr';
  }

  String _getPlaceholder() {
    switch (_selectedCategory) {
      case 'medicacao':
        return 'Ex: Tomar a Losartana';
      case 'refeicoes':
        return 'Ex: Tomar o café da manhã';
      case 'exercicio':
        return 'Ex: Fazer caminhada';
      case 'hidratacao':
        return 'Ex: Beber 2 copos de água';
      case 'personalizado':
      default:
        return 'Ex: Medir a pressão';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const SupervisorDrawer(currentRoute: '/new-reminder'),
      bottomNavigationBar: const SupervisorBottomNav(
        selected: SupervisorNavDestination.newReminder,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Novo Lembrete',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Configure um lembrete para garantir o bem-estar e a rotina do idoso.',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Passo 1: Identificação (Categoria e Foto)
                    _buildStepCard(
                      stepNumber: 1,
                      title: 'Identificação',
                      summary: _getStep1Summary(),
                      children: [
                        _buildCategorySelector(),
                        if (_selectedCategory == 'medicacao') ...[
                          const SizedBox(height: 20),
                          _buildIACard(),
                          const SizedBox(height: 20),
                          _buildFotoSection(),
                        ],
                      ],
                    ),

                    // Passo 2: O Que Lembrar e Horário
                    _buildStepCard(
                      stepNumber: 2,
                      title: 'Informações e Horário',
                      summary: _getStep2Summary(),
                      children: [
                        Row(
                          children: [
                            const Text(
                              'O QUE LEMBRAR?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Obrigatório',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(minHeight: 56),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            border: Border.all(color: AppColors.outlineVariant),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _titleController,
                            maxLength: 80,
                            style: const TextStyle(fontSize: 18),
                            decoration: InputDecoration(
                              hintText: _getPlaceholder(),
                              border: InputBorder.none,
                              counterText: '',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Text(
                              'HORÁRIO DO LEMBRETE',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Obrigatório',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final time = await showCustomTimePicker(
                              context: context,
                              initialTime: _selectedTime ?? const TimeOfDay(hour: 8, minute: 0),
                            );
                            if (time != null) {
                              if (!mounted) return;
                              setState(() => _selectedTime = time);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.outlineVariant),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _selectedTime != null
                                      ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                                      : '--:--',
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Icon(
                                  Icons.schedule,
                                  size: 32,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Passo 3: Repetição e Avisos
                    _buildStepCard(
                      stepNumber: 3,
                      title: 'Áudio e Duração',
                      summary: _getRecurrenceDescription(),
                      children: [
                        _buildAudioSection(),
                        const SizedBox(height: 24),
                        _buildRecurrenceSection(),
                        if (_selectedCategory == 'medicacao') ...[
                          const SizedBox(height: 24),
                          _buildDurationSection(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required int stepNumber,
    required String title,
    required List<Widget> children,
    String? summary,
  }) {
    final isActive = _activeStep == stepNumber;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: isActive ? AppColors.surfaceContainerLow : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.outlineVariant,
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: InkWell(
          onTap: isActive ? null : () => _goToStep(stepNumber),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.primary : AppColors.outline,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$stepNumber',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (!isActive)
                      const Icon(
                        Icons.edit_note,
                        color: AppColors.outline,
                        size: 24,
                      ),
                  ],
                ),
                if (!isActive && summary != null && summary.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 38),
                    child: Text(
                      summary,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                if (isActive) ...[
                  const SizedBox(height: 16),
                  ...children,
                  if (stepNumber < 3) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _goToStep(stepNumber + 1),
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(
                          stepNumber == 1 ? 'Avançar para Etapa 2' : 'Avançar para Etapa 3',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Builder(
      builder: (context) {
        return Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            color: AppColors.surface,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu, color: AppColors.primary, size: 32),
              ),
              const Expanded(
                child: Text(
                  'Lembrete Amigo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIACard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.12),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppColors.primary,
                size: 26,
              ),
              const SizedBox(width: 8),
              const Text(
                'Preencher com Foto (IA)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Tire uma foto da receita médica ou da caixa do remédio para preencher os dados automaticamente com IA.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.pushNamed(
                      context,
                      '/identify-medication',
                    );
                    if (result != null && mounted) {
                      final data = result as Map<String, dynamic>;
                      setState(() {
                        _selectedCategory = 'medicacao';
                        if (data['titulo'] != null &&
                            data['titulo'].toString().isNotEmpty) {
                          final title = data['titulo'] as String;
                          final dosage = data['dosagem'] as String? ?? '';
                          _titleController.text = dosage.isNotEmpty ? '$title ($dosage)' : title;
                        }
                        if (data['fotoPath'] != null) {
                          _fotoPath = data['fotoPath'] as String;
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Campos preenchidos com sucesso!'),
                          backgroundColor: AppColors.tertiaryFixedDim,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.photo_camera, size: 20),
                  label: const Text(
                    'Escanear Receita ou Caixa',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.pushNamed(
                      context,
                      '/barcode-scanner',
                    );
                    if (result != null && mounted) {
                      final data = result as Map<String, dynamic>;
                      setState(() {
                        _selectedCategory = 'medicacao';
                        if (data['titulo'] != null &&
                            data['titulo'].toString().isNotEmpty) {
                          _titleController.text = data['titulo'] as String;
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Medicamento identificado por código de barras!'),
                          backgroundColor: AppColors.tertiaryFixedDim,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.qr_code_scanner, size: 20),
                  label: const Text(
                    'Escanear Código de Barras',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> cat) {
    final isSelected = _selectedCategory == cat['key'];
    final icon = cat['icon'] as IconData;
    final label = cat['label'] as String;
    final color = cat['color'] as Color;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = cat['key'] as String;
          if (_selectedCategory != 'medicacao') {
            if (_gerarAudioIA == true) {
              _gerarAudioIA = null;
            }
            _medicamentoInstrucoes = null;
            _medicamentoAudioTexto = null;
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.outlineVariant,
            width: isSelected ? 2.5 : 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? color : AppColors.outline,
              size: 26,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : AppColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    final categories = [
      {
        'icon': Icons.medication,
        'label': 'Medicação',
        'key': 'medicacao',
        'color': AppColors.medicationsColor,
      },
      {
        'icon': Icons.restaurant,
        'label': 'Refeições',
        'key': 'refeicoes',
        'color': AppColors.mealsColor,
      },
      {
        'icon': Icons.directions_walk,
        'label': 'Exercício',
        'key': 'exercicio',
        'color': AppColors.tertiary,
      },
      {
        'icon': Icons.water_drop,
        'label': 'Hidratação',
        'key': 'hidratacao',
        'color': AppColors.voiceFeedbackBlue,
      },
      {
        'icon': Icons.notifications,
        'label': 'Personalizado',
        'key': 'personalizado',
        'color': AppColors.customColor,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'CATEGORIA DO LEMBRETE',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Obrigatório',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildCategoryCard(categories[0])),
                const SizedBox(width: 10),
                Expanded(child: _buildCategoryCard(categories[1])),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildCategoryCard(categories[2])),
                const SizedBox(width: 10),
                Expanded(child: _buildCategoryCard(categories[3])),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: _buildCategoryCard(categories[4]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'FOTO REAL DO REMÉDIO',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Opcional',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Tire uma foto da embalagem ou do comprimido real para facilitar a identificação.',
          style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _capturarFotoRemedio,
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _fotoPath != null
                    ? AppColors.tertiaryFixedDim
                    : AppColors.outlineVariant,
                width: _fotoPath != null ? 3 : 2,
              ),
            ),
            child: _fotoPath != null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildMedicationPhotoPreview(),
                      const SizedBox(width: 12),
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Foto Vinculada!',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      TextButton(
                        onPressed: () => setState(() => _fotoPath = null),
                        child: const Text(
                          'Remover',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_camera,
                        size: 48,
                        color: AppColors.primary,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tirar Foto do Remédio',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'ÁUDIO DO IDOSO',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Opcional',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('Grave Voz'),
                selected: _gerarAudioIA == false,
                onSelected: (val) {
                  setState(() {
                    _gerarAudioIA = val ? false : null;
                    if (!val) _audioPath = null;
                  });
                },
              ),
            ),
            if (_selectedCategory == 'medicacao') ...[
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Voz por IA'),
                  selected: _gerarAudioIA == true,
                  onSelected: (val) {
                    setState(() {
                      _gerarAudioIA = val ? true : null;
                      if (val) _audioPath = null;
                    });
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (_gerarAudioIA == true) ...[
          const Center(
            child: Column(
              children: [
                Icon(Icons.auto_awesome, color: AppColors.primary, size: 36),
                SizedBox(height: 8),
                Text(
                  'Voz por IA Ativada',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'O app gerará uma fala acolhedora e explicativa do remédio para ler ao idoso.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ] else if (_gerarAudioIA == false) ...[
          if (_audioPath != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.audiotrack,
                  color: AppColors.onTertiaryFixedVariant,
                  size: 28,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Voz de familiar vinculada',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => setState(() => _audioPath = null),
                  child: const Text(
                    'Remover',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const Center(
              child: Text(
                'Grave uma frase familiar. Ela será tocada automaticamente no horário.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                onTap: () async {
                  final result = await Navigator.pushNamed(
                    context,
                    '/new-reminder-audio',
                  );
                  if (result is String) {
                    if (!mounted) return;
                    setState(() => _audioPath = result);
                  }
                },
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.secondaryContainer,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mic,
                    size: 32,
                    color: AppColors.onSecondaryContainer,
                  ),
                ),
              ),
            ),
          ],
        ] else ...[
          const Center(
            child: Column(
              children: [
                Icon(Icons.info_outline, color: AppColors.outline, size: 36),
                SizedBox(height: 8),
                Text(
                  'Nenhum áudio selecionado',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'O lembrete usará a voz de leitura padrão do sistema (opcional).',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecurrenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'REPETIÇÃO DO LEMBRETE',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Opcional',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_selectedSingleDate != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Agendado para data única',
                        style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_selectedSingleDate!.day.toString().padLeft(2, '0')}/${_selectedSingleDate!.month.toString().padLeft(2, '0')}/${_selectedSingleDate!.year}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedDiasSemana = [_selectedSingleDate!.weekday];
                      _selectedSingleDate = null;
                    });
                  },
                  child: const Text('Repetir Semanal'),
                ),
              ],
            ),
          ),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Selecione os dias da semana:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final date = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: AppColors.primary,
                            onPrimary: Colors.white,
                            onSurface: AppColors.onSurface,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (date != null) {
                    setState(() {
                      _selectedSingleDate = date;
                      _selectedDiasSemana = [];
                    });
                  }
                },
                icon: const Icon(Icons.calendar_month, size: 18),
                label: const Text('Data Única'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (idx) {
              final weekdays = [7, 1, 2, 3, 4, 5, 6];
              final weekday = weekdays[idx];
              final labels = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
              final isSelected = _selectedDiasSemana.contains(weekday);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedDiasSemana.remove(weekday);
                    } else {
                      _selectedDiasSemana.add(weekday);
                    }
                  });
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.surfaceContainerLowest,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.outlineVariant,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      labels[idx],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppColors.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.outlineVariant,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getRecurrenceDescription(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDurationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'DURAÇÃO DO TRATAMENTO',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Obrigatório',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('Uso Contínuo'),
                selected: _isUsoContinuo,
                onSelected: (val) {
                  setState(() => _isUsoContinuo = true);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceChip(
                label: const Text('Período Definido'),
                selected: !_isUsoContinuo,
                onSelected: (val) {
                  setState(() => _isUsoContinuo = false);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dataInicio,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _dataInicio = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Data Início',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_dataInicio.day}/${_dataInicio.month}/${_dataInicio.year}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!_isUsoContinuo) ...[
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dataFim ?? DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _dataFim = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Data Fim',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dataFim != null
                              ? '${_dataFim!.day}/${_dataFim!.month}/${_dataFim!.year}'
                              : 'Selecionar',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(
          top: BorderSide(color: AppColors.outlineVariant, width: 2),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 64,
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _salvarLembrete,
          icon: _isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _isSaving ? 'Salvando...' : 'Salvar e Enviar',
              maxLines: 1,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondaryContainer,
            foregroundColor: AppColors.onSecondaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }



  void _salvarLembrete() async {
    if (_isSaving) return;
    final titulo = _titleController.text.trim();
    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, digite o que lembrar'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (titulo.length > 80) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Use um nome com até 80 caracteres.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione uma categoria para o lembrete.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione o horário do lembrete.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    DateTime targetDate;
    if (_selectedSingleDate != null) {
      targetDate = _selectedSingleDate!;
    } else if (_selectedDiasSemana.isEmpty) {
      final now = DateTime.now();
      final reminderTime = DateTime(now.year, now.month, now.day, _selectedTime!.hour, _selectedTime!.minute);
      if (reminderTime.isAfter(now)) {
        targetDate = DateTime(now.year, now.month, now.day);
      } else {
        targetDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      }
    } else {
      targetDate = _dataInicio;
    }

    if (_gerarAudioIA == false && _audioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, grave o áudio para o lembrete.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final isSingleReminder =
        _selectedSingleDate != null || _selectedDiasSemana.isEmpty;
    if (!_isUsoContinuo &&
        _selectedCategory == 'medicacao' &&
        !isSingleReminder) {
      if (_dataFim == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecione a data de término do tratamento.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      final startDay = DateTime(_dataInicio.year, _dataInicio.month, _dataInicio.day);
      final endDay = DateTime(_dataFim!.year, _dataFim!.month, _dataFim!.day);
      if (endDay.isBefore(startDay)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A data de término deve ser posterior ou igual à data de início.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    if (mounted) {
      setState(() => _isSaving = true);
    }

    if (_selectedCategory == 'medicacao') {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            margin: EdgeInsets.all(32),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Analisando medicamento com IA...',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final newTimeStr = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';
      Map<String, dynamic>? analysis;
      try {
        analysis = await LembreteService.instance.analyzeMedication(
          newMedication: titulo,
          newMedicationTime: newTimeStr,
        );
      } catch (e) {
        debugPrint('Erro ao analisar medicamento: $e');
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }

      if (analysis != null) {
        _medicamentoInstrucoes = analysis['guidelines'] as String? ?? '';
        _medicamentoAudioTexto = analysis['suggestedAudioText'] as String? ?? '';

        final hasInteraction = analysis['hasInteraction'] == true;
        final severity = analysis['severity'].toString().toLowerCase();
        final interactionWarning = analysis['interactionWarning'] as String? ?? '';
        final schedulingConflictWarning = analysis['schedulingConflictWarning'] as String? ?? '';

        final bool showInteraction = hasInteraction && (severity == 'moderate' || severity == 'severe');
        final bool showConflict = schedulingConflictWarning.isNotEmpty;

        if (showInteraction || showConflict) {
          if (!mounted) return;
          final confirmSave = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              icon: Icon(
                Icons.warning_amber_rounded,
                color: severity == 'severe' ? Colors.red : Colors.orange,
                size: 48,
              ),
              title: const Text(
                'Alerta Clínico de IA',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Scrollbar(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showInteraction) ...[
                        const Text(
                          'Interação Medicamentosa:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          interactionWarning,
                          style: const TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (showConflict) ...[
                        const Text(
                          'Conflito de Horário / Polimedicação:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          schedulingConflictWarning,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Ajustar Lembrete'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: severity == 'severe' ? Colors.red : AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Ignorar e Salvar'),
                ),
              ],
            ),
          );

          if (confirmSave != true) {
            if (mounted) setState(() => _isSaving = false);
            return;
          }
        }
      }
    }

    final now = DateTime.now();
    final reminderId = widget.lembrete?.id ?? now.millisecondsSinceEpoch.toString();

    final lembrete = Lembrete(
      id: reminderId,
      titulo: titulo,
      horarioHour: _selectedTime!.hour,
      horarioMinute: _selectedTime!.minute,
      categoria: _selectedCategory ?? 'personalizado',
      audioPath: _gerarAudioIA == true ? 'ia_generated' : _audioPath,
      medicamentoFotoPath: _selectedCategory == 'medicacao' ? _fotoPath : null,
      medicamentoInstrucoes: _selectedCategory == 'medicacao' ? _medicamentoInstrucoes : null,
      medicamentoAudioTexto: _gerarAudioIA == true && _selectedCategory == 'medicacao' ? _medicamentoAudioTexto : null,
      recorrencia: (_selectedSingleDate != null || _selectedDiasSemana.isEmpty) ? 'unico' : (_selectedDiasSemana.length == 7 ? 'diario' : 'semanal'),
      repeteTodosOsDias: _selectedDiasSemana.length == 7,
      recorrenciaSemanal: _selectedDiasSemana.length < 7 && _selectedDiasSemana.isNotEmpty && _selectedSingleDate == null,
      recorrenciaMensal: false,
      recorrenciaIntervalo: false,
      lembreteUnico: _selectedSingleDate != null || _selectedDiasSemana.isEmpty,
      diasSemana: _selectedDiasSemana,
      diaMes: null,
      intervaloHoras: null,
      dataInicio: (_selectedSingleDate != null || _selectedDiasSemana.isEmpty) ? targetDate : _dataInicio,
      dataFim: (_selectedSingleDate != null || _selectedDiasSemana.isEmpty) ? targetDate : ((_isUsoContinuo || _selectedCategory != 'medicacao') ? null : _dataFim),
      isUsoContinuo: (_selectedSingleDate != null || _selectedDiasSemana.isEmpty) ? false : (_selectedCategory != 'medicacao' ? true : _isUsoContinuo),
      concluido: widget.lembrete?.concluido ?? false,
      concluidoComFoto: widget.lembrete?.concluidoComFoto ?? false,
      status: widget.lembrete?.status,
      criadoEm: widget.lembrete?.criadoEm,
    );

    try {
      await LembreteService.instance.adicionar(lembrete);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.lembrete == null
                ? 'Lembrete criado com sucesso!'
                : 'Lembrete atualizado com sucesso!',
          ),
          backgroundColor: AppColors.tertiaryFixedDim,
        ),
      );
      Navigator.pop(context, lembrete);
    } catch (e) {
      debugPrint('Erro interno ao salvar lembrete: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível salvar o lembrete agora. Tente novamente.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
