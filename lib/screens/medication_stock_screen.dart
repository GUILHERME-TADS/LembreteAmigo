import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

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

  Future<void> _shareShoppingList(List<Lembrete> medications) async {
    if (medications.isEmpty) return;
    final buffer = StringBuffer();
    buffer.writeln('🛒 *Lista de Medicamentos para Reposição / Farmácia*');
    buffer.writeln('📅 Data: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}');
    buffer.writeln('------------------------------------------');

    final urgent = <Lembrete>[];
    final normal = <Lembrete>[];

    for (final med in medications) {
      final stock = med.medicamentoEstoque;
      final minimum = med.medicamentoEstoqueMinimo;
      final low = stock != null && minimum != null && stock <= minimum;
      if (stock == 0 || low) {
        urgent.add(med);
      } else {
        normal.add(med);
      }
    }

    if (urgent.isNotEmpty) {
      buffer.writeln('\n🚨 *PRECISAM DE REPOSIÇÃO URGENTE:*');
      for (final med in urgent) {
        final days = StockService.instance.estimatedDaysRemaining(med);
        final daysStr = days != null ? ' (~$days dia(s) restante(s))' : '';
        final stock = med.medicamentoEstoque ?? 0;
        buffer.writeln('• *${med.titulo}* — Restam: $stock un.$daysStr');
      }
    }

    if (normal.isNotEmpty) {
      buffer.writeln('\n✅ *DEMAIS MEDICAMENTOS EM ESTOQUE:*');
      for (final med in normal) {
        final days = StockService.instance.estimatedDaysRemaining(med);
        final daysStr = days != null ? ' (~$days dia(s))' : '';
        final stock = med.medicamentoEstoque != null ? '${med.medicamentoEstoque} un.' : 'Não informado';
        buffer.writeln('• ${med.titulo} — Estoque: $stock$daysStr');
      }
    }

    buffer.writeln('\n------------------------------------------');
    buffer.writeln('Gerado pelo aplicativo *Lembrete Amigo* 💙');

    await SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        subject: 'Lista de Farmácia - Lembrete Amigo',
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
      appBar: AppBar(
        title: const Text('Estoque de Medicamentos'),
        actions: [
          if (medications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Compartilhar Lista de Compras',
              onPressed: () => _shareShoppingList(medications),
            ),
        ],
      ),
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
    final minimum = reminder.medicamentoEstoqueMinimo ?? 5;
    final days = StockService.instance.estimatedDaysRemaining(reminder);
    final low = stock != null && stock <= minimum;
    final isZero = stock == 0;

    final Color statusColor = isZero
        ? AppColors.error
        : low
            ? AppColors.warning
            : AppColors.success;

    final busy = _busyReminderId == reminder.id;
    final maxCapacity = ((minimum * 4).clamp(30, 100)).toDouble();
    final progress = stock != null ? (stock / maxCapacity).clamp(0.0, 1.0) : 0.5;

    return Container(
      decoration: AppDecorations.blisterCard(statusColor: statusColor),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(Icons.medication_rounded, color: statusColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.titulo,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      if (reminder.medicamentoDose != null && reminder.medicamentoDose!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Dose: ${reminder.medicamentoDose}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    isZero
                        ? 'SEM ESTOQUE'
                        : low
                            ? 'ESTOQUE BAIXO'
                            : 'EM DIA',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  stock == null
                      ? 'Estoque não informado'
                      : '$stock unidades disponíveis',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (days != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      days == 0 ? 'Acaba hoje' : 'Acaba em ~$days dias',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Barra de Nível Visual do Medicamento
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: stock == null ? 0.0 : progress,
                minHeight: 10,
                backgroundColor: AppColors.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Aviso configurado para mínimo de $minimum unidades',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : () => _showReplenishDialog(reminder),
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add_circle_outline, size: 20),
                    label: const Text(
                      'Repor',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => _showHistory(reminder),
                  icon: const Icon(Icons.history, size: 20),
                  label: const Text('Histórico'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
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
