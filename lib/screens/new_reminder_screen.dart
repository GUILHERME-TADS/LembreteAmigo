import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../services/medication_safety_service.dart';
import '../widgets/supervisor_bottom_nav.dart';
import '../widgets/custom_time_picker.dart';
import '../widgets/supervisor_drawer.dart';
import '../services/session_role_service.dart';

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
  final _medicationDoseController = TextEditingController();
  final _medicationUnitController = TextEditingController();
  final _medicationStockController = TextEditingController();
  final _medicationLowStockController = TextEditingController();
  final _medicationUnitsPerDoseController = TextEditingController();
  LembretePrioridade _priority = LembretePrioridade.normal;
  int _toleranceMinutes = 30;
  int _repeatIntervalMinutes = 5;
  int _maxReminderRepeats = 2;
  bool _escalateToCaregiver = true;
  LembreteModoConfirmacao _confirmationMode = LembreteModoConfirmacao.simples;
  List<int> _snoozeOptions = [5, 10, 15];
  int _maxSnoozes = 2;

  bool _validateStep1() {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
        SnackBar(
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
      if (_selectedDiasSemana.isEmpty && l.repeteTodosOsDias) {
        _selectedDiasSemana = [1, 2, 3, 4, 5, 6, 7];
      }
      _selectedSingleDate = l.lembreteUnico ? l.dataInicio : null;
      _isUsoContinuo = l.isUsoContinuo;
      _dataInicio = l.dataInicio ?? DateTime.now();
      _dataFim = l.dataFim;
      _audioPath = l.audioPath == 'ia_generated' ? null : l.audioPath;
      _fotoPath = l.medicamentoFotoPath;
      _medicamentoInstrucoes = l.medicamentoInstrucoes;
      _medicamentoAudioTexto = l.medicamentoAudioTexto;
      _priority = l.prioridade;
      _toleranceMinutes = l.toleranciaMinutos;
      _repeatIntervalMinutes = l.intervaloRepeticaoMinutos;
      _maxReminderRepeats = l.maximoRepeticoes;
      _escalateToCaregiver = l.avisarCuidador;
      _confirmationMode = l.modoConfirmacao;
      _snoozeOptions = List<int>.from(l.opcoesAdiamentoMinutos);
      _maxSnoozes = l.maximoAdiamentos;
      _medicationDoseController.text = l.medicamentoDose ?? '';
      _medicationUnitController.text = l.medicamentoUnidade ?? '';
      _medicationStockController.text = l.medicamentoEstoque?.toString() ?? '';
      _medicationLowStockController.text =
          l.medicamentoEstoqueMinimo?.toString() ?? '';
      _medicationUnitsPerDoseController.text =
          l.medicamentoUnidadesPorDose?.toString() ?? '';
      _gerarAudioIA = l.audioPath == null
          ? null
          : l.audioPath == 'ia_generated';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _medicationDoseController.dispose();
    _medicationUnitController.dispose();
    _medicationStockController.dispose();
    _medicationLowStockController.dispose();
    _medicationUnitsPerDoseController.dispose();
    super.dispose();
  }

  Future<void> _capturarFotoRemedio() async {
    if (_fotoPath != null) {
      setState(() => _fotoPath = null);
      return;
    }
    if (_isCapturingPhoto) return;

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
                'Adicionar Foto do Remédio',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  Icons.photo_camera,
                  color: AppColors.primary,
                  size: 28,
                ),
                title: const Text(
                  'Tirar Foto com a Câmera',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFotoRemedio(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: AppColors.primary,
                  size: 28,
                ),
                title: const Text(
                  'Escolher da Galeria',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFotoRemedio(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFotoRemedio(ImageSource source) async {
    if (_isCapturingPhoto) return;
    setState(() => _isCapturingPhoto = true);

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;

      setState(() => _fotoPath = image.path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Foto do remédio vinculada com sucesso!'),
          backgroundColor: AppColors.tertiaryFixedDim,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível adicionar a foto: $e'),
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
    final image =
        kIsWeb || path.startsWith('http://') || path.startsWith('https://')
        ? Image.network(
            path,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) => Icon(
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
            errorBuilder: (_, error, stackTrace) => Icon(
              Icons.check_circle,
              color: AppColors.onTertiaryFixedVariant,
              size: 36,
            ),
          );
    return ClipRRect(borderRadius: BorderRadius.circular(8), child: image);
  }

  String _getRecurrenceDescription() {
    if (_selectedTime == null) {
      return 'Selecione o horário e os dias.';
    }
    final timeStr =
        '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

    if (_selectedSingleDate != null) {
      final dateStr =
          '${_selectedSingleDate!.day.toString().padLeft(2, '0')}/${_selectedSingleDate!.month.toString().padLeft(2, '0')}/${_selectedSingleDate!.year}';
      return 'Toca uma única vez em $dateStr às $timeStr.';
    }

    if (_selectedDiasSemana.isEmpty) {
      final now = DateTime.now();
      final reminderTime = DateTime(
        now.year,
        now.month,
        now.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
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
      'consulta': 'Consulta ou exame',
      'personalizado': 'Personalizado',
    };
    return 'Categoria: ${names[_selectedCategory] ?? _selectedCategory}';
  }

  String _getStep2Summary() {
    final titulo = _titleController.text.trim();
    if (_selectedTime == null) {
      return titulo.isEmpty ? 'Nenhum horário selecionado' : titulo;
    }
    final timeStr =
        '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';
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
      case 'consulta':
        return 'Ex: Consulta com cardiologista';
      case 'personalizado':
      default:
        return 'Ex: Medir a pressão';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: SessionRoleService.isSupervisor
          ? const SupervisorDrawer(currentRoute: '/new-reminder')
          : null,
      bottomNavigationBar: SessionRoleService.isSupervisor
          ? const SupervisorBottomNav(
              selected: SupervisorNavDestination.newReminder,
            )
          : null,
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
                    Text(
                      'Novo Lembrete',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Configure um lembrete para garantir o bem-estar e a rotina do idoso.',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildIACard(),
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
                            Text(
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
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
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Text(
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
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
                              initialTime:
                                  _selectedTime ??
                                  const TimeOfDay(hour: 8, minute: 0),
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
                              border: Border.all(
                                color: AppColors.outlineVariant,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _selectedTime != null
                                      ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                                      : '--:--',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Icon(
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
                        const SizedBox(height: 24),
                        _buildSafetySection(),
                        if (_selectedCategory == 'medicacao') ...[
                          const SizedBox(height: 24),
                          _buildMedicationSafetySection(),
                        ],
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
          color: isActive
              ? AppColors.surfaceContainerLow
              : AppColors.surfaceContainerLowest,
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
                  ),
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
                          color: isActive
                              ? AppColors.primary
                              : AppColors.onSurfaceVariant,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (!isActive)
                      Icon(Icons.edit_note, color: AppColors.outline, size: 24),
                  ],
                ),
                if (!isActive && summary != null && summary.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 38),
                    child: Text(
                      summary,
                      style: TextStyle(
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
                          stepNumber == 1
                              ? 'Avançar para Etapa 2'
                              : 'Avançar para Etapa 3',
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
          decoration: BoxDecoration(color: AppColors.surface),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: Icon(Icons.menu, color: AppColors.primary, size: 32),
              ),
              Expanded(
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
              Icon(Icons.auto_awesome, color: AppColors.primary, size: 26),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'PREENCHIMENTO RÁPIDO COM IA',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Opcional',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tem uma receita médica ou caixinha de remédio? Toque abaixo para a Inteligência Artificial ler e preencher o formulário automaticamente para você.',
            style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
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
                        _activeStep = 2;
                        if (data['titulo'] != null &&
                            data['titulo'].toString().isNotEmpty) {
                          final title = data['titulo'] as String;
                          final dosage = data['dosagem'] as String? ?? '';
                          _titleController.text = dosage.isNotEmpty
                              ? '$title ($dosage)'
                              : title;
                        }
                        if (data['fotoPath'] != null) {
                          _fotoPath = data['fotoPath'] as String;
                        }
                        if (data['observacoes'] != null &&
                            data['observacoes'].toString().isNotEmpty) {
                          _medicamentoInstrucoes =
                              data['observacoes'] as String;
                        }
                        if (data['intervaloSugerido'] != null &&
                            data['intervaloSugerido'].toString().isNotEmpty) {
                          final interval = data['intervaloSugerido'] as String;
                          if (_medicamentoInstrucoes != null &&
                              _medicamentoInstrucoes!.isNotEmpty) {
                            _medicamentoInstrucoes =
                                '$_medicamentoInstrucoes (Sugestão de intervalo: $interval)';
                          } else {
                            _medicamentoInstrucoes =
                                'Sugestão de intervalo: $interval';
                          }
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Campos preenchidos com sucesso!'),
                          backgroundColor: AppColors.tertiaryFixedDim,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.photo_camera, size: 20),
                  label: const Text(
                    'Escanear Receita ou Caixa',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                        _activeStep = 2;
                        if (data['titulo'] != null &&
                            data['titulo'].toString().isNotEmpty) {
                          _titleController.text = data['titulo'] as String;
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Medicamento identificado por código de barras!',
                          ),
                          backgroundColor: AppColors.tertiaryFixedDim,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.qr_code_scanner, size: 20),
                  label: const Text(
                    'Escanear Código de Barras',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary, width: 2),
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
          if (_selectedCategory == 'medicacao' &&
              _priority == LembretePrioridade.normal) {
            _priority = LembretePrioridade.importante;
            _toleranceMinutes = 15;
            if (widget.lembrete == null) {
              _confirmationMode = LembreteModoConfirmacao.foto;
            }
          }
          if (_selectedCategory != 'medicacao') {
            if (widget.lembrete == null) {
              _confirmationMode = LembreteModoConfirmacao.simples;
            }
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
            Icon(icon, color: isSelected ? color : AppColors.outline, size: 26),
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
        'icon': Icons.event_available,
        'label': 'Consulta',
        'key': 'consulta',
        'color': AppColors.primary,
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
            Text(
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
              child: Text(
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
            Row(
              children: [
                Expanded(child: _buildCategoryCard(categories[4])),
                const SizedBox(width: 10),
                Expanded(child: _buildCategoryCard(categories[5])),
              ],
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
            Text(
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
              child: Text(
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
        Text(
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
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Foto Vinculada!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _fotoPath = null),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
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
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo,
                        size: 44,
                        color: AppColors.primary,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Adicionar Foto do Remédio',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Câmera ou Galeria',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant,
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
            Text(
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
              child: Text(
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
          Center(
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
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ] else if (_gerarAudioIA == false) ...[
          if (_audioPath != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.audiotrack,
                  color: AppColors.onTertiaryFixedVariant,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Voz de familiar vinculada',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _audioPath = null),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Remover',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Center(
              child: Text(
                'Grave uma frase familiar. Ela será tocada automaticamente no horário.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
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
                  decoration: BoxDecoration(
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
                  child: Icon(
                    Icons.mic,
                    size: 32,
                    color: AppColors.onSecondaryContainer,
                  ),
                ),
              ),
            ),
          ],
        ] else ...[
          Center(
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
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecurrenceSection() {
    final bool isDiario =
        _selectedSingleDate == null && _selectedDiasSemana.length == 7;
    final bool isDataUnica =
        _selectedSingleDate != null ||
        (_selectedSingleDate == null && _selectedDiasSemana.isEmpty);
    final bool isSemanal =
        _selectedSingleDate == null &&
        _selectedDiasSemana.isNotEmpty &&
        _selectedDiasSemana.length < 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.repeat, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text(
              'FREQUÊNCIA E REPETIÇÃO',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text(
                'Todos os Dias',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              selected: isDiario,
              onSelected: (_) {
                setState(() {
                  _selectedSingleDate = null;
                  _selectedDiasSemana = [1, 2, 3, 4, 5, 6, 7];
                });
              },
            ),
            ChoiceChip(
              label: const Text(
                'Dias da Semana',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              selected: isSemanal,
              onSelected: (_) {
                setState(() {
                  _selectedSingleDate = null;
                  if (_selectedDiasSemana.isEmpty ||
                      _selectedDiasSemana.length == 7) {
                    _selectedDiasSemana = [1, 2, 3, 4, 5];
                  }
                });
              },
            ),
            ChoiceChip(
              label: const Text(
                'Data Única',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              selected: isDataUnica,
              onSelected: (_) {
                setState(() {
                  _selectedSingleDate = _selectedSingleDate ?? DateTime.now();
                  _selectedDiasSemana = [];
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (isDiario) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.primary, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'O lembrete tocará todos os dias da semana (de Domingo a Sábado).',
                    style: TextStyle(fontSize: 14, color: AppColors.onSurface),
                  ),
                ),
              ],
            ),
          ),
        ] else if (isSemanal) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Toque nos dias em que o lembrete deve tocar:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurfaceVariant,
                ),
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
                          if (_selectedDiasSemana.length > 1) {
                            _selectedDiasSemana.remove(weekday);
                          }
                        } else {
                          _selectedDiasSemana.add(weekday);
                        }
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surfaceContainerLowest,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.outlineVariant,
                          width: 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          labels[idx],
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : AppColors.onSurface,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedDiasSemana = [1, 2, 3, 4, 5];
                      });
                    },
                    icon: const Icon(Icons.work_outline, size: 16),
                    label: const Text(
                      'Seg a Sex',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedDiasSemana = [6, 7];
                      });
                    },
                    icon: const Icon(Icons.weekend_outlined, size: 16),
                    label: const Text(
                      'Fim de Semana',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month, color: AppColors.primary, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data do Lembrete',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedSingleDate != null
                            ? '${_selectedSingleDate!.day.toString().padLeft(2, '0')}/${_selectedSingleDate!.month.toString().padLeft(2, '0')}/${_selectedSingleDate!.year}'
                            : 'Selecione uma data',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedSingleDate ?? now,
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 365)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
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
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('Alterar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.outlineVariant, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getRecurrenceDescription(),
                  style: TextStyle(
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
            Text(
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
              child: Text(
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
                      Text(
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
                      initialDate:
                          _dataFim ??
                          DateTime.now().add(const Duration(days: 7)),
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
                        Text(
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

  Widget _buildSafetySection() {
    const labels = {
      LembretePrioridade.normal: 'Normal',
      LembretePrioridade.importante: 'Importante',
      LembretePrioridade.critica: 'Crítica',
    };
    const confirmationLabels = {
      LembreteModoConfirmacao.simples: 'Um toque',
      LembreteModoConfirmacao.vozOuBotao: 'Voz ou botao',
      LembreteModoConfirmacao.foto: 'Foto',
      LembreteModoConfirmacao.cuidador: 'Somente cuidador',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ATENÇÃO E ESCALONAMENTO',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Defina quando o cuidador deve ser avisado se não houver resposta.',
          style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<LembreteModoConfirmacao>(
          initialValue: _confirmationMode,
          decoration: const InputDecoration(
            labelText: 'Como confirmar',
            helperText: 'Medicamentos ficam mais seguros com foto.',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.verified_user_outlined),
          ),
          items: LembreteModoConfirmacao.values
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(confirmationLabels[value]!),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _confirmationMode = value);
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'Opcoes para lembrar depois',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'A pessoa escolhe um destes tempos quando o aviso aparecer.',
          style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [5, 10, 15, 30].map((minutes) {
            final selected = _snoozeOptions.contains(minutes);
            return FilterChip(
              selected: selected,
              label: Text('$minutes min'),
              onSelected: (enabled) {
                setState(() {
                  if (enabled) {
                    _snoozeOptions = {..._snoozeOptions, minutes}.toList()
                      ..sort();
                  } else if (_snoozeOptions.length > 1) {
                    _snoozeOptions = _snoozeOptions
                        .where((value) => value != minutes)
                        .toList();
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        _buildIntDropdown(
          label: 'Maximo de adiamentos',
          value: _maxSnoozes,
          values: const [0, 1, 2, 3, 5],
          onChanged: (value) => setState(() => _maxSnoozes = value),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<LembretePrioridade>(
          initialValue: _priority,
          decoration: const InputDecoration(
            labelText: 'Nível de atenção',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.priority_high),
          ),
          items: LembretePrioridade.values
              .map(
                (value) =>
                    DropdownMenuItem(value: value, child: Text(labels[value]!)),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _priority = value;
              if (value == LembretePrioridade.critica &&
                  _toleranceMinutes > 10) {
                _toleranceMinutes = 10;
              }
            });
          },
        ),
        const SizedBox(height: 12),
        _buildIntDropdown(
          label: 'Tempo sem resposta',
          value: _toleranceMinutes,
          values: const [5, 10, 15, 30, 60, 120],
          suffix: 'minutos',
          onChanged: (value) => setState(() => _toleranceMinutes = value),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildIntDropdown(
                label: 'Repetições',
                value: _maxReminderRepeats,
                values: const [0, 1, 2, 3, 5],
                onChanged: (value) =>
                    setState(() => _maxReminderRepeats = value),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildIntDropdown(
                label: 'Intervalo',
                value: _repeatIntervalMinutes,
                values: const [2, 5, 10, 15, 30],
                suffix: 'min',
                onChanged: (value) =>
                    setState(() => _repeatIntervalMinutes = value),
              ),
            ),
          ],
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _escalateToCaregiver,
          onChanged: (value) => setState(() => _escalateToCaregiver = value),
          title: const Text(
            'Avisar cuidador',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Text(
            'Envia um alerta quando terminar o tempo sem resposta.',
          ),
        ),
      ],
    );
  }

  Widget _buildIntDropdown({
    required String label,
    required int value,
    required List<int> values,
    required ValueChanged<int> onChanged,
    String? suffix,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: values
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(suffix == null ? '$item' : '$item $suffix'),
            ),
          )
          .toList(),
      onChanged: (item) {
        if (item != null) onChanged(item);
      },
    );
  }

  Widget _buildMedicationSafetySection() {
    InputDecoration decoration(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DADOS DO MEDICAMENTO',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ajuda a evitar enganos e a avisar quando o medicamento estiver acabando.',
          style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _medicationDoseController,
                maxLength: 40,
                decoration: decoration('Dose', hint: 'Ex: 1'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _medicationUnitController,
                maxLength: 30,
                decoration: decoration('Unidade', hint: 'comprimido'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _medicationStockController,
                keyboardType: TextInputType.number,
                decoration: decoration('Estoque atual', hint: '30'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _medicationLowStockController,
                keyboardType: TextInputType.number,
                decoration: decoration('Avisar quando restarem', hint: '5'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _medicationUnitsPerDoseController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: decoration(
            'Quantidade consumida por confirmação',
            hint: 'Ex: 1',
          ),
        ),
      ],
    );
  }

  int? _optionalInt(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : int.tryParse(value);
  }

  double? _optionalDouble(TextEditingController controller) {
    final value = controller.text.trim().replaceAll(',', '.');
    return value.isEmpty ? null : double.tryParse(value);
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
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

  Future<bool> _confirmMedicationSafety(String title) async {
    final time = _selectedTime;
    if (_selectedCategory != 'medicacao' || time == null) return true;
    final oneTime = _selectedSingleDate != null || _selectedDiasSemana.isEmpty;
    final startDate = _selectedSingleDate ?? _dataInicio;
    final endDate = oneTime ? startDate : (_isUsoContinuo ? null : _dataFim);
    final warnings = MedicationSafetyService.findScheduleConflicts(
      title: title,
      hour: time.hour,
      minute: time.minute,
      weekDays: _selectedDiasSemana,
      existingReminders: LembreteService.instance.lembretes,
      editingReminderId: widget.lembrete?.id,
      startDate: startDate,
      endDate: endDate,
      oneTime: oneTime,
    );
    if (warnings.isEmpty || !mounted) return true;

    final hasCritical = warnings.any(
      (warning) => warning.severity == MedicationSafetySeverity.critical,
    );
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          hasCritical ? Icons.block : Icons.warning_amber_rounded,
          color: hasCritical ? AppColors.error : AppColors.warning,
          size: 48,
        ),
        title: Text(
          hasCritical
              ? 'Dose duplicada bloqueada'
              : 'Confira os horários dos medicamentos',
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: warnings
                  .map(
                    (warning) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        warning.severity == MedicationSafetySeverity.critical
                            ? Icons.error
                            : Icons.info,
                        color:
                            warning.severity ==
                                MedicationSafetySeverity.critical
                            ? AppColors.error
                            : AppColors.warning,
                      ),
                      title: Text(
                        warning.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(warning.message),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Voltar e corrigir'),
          ),
          if (!hasCritical)
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Horários conferidos'),
            ),
        ],
      ),
    );
    return result == true;
  }

  void _salvarLembrete() async {
    if (_isSaving) return;
    final titulo = _titleController.text.trim();
    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor, digite o que lembrar'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (titulo.length > 80) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Use um nome com até 80 caracteres.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selecione uma categoria para o lembrete.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor, selecione o horário do lembrete.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final medicationStock = _optionalInt(_medicationStockController);
    final medicationLowStock = _optionalInt(_medicationLowStockController);
    final medicationUnitsPerDose = _optionalDouble(
      _medicationUnitsPerDoseController,
    );
    if (_selectedCategory == 'medicacao' &&
        ((medicationStock != null && medicationStock < 0) ||
            (medicationLowStock != null && medicationLowStock < 0) ||
            (medicationUnitsPerDose != null && medicationUnitsPerDose <= 0))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Confira os números de estoque e consumo do medicamento.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    DateTime targetDate;
    if (_selectedSingleDate != null) {
      targetDate = _selectedSingleDate!;
    } else if (_selectedDiasSemana.isEmpty) {
      if (widget.lembrete != null && widget.lembrete!.dataInicio != null) {
        // Na edição, mantemos a data de início original para lembretes de dia único,
        // em vez de jogá-los para amanhã, a menos que o usuário mude a data explicitamente.
        targetDate = _dataInicio;
      } else {
        final now = DateTime.now();
        final reminderTime = DateTime(
          now.year,
          now.month,
          now.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
        if (reminderTime.isAfter(now)) {
          targetDate = DateTime(now.year, now.month, now.day);
        } else {
          targetDate = DateTime(
            now.year,
            now.month,
            now.day,
          ).add(const Duration(days: 1));
        }
      }
    } else {
      targetDate = _dataInicio;
    }

    if (_gerarAudioIA == false && _audioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
          SnackBar(
            content: Text(
              'Por favor, selecione a data de término do tratamento.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      final startDay = DateTime(
        _dataInicio.year,
        _dataInicio.month,
        _dataInicio.day,
      );
      final endDay = DateTime(_dataFim!.year, _dataFim!.month, _dataFim!.day);
      if (endDay.isBefore(startDay)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'A data de término deve ser posterior ou igual à data de início.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    if (!await _confirmMedicationSafety(titulo)) {
      return;
    }
    if (!mounted) return;

    if (mounted) {
      setState(() => _isSaving = true);
    }

    final bool isMedicationChanged =
        widget.lembrete == null ||
        widget.lembrete!.titulo.trim().toLowerCase() !=
            titulo.trim().toLowerCase() ||
        widget.lembrete!.horarioHour != _selectedTime!.hour ||
        widget.lembrete!.horarioMinute != _selectedTime!.minute;

    if (_selectedCategory == 'medicacao' && isMedicationChanged) {
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

      final newTimeStr =
          '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';
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
        _medicamentoAudioTexto =
            analysis['suggestedAudioText'] as String? ?? '';

        final hasInteraction = analysis['hasInteraction'] == true;
        final severity = analysis['severity'].toString().toLowerCase();
        final interactionWarning =
            analysis['interactionWarning'] as String? ?? '';
        final schedulingConflictWarning =
            analysis['schedulingConflictWarning'] as String? ?? '';

        final bool showInteraction =
            hasInteraction && (severity == 'moderate' || severity == 'severe');
        final bool showConflict = schedulingConflictWarning.isNotEmpty;

        if (showInteraction || showConflict) {
          if (!mounted) return;
          final confirmSave = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              icon: Icon(
                Icons.warning_amber_rounded,
                color: severity == 'severe'
                    ? AppColors.error
                    : AppColors.warning,
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
                        Text(
                          'Interação Medicamentosa:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          interactionWarning,
                          style: const TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (showConflict) ...[
                        Text(
                          'Conflito de Horário / Polimedicação:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.warning,
                          ),
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
                    backgroundColor: severity == 'severe'
                        ? AppColors.error
                        : AppColors.primary,
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
    final reminderId =
        widget.lembrete?.id ?? now.millisecondsSinceEpoch.toString();

    final lembrete = Lembrete(
      id: reminderId,
      titulo: titulo,
      horarioHour: _selectedTime!.hour,
      horarioMinute: _selectedTime!.minute,
      categoria: _selectedCategory ?? 'personalizado',
      prioridade: _priority,
      toleranciaMinutos: _toleranceMinutes,
      intervaloRepeticaoMinutos: _repeatIntervalMinutes,
      maximoRepeticoes: _maxReminderRepeats,
      avisarCuidador: _escalateToCaregiver,
      modoConfirmacao: _confirmationMode,
      opcoesAdiamentoMinutos: _snoozeOptions,
      maximoAdiamentos: _maxSnoozes,
      medicamentoDose: _selectedCategory == 'medicacao'
          ? _medicationDoseController.text.trim()
          : null,
      medicamentoUnidade: _selectedCategory == 'medicacao'
          ? _medicationUnitController.text.trim()
          : null,
      medicamentoEstoque: _selectedCategory == 'medicacao'
          ? medicationStock
          : null,
      medicamentoEstoqueMinimo: _selectedCategory == 'medicacao'
          ? medicationLowStock
          : null,
      medicamentoUnidadesPorDose: _selectedCategory == 'medicacao'
          ? medicationUnitsPerDose
          : null,
      audioPath: _gerarAudioIA == true ? 'ia_generated' : _audioPath,
      medicamentoFotoPath: _selectedCategory == 'medicacao' ? _fotoPath : null,
      medicamentoInstrucoes: _selectedCategory == 'medicacao'
          ? _medicamentoInstrucoes
          : null,
      medicamentoAudioTexto:
          _gerarAudioIA == true && _selectedCategory == 'medicacao'
          ? _medicamentoAudioTexto
          : null,
      recorrencia: (_selectedSingleDate != null || _selectedDiasSemana.isEmpty)
          ? 'unico'
          : (_selectedDiasSemana.length == 7 ? 'diario' : 'semanal'),
      repeteTodosOsDias: _selectedDiasSemana.length == 7,
      recorrenciaSemanal:
          _selectedDiasSemana.length < 7 &&
          _selectedDiasSemana.isNotEmpty &&
          _selectedSingleDate == null,
      recorrenciaMensal: false,
      recorrenciaIntervalo: false,
      lembreteUnico: _selectedSingleDate != null || _selectedDiasSemana.isEmpty,
      diasSemana: _selectedDiasSemana,
      diaMes: null,
      intervaloHoras: null,
      dataInicio: (_selectedSingleDate != null || _selectedDiasSemana.isEmpty)
          ? targetDate
          : _dataInicio,
      dataFim: (_selectedSingleDate != null || _selectedDiasSemana.isEmpty)
          ? targetDate
          : ((_isUsoContinuo || _selectedCategory != 'medicacao')
                ? null
                : _dataFim),
      isUsoContinuo:
          (_selectedSingleDate != null || _selectedDiasSemana.isEmpty)
          ? false
          : (_selectedCategory != 'medicacao' ? true : _isUsoContinuo),
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
        SnackBar(
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
