import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../widgets/supervisor_bottom_nav.dart';
import '../widgets/me_explica_button.dart';

class NewReminderScreen extends StatefulWidget {
  const NewReminderScreen({super.key});

  @override
  State<NewReminderScreen> createState() => _NewReminderScreenState();
}

class _NewReminderScreenState extends State<NewReminderScreen> {
  String? _selectedCategory;
  final _titleController = TextEditingController();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  String _selectedForma = 'comprimido';
  String _selectedCor = 'azul';
  String? _audioPath;
  String? _fotoPath;
  String _selectedUrgency = 'normal';
  String _selectedRecorrencia = 'diario';
  List<int> _selectedDiasSemana = [];
  int? _selectedIntervaloHoras = 4;
  int? _selectedDiaMes = 1;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const SupervisorBottomNav(
        selected: SupervisorNavDestination.newReminder,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
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
                    const SizedBox(height: 12),
                    const MeExplicaButton(
                      textoExplicacao:
                          'Nesta tela voce cria um lembrete para o idoso. Escolha a categoria, o horario e, se quiser, grave sua propria voz. Essa voz sera tocada automaticamente quando o lembrete aparecer.',
                    ),
                    const SizedBox(height: 24),
                    _buildCategorySelector(),
                    const SizedBox(height: 24),
                    _buildUrgencySelector(),
                    if (_selectedCategory == 'medicacao') ...[
                      const SizedBox(height: 24),
                      _buildPillAppearanceSelector(),
                      const SizedBox(height: 24),
                      _buildFotoSection(),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'O QUE LEMBRAR?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.05,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        border: Border.all(color: AppColors.outline),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _titleController,
                        style: const TextStyle(fontSize: 18),
                        decoration: const InputDecoration(
                          hintText: 'Ex: Tomar o remédio de pressão',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'HORÁRIO',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.05,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: InkWell(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _selectedTime,
                          );
                          if (time != null)
                            setState(() => _selectedTime = time);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.outlineVariant),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                  letterSpacing: -0.01,
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
                    ),
                    const SizedBox(height: 24),
                    _buildAudioSection(),
                    const SizedBox(height: 24),
                    _buildRecurrenceSection(),
                    const SizedBox(height: 32),
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

  Widget _buildTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          ),
          const Expanded(
            child: Text(
              'Lembrete Amigo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    final categories = [
      {
        'icon': Icons.medication,
        'label': 'Remédio',
        'key': 'medicacao',
        'color': AppColors.medicationsColor,
      },
      {
        'icon': Icons.restaurant,
        'label': 'Refeição',
        'key': 'refeicoes',
        'color': AppColors.mealsColor,
      },
      {
        'icon': Icons.directions_walk,
        'label': 'Exercício',
        'key': 'exercicio',
        'color': AppColors.tertiaryContainer,
      },
      {
        'icon': Icons.water_drop,
        'label': 'Água',
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CATEGORIA DO LEMBRETE',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.05,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: categories.map((cat) {
                final key = cat['key'] as String;
                final color = cat['color'] as Color;
                final selected = _selectedCategory == key;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedCategory = selected ? null : key),
                  child: Container(
                    width: 95,
                    height: 115,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withValues(alpha: 0.2)
                          : AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? color : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: selected
                                ? color
                                : color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            cat['icon'] as IconData,
                            size: 24,
                            color: selected ? Colors.white : color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cat['label'] as String,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected ? color : AppColors.onSurface,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          const Text(
            'ÁUDIO PERSONALIZADO',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.05,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Grave uma frase familiar. Ela sera tocada automaticamente antes do aviso do app.',
            style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
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
            GestureDetector(
              onTap: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/new-reminder-audio',
                );
                if (result is String) {
                  setState(() => _audioPath = result);
                }
              },
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mic,
                  size: 36,
                  color: AppColors.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFotoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FOTO REAL DO REMÉDIO (OPCIONAL)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.05,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tire uma foto da embalagem ou do comprimido real para facilitar a identificação.',
            style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              setState(() {
                if (_fotoPath == null) {
                  _fotoPath =
                      'simulado_remedio_${_selectedForma}_$_selectedCor.png';
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Foto do remédio vinculada com sucesso!'),
                      backgroundColor: AppColors.tertiaryFixedDim,
                    ),
                  );
                } else {
                  _fotoPath = null;
                }
              });
            },
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
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.onTertiaryFixedVariant,
                          size: 36,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Foto Vinculada!',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              'Aparência: $_selectedForma $_selectedCor',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.onSurfaceVariant,
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
      ),
    );
  }

  Widget _buildUrgencySelector() {
    final urgencies = [
      {'key': 'normal', 'label': 'Normal', 'color': Colors.green},
      {'key': 'importante', 'label': 'Importante', 'color': Colors.orange},
      {'key': 'critico', 'label': 'Crítico', 'color': Colors.red},
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NÍVEL DE URGÊNCIA',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.05,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: urgencies.map((u) {
              final selected = _selectedUrgency == u['key'];
              final color = u['color'] as Color;
              return Expanded(
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _selectedUrgency = u['key'] as String),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withValues(alpha: 0.2)
                          : AppColors.surfaceContainerLowest,
                      border: Border.all(
                        color: selected ? color : AppColors.outlineVariant,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        u['label'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: selected ? color : AppColors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurrenceSection() {
    final recorrencias = [
      {'key': 'diario', 'label': 'Diário'},
      {'key': 'semanal', 'label': 'Semanal'},
      {'key': 'intervalo', 'label': 'A cada X horas'},
      {'key': 'quinzenal', 'label': 'A cada 15 dias'},
      {'key': 'mensal', 'label': 'Mensal'},
      {'key': 'unico', 'label': 'Uma vez'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REPETIÇÃO DO LEMBRETE',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.05,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedRecorrencia,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: recorrencias
                .map(
                  (r) => DropdownMenuItem(
                    value: r['key'],
                    child: Text(r['label'] as String),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedRecorrencia = val);
              }
            },
          ),

          if (_selectedRecorrencia == 'semanal') ...[
            const SizedBox(height: 16),
            const Text(
              'Selecione os dias da semana:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (idx) {
                final weekday = idx + 1;
                final labels = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
                final selected = _selectedDiasSemana.contains(weekday);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (selected) {
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
                      color: selected
                          ? AppColors.primary
                          : AppColors.surfaceContainerLowest,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Center(
                      child: Text(
                        labels[idx],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: selected ? Colors.white : AppColors.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],

          if (_selectedRecorrencia == 'intervalo') ...[
            const SizedBox(height: 16),
            const Text(
              'Repetir a cada quantas horas?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedIntervaloHoras,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceContainerLowest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [2, 4, 6, 8, 12]
                        .map(
                          (h) => DropdownMenuItem(
                            value: h,
                            child: Text('$h em $h horas'),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedIntervaloHoras = val);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],

          if (_selectedRecorrencia == 'mensal') ...[
            const SizedBox(height: 16),
            const Text(
              'Qual o dia do mês?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _selectedDiaMes,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceContainerLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: List.generate(31, (i) => i + 1)
                  .map((d) => DropdownMenuItem(value: d, child: Text('Dia $d')))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedDiaMes = val);
                }
              },
            ),
          ],
        ],
      ),
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
          onPressed: _salvarLembrete,
          icon: const Icon(Icons.send),
          label: const Text(
            'Salvar e Enviar',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
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

  Widget _buildPillAppearanceSelector() {
    final formas = [
      {'key': 'comprimido', 'label': 'Comprimido', 'icon': Icons.circle},
      {'key': 'capsula', 'label': 'Cápsula', 'icon': Icons.splitscreen},
      {'key': 'gotas', 'label': 'Gotas', 'icon': Icons.water_drop},
      {'key': 'pomada', 'label': 'Pomada', 'icon': Icons.healing},
    ];

    final cores = [
      {
        'key': 'vermelho',
        'label': 'Vermelho',
        'color': const Color(0xFFE57373),
      },
      {'key': 'azul', 'label': 'Azul', 'color': const Color(0xFF64B5F6)},
      {'key': 'verde', 'label': 'Verde', 'color': const Color(0xFF81C784)},
      {'key': 'amarelo', 'label': 'Amarelo', 'color': const Color(0xFFFFD54F)},
      {'key': 'branco', 'label': 'Branco', 'color': const Color(0xFFEEEEEE)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'APARÊNCIA DO REMÉDIO',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.05,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Formato:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: formas.map((f) {
            final selected = _selectedForma == f['key'];
            return Expanded(
              child: GestureDetector(
                onTap: () =>
                    setState(() => _selectedForma = f['key'] as String),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryContainer
                        : AppColors.surfaceContainerLowest,
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : AppColors.outlineVariant,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        f['icon'] as IconData,
                        color: selected ? Colors.white : AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        f['label'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        const Text(
          'Cor:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: cores.map((c) {
            final selected = _selectedCor == c['key'];
            final color = c['color'] as Color;
            return GestureDetector(
              onTap: () => setState(() => _selectedCor = c['key'] as String),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.primary : Colors.black12,
                    width: selected ? 4 : 2,
                  ),
                ),
                child: selected
                    ? Icon(
                        Icons.check,
                        color: c['key'] == 'branco'
                            ? Colors.black
                            : Colors.white,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _salvarLembrete() async {
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

    if (_selectedRecorrencia == 'semanal' && _selectedDiasSemana.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione pelo menos um dia da semana'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final lembrete = Lembrete(
      id: now.millisecondsSinceEpoch.toString(),
      titulo: titulo,
      horarioHour: _selectedTime.hour,
      horarioMinute: _selectedTime.minute,
      categoria: _selectedCategory ?? 'personalizado',
      audioPath: _audioPath,
      medicamentoForma: _selectedCategory == 'medicacao'
          ? _selectedForma
          : null,
      medicamentoCor: _selectedCategory == 'medicacao' ? _selectedCor : null,
      medicamentoFotoPath: _selectedCategory == 'medicacao' ? _fotoPath : null,
      urgencia: _selectedUrgency,
      recorrencia: _selectedRecorrencia,
      repeteTodosOsDias: _selectedRecorrencia == 'diario',
      recorrenciaSemanal: _selectedRecorrencia == 'semanal',
      recorrenciaMensal: _selectedRecorrencia == 'mensal',
      recorrenciaIntervalo: _selectedRecorrencia == 'intervalo',
      lembreteUnico: _selectedRecorrencia == 'unico',
      diasSemana: _selectedRecorrencia == 'semanal'
          ? _selectedDiasSemana
          : const [],
      diaMes: _selectedRecorrencia == 'mensal' ? _selectedDiaMes : null,
      intervaloHoras: _selectedRecorrencia == 'intervalo'
          ? _selectedIntervaloHoras
          : null,
    );

    try {
      await LembreteService.instance.adicionar(lembrete);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lembrete criado com sucesso!'),
          backgroundColor: AppColors.tertiaryFixedDim,
        ),
      );
      Navigator.pop(context, lembrete);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nao foi possivel salvar o lembrete: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
