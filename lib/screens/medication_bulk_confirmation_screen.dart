import 'package:flutter/material.dart';
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../services/prescription_parser_service.dart';
import '../theme/app_theme.dart';

class MedicationBulkConfirmationScreen extends StatefulWidget {
  final List<PrescriptionReminderItem> initialItems;

  const MedicationBulkConfirmationScreen({
    super.key,
    required this.initialItems,
  });

  @override
  State<MedicationBulkConfirmationScreen> createState() =>
      _MedicationBulkConfirmationScreenState();
}

class _EditablePrescriptionItem {
  bool selected;
  final TextEditingController titleController;
  final TextEditingController dosageController;
  final TextEditingController obsController;
  TimeOfDay time;

  _EditablePrescriptionItem({
    required String title,
    required String dosage,
    required String obs,
    required this.time,
  }) : selected = true,
       titleController = TextEditingController(text: title),
       dosageController = TextEditingController(text: dosage),
       obsController = TextEditingController(text: obs);

  void dispose() {
    titleController.dispose();
    dosageController.dispose();
    obsController.dispose();
  }
}

class _MedicationBulkConfirmationScreenState
    extends State<MedicationBulkConfirmationScreen> {
  final List<_EditablePrescriptionItem> _items = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (final item in widget.initialItems) {
      _items.add(
        _EditablePrescriptionItem(
          title: item.titulo,
          dosage: item.dosagem,
          obs: item.observacoes,
          time: TimeOfDay(hour: item.horarioHour, minute: item.horarioMinute),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _selectTime(
    BuildContext context,
    _EditablePrescriptionItem item,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: item.time,
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
    if (picked != null) {
      setState(() {
        item.time = picked;
      });
    }
  }

  Future<void> _salvarLembretes() async {
    final selectedItems = _items.where((i) => i.selected).toList();
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selecione pelo menos um medicamento para salvar.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      int index = 0;
      for (final item in selectedItems) {
        final uniqueId = '${now.millisecondsSinceEpoch}_${index++}';

        final String fullTitle = item.titleController.text.trim();
        final lembrete = Lembrete(
          id: uniqueId,
          titulo: fullTitle,
          horarioHour: item.time.hour,
          horarioMinute: item.time.minute,
          categoria: 'medicacao',
          recorrencia: 'diario',
          repeteTodosOsDias: true,
        );

        await LembreteService.instance.adicionar(lembrete);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${selectedItems.length} lembretes criados com sucesso!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar lembretes: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Confirmar Receita')),
      body: SafeArea(
        child: _items.isEmpty
            ? Center(
                child: Text(
                  'Nenhum medicamento encontrado na receita.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: item.selected
                                  ? AppColors.primary
                                  : AppColors.outlineVariant,
                              width: item.selected ? 2 : 1,
                            ),
                          ),
                          color: item.selected
                              ? AppColors.surfaceContainerLowest
                              : AppColors.surfaceContainerLow,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: item.selected,
                                      activeColor: AppColors.primary,
                                      onChanged: (val) {
                                        setState(() {
                                          item.selected = val ?? false;
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: item.titleController,
                                        decoration: const InputDecoration(
                                          labelText: 'Nome do Remédio',
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.onSurface,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: AppColors.error,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _items.removeAt(index);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: item.dosageController,
                                        decoration: const InputDecoration(
                                          labelText: 'Dosagem (ex: 50mg)',
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                        ),
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: AppColors.onSurface,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    InkWell(
                                      onTap: () => _selectTime(context, item),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              size: 18,
                                              color:
                                                  AppColors.onPrimaryContainer,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${item.time.hour.toString().padLeft(2, '0')}:${item.time.minute.toString().padLeft(2, '0')}',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors
                                                    .onPrimaryContainer,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: item.obsController,
                                  decoration: const InputDecoration(
                                    labelText: 'Instruções / Frequência',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _salvarLembretes,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Icon(Icons.check_circle, size: 28),
                        label: Text(
                          _isSaving ? 'SALVANDO...' : 'CRIAR LEMBRETES',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
