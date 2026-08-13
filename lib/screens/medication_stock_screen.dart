import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/lembrete.dart';
import '../models/stock_movement.dart';
import '../services/lembrete_service.dart';
import '../services/session_role_service.dart';
import '../services/stock_service.dart';
import '../theme/app_theme.dart';
import '../widgets/supervisor_bottom_nav.dart';
import '../widgets/supervisor_drawer.dart';

class MedicationStockScreen extends StatefulWidget {
  const MedicationStockScreen({super.key});

  @override
  State<MedicationStockScreen> createState() => _MedicationStockScreenState();
}

class _MedicationStockScreenState extends State<MedicationStockScreen> {
  bool _loading = true;
  String? _elderlyId;
  String? _busyReminderId;

  @override
  void initState() {
    super.initState();
    LembreteService.instance.notifier.addListener(_onRemindersChanged);
    _load();
  }

  @override
  void dispose() {
    LembreteService.instance.notifier.removeListener(_onRemindersChanged);
    super.dispose();
  }

  void _onRemindersChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final id = await SessionRoleService.getVerifiedActiveIdosoId();
    if (id != null) await LembreteService.instance.carregar();
    if (mounted) {
      setState(() {
        _elderlyId = id;
        _loading = false;
      });
    }
  }

  Future<void> _showReplenishDialog(Lembrete reminder) async {
    final quantityController = TextEditingController();
    final noteController = TextEditingController();
    DateTime? expirationDate;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Repor ${reminder.titulo}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantidade adicionada',
                    hintText: 'Ex.: 30',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) {
                      setDialogState(() => expirationDate = picked);
                    }
                  },
                  icon: const Icon(Icons.event),
                  label: Text(
                    expirationDate == null
                        ? 'Informar validade (opcional)'
                        : DateFormat('dd/MM/yyyy').format(expirationDate!),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Observação (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final quantity = int.tryParse(quantityController.text);
                if (quantity == null || quantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Informe uma quantidade.')),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      quantityController.dispose();
      noteController.dispose();
      return;
    }
    final quantity = int.parse(quantityController.text);
    setState(() => _busyReminderId = reminder.id);
    try {
      final remaining = await StockService.instance.replenish(
        reminder: reminder,
        quantity: quantity,
        expirationDate: expirationDate,
        note: noteController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Novo estoque: $remaining unidade(s).')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível atualizar: $error')),
        );
      }
    } finally {
      quantityController.dispose();
      noteController.dispose();
      if (mounted) setState(() => _busyReminderId = null);
    }
  }

  void _showHistory(Lembrete reminder) {
    final elderlyId = _elderlyId;
    if (elderlyId == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.history, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Histórico — ${reminder.titulo}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<List<StockMovement>>(
                  stream: StockService.instance.watchMovements(
                    elderlyId,
                    reminderId: reminder.id,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text(snapshot.error.toString()));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final movements = snapshot.data!;
                    if (movements.isEmpty) {
                      return const Center(
                        child: Text('Nenhum movimento registrado.'),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: movements.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, index) {
                        final movement = movements[index];
                        final positive = movement.type == 'reposicao';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: positive
                                ? AppColors.successContainer
                                : AppColors.errorContainer,
                            child: Icon(
                              positive ? Icons.add : Icons.remove,
                              color: positive
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                          title: Text(
                            positive
                                ? 'Reposição de ${movement.quantity}'
                                : '${movement.type}: ${movement.quantity}',
                          ),
                          subtitle: Text(
                            '${movement.previousStock} → '
                            '${movement.resultingStock} • '
                            '${DateFormat('dd/MM HH:mm').format(movement.createdAt.toLocal())}',
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final medications =
        LembreteService.instance.lembretes
            .where((item) => item.categoria == LembreteCategoria.medicacao)
            .toList()
          ..sort((a, b) => a.titulo.compareTo(b.titulo));
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const SupervisorDrawer(currentRoute: '/medication-stock'),
      bottomNavigationBar: const SupervisorBottomNav(
        selected: SupervisorNavDestination.none,
      ),
      appBar: AppBar(title: const Text('Estoque de Medicamentos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _elderlyId == null
          ? const _StockEmpty(
              icon: Icons.link_off,
              text: 'Conecte uma pessoa idosa para acompanhar o estoque.',
            )
          : medications.isEmpty
          ? const _StockEmpty(
              icon: Icons.medication_outlined,
              text: 'Nenhum medicamento cadastrado.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: medications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _medicationCard(medications[index]),
              ),
            ),
    );
  }

  Widget _medicationCard(Lembrete reminder) {
    final stock = reminder.medicamentoEstoque;
    final minimum = reminder.medicamentoEstoqueMinimo;
    final days = StockService.instance.estimatedDaysRemaining(reminder);
    final low = stock != null && minimum != null && stock <= minimum;
    final color = stock == 0
        ? AppColors.error
        : low
        ? AppColors.warning
        : AppColors.primary;
    final busy = _busyReminderId == reminder.id;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(Icons.medication, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    reminder.titulo,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (low)
                  Chip(
                    label: Text(stock == 0 ? 'SEM ESTOQUE' : 'ESTOQUE BAIXO'),
                    labelStyle: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                    backgroundColor: color.withValues(alpha: 0.12),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              stock == null
                  ? 'Estoque ainda não informado'
                  : '$stock unidade(s) disponível(is)',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (days != null) ...[
              const SizedBox(height: 4),
              Text(
                days == 0
                    ? 'Pode terminar hoje'
                    : 'Estimativa: aproximadamente $days dia(s)',
              ),
            ],
            if (minimum != null)
              Text('Avisar quando chegar a $minimum unidade(s)'),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: busy ? null : () => _showReplenishDialog(reminder),
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_box),
                  label: const Text('Repor estoque'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showHistory(reminder),
                  icon: const Icon(Icons.history),
                  label: const Text('Histórico'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StockEmpty extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StockEmpty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
