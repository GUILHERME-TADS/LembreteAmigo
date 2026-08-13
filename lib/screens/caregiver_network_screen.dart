import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../services/session_role_service.dart';
import '../theme/app_theme.dart';

class CaregiverNetworkScreen extends StatefulWidget {
  const CaregiverNetworkScreen({super.key});

  @override
  State<CaregiverNetworkScreen> createState() => _CaregiverNetworkScreenState();
}

class _CaregiverNetworkScreenState extends State<CaregiverNetworkScreen> {
  bool _loading = true;
  bool _generating = false;
  String? _inviteCode;
  String? _elderlyId;
  List<_CaregiverInfo> _caregivers = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final elderlyId = await SessionRoleService.getActiveIdosoId();
      final snapshot = await FirebaseFirestore.instance
          .collection('idoso_perfil')
          .doc(elderlyId)
          .get();
      final data = snapshot.data() ?? <String, dynamic>{};
      final ids = <String>{
        ...((data['caregiverIds'] as List?) ?? const [])
            .whereType<String>()
            .where((id) => id.isNotEmpty),
        if (data['supervisorId'] is String &&
            (data['supervisorId'] as String).isNotEmpty)
          data['supervisorId'] as String,
      }.toList();
      final roles = data['caregiverRoles'] is Map
          ? Map<String, dynamic>.from(data['caregiverRoles'] as Map)
          : <String, dynamic>{};
      final routing = data['caregiverRouting'] is Map
          ? Map<String, dynamic>.from(data['caregiverRouting'] as Map)
          : <String, dynamic>{};
      final primaryId = data['supervisorId'] as String?;

      final caregivers = <_CaregiverInfo>[];
      for (final id in ids) {
        String name = 'Cuidador';
        try {
          final supervisor = await FirebaseFirestore.instance
              .collection('supervisores')
              .doc(id)
              .get();
          name = supervisor.data()?['nome'] as String? ?? name;
        } catch (_) {}
        final rawRouting = routing[id] is Map
            ? Map<String, dynamic>.from(routing[id] as Map)
            : <String, dynamic>{};
        caregivers.add(
          _CaregiverInfo(
            id: id,
            name: name,
            role:
                roles[id] as String? ??
                (id == primaryId ? 'primary' : 'backup'),
            priority:
                (rawRouting['priority'] as num?)?.toInt() ??
                (id == primaryId ? 1 : caregivers.length + 1),
            availableStart: rawRouting['availableStart'] as String? ?? '00:00',
            availableEnd: rawRouting['availableEnd'] as String? ?? '23:59',
            alertTypes:
                (rawRouting['alertTypes'] as List?)
                    ?.whereType<String>()
                    .toSet() ??
                const {
                  'missed_reminder',
                  'help_request',
                  'device_barrier',
                  'low_stock',
                },
          ),
        );
      }
      caregivers.sort((a, b) => a.priority.compareTo(b.priority));

      if (!mounted) return;
      setState(() {
        _elderlyId = elderlyId;
        _caregivers = caregivers;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível carregar a rede: $error')),
      );
    }
  }

  Future<void> _generateInvite() async {
    if (_generating || _caregivers.length >= 8) return;
    setState(() => _generating = true);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('createPairingCode')
          .call();
      final data = Map<String, dynamic>.from(result.data as Map);
      final code = data['code'] as String?;
      if (code == null || code.length != 6) {
        throw StateError('Código de convite inválido.');
      }
      if (!mounted) return;
      setState(() => _inviteCode = code);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível gerar o convite: $error')),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _removeCaregiver(_CaregiverInfo caregiver) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover cuidador?'),
        content: Text(
          '${caregiver.name} deixará de acompanhar os lembretes e alertas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true || _elderlyId == null) return;

    try {
      await FirebaseFunctions.instance.httpsCallable('unlinkElderly').call({
        'elderlyId': _elderlyId,
        'caregiverId': caregiver.id,
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível remover: $error')),
      );
    }
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 0,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  String _formatTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  Future<void> _editRouting(_CaregiverInfo caregiver) async {
    var priority = caregiver.priority.clamp(1, 8);
    var start = _parseTime(caregiver.availableStart);
    var end = _parseTime(caregiver.availableEnd);
    var alertTypes = Set<String>.from(caregiver.alertTypes);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Alertas para ${caregiver.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: priority,
                  decoration: const InputDecoration(
                    labelText: 'Ordem de contato',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(
                    8,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text('${index + 1}º a receber'),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => priority = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final selected = await showTimePicker(
                            context: context,
                            initialTime: start,
                          );
                          if (selected != null) {
                            setDialogState(() => start = selected);
                          }
                        },
                        child: Text('De ${_formatTime(start)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final selected = await showTimePicker(
                            context: context,
                            initialTime: end,
                          );
                          if (selected != null) {
                            setDialogState(() => end = selected);
                          }
                        },
                        child: Text('Até ${_formatTime(end)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Receber alertas de',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final entry in const {
                  'missed_reminder': 'Lembrete sem resposta',
                  'help_request': 'Pedido de ajuda',
                  'device_barrier': 'Problema no celular',
                  'low_stock': 'Estoque baixo',
                }.entries)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: alertTypes.contains(entry.key),
                    title: Text(entry.value),
                    onChanged: (checked) {
                      setDialogState(() {
                        if (checked == true) {
                          alertTypes.add(entry.key);
                        } else if (alertTypes.length > 1) {
                          alertTypes.remove(entry.key);
                        }
                      });
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'priority': priority,
                'availableStart': _formatTime(start),
                'availableEnd': _formatTime(end),
                'alertTypes': alertTypes.toList(),
              }),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (result == null || _elderlyId == null) return;
    try {
      await FirebaseFunctions.instance
          .httpsCallable('updateCaregiverRouting')
          .call({
            'elderlyId': _elderlyId,
            'caregiverId': caregiver.id,
            ...result,
          });
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar: $error')),
      );
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'primary':
        return 'Principal';
      case 'backup':
        return 'Reserva';
      case 'family':
        return 'Familiar';
      case 'viewer':
        return 'Somente acompanhamento';
      default:
        return 'Cuidador';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minha rede de cuidado')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryFixed,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(Icons.groups_2, size: 52, color: AppColors.primary),
                  SizedBox(height: 8),
                  Text(
                    'Pessoas que ajudam você',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Você pode conectar até 8 cuidadores ou familiares.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_caregivers.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.person_off, size: 34),
                  title: Text('Nenhum cuidador conectado'),
                  subtitle: Text('Gere um convite para começar.'),
                ),
              )
            else
              ..._caregivers.map(
                (caregiver) => Card(
                  child: ListTile(
                    minVerticalPadding: 14,
                    leading: CircleAvatar(
                      child: Text(
                        caregiver.name.isEmpty
                            ? '?'
                            : caregiver.name[0].toUpperCase(),
                      ),
                    ),
                    title: Text(
                      caregiver.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${_roleLabel(caregiver.role)} • '
                      '${caregiver.priority}º • '
                      '${caregiver.availableStart}–${caregiver.availableEnd}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Configurar alertas',
                          onPressed: () => _editRouting(caregiver),
                          icon: const Icon(Icons.tune),
                        ),
                        IconButton(
                          tooltip: 'Remover cuidador',
                          onPressed: () => _removeCaregiver(caregiver),
                          icon: Icon(
                            Icons.person_remove_outlined,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            if (_inviteCode != null)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Mostre este código ao novo cuidador',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      _inviteCode!.split('').join(' '),
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('O código expira em 10 minutos.'),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 68,
              child: FilledButton.icon(
                onPressed: _loading || _generating || _caregivers.length >= 8
                    ? null
                    : _generateInvite,
                icon: const Icon(Icons.person_add_alt_1, size: 28),
                label: Text(
                  _generating ? 'Gerando convite...' : 'Conectar novo cuidador',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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

class _CaregiverInfo {
  final String id;
  final String name;
  final String role;
  final int priority;
  final String availableStart;
  final String availableEnd;
  final Set<String> alertTypes;

  const _CaregiverInfo({
    required this.id,
    required this.name,
    required this.role,
    required this.priority,
    required this.availableStart,
    required this.availableEnd,
    required this.alertTypes,
  });
}
