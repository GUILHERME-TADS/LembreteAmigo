import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:qr/qr.dart';
import 'package:share_plus/share_plus.dart';

import '../models/emergency_card.dart';
import '../services/emergency_card_service.dart';
import '../services/lembrete_service.dart';

class EmergencyCardScreen extends StatefulWidget {
  const EmergencyCardScreen({super.key});

  @override
  State<EmergencyCardScreen> createState() => _EmergencyCardScreenState();
}

class _EmergencyCardScreenState extends State<EmergencyCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _noteController = TextEditingController();
  final Set<String> _selectedMedications = <String>{};

  EmergencyCard? _card;
  List<String> _availableMedications = const [];
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _allergiesController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final card = await EmergencyCardService.instance.load();
    final medications =
        LembreteService.instance.lembretes
            .where((item) => item.categoria == 'medicacao')
            .map((item) => item.titulo.trim())
            .where((title) => title.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    if (!mounted) return;
    _fill(card);
    setState(() {
      _card = card;
      _availableMedications = medications;
      _loading = false;
    });
  }

  void _fill(EmergencyCard card) {
    _nameController.text = card.name;
    _allergiesController.text = card.allergies;
    _contactNameController.text = card.contactName;
    _contactPhoneController.text = card.contactPhone;
    _noteController.text = card.note;
    _selectedMedications
      ..clear()
      ..addAll(card.medications);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final card = EmergencyCard(
      name: _nameController.text.trim(),
      allergies: _allergiesController.text.trim(),
      medications: _selectedMedications.take(10).toList(growable: false),
      contactName: _contactNameController.text.trim(),
      contactPhone: _contactPhoneController.text.trim(),
      note: _noteController.text.trim(),
      updatedAt: DateTime.now(),
    );
    await EmergencyCardService.instance.save(card);
    if (!mounted) return;
    setState(() {
      _card = card;
      _editing = false;
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cartão de emergência salvo neste aparelho.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartão de emergência'),
        actions: [
          if (_card != null && !_editing)
            IconButton(
              tooltip: 'Compartilhar texto',
              icon: const Icon(Icons.share_outlined),
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text: EmergencyCardService.instance.shareText(_card!),
                  subject: 'Cartão de emergência',
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _privacyNotice(),
                  const SizedBox(height: 16),
                  if (_editing) _editForm() else _cardView(_card!),
                ],
              ),
            ),
      floatingActionButton: _loading || _editing
          ? null
          : FloatingActionButton.extended(
              onPressed: () => setState(() => _editing = true),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar'),
            ),
    );
  }

  Widget _privacyNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondaryContainer),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: AppColors.onWarningContainer),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Funciona sem internet. Os dados ficam neste aparelho, mas qualquer pessoa que escanear o QR poderá lê-los.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardView(EmergencyCard card) {
    final payload = EmergencyCardService.instance.qrPayload(card);
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.error, AppColors.errorContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              const Icon(
                Icons.health_and_safety,
                color: Colors.white,
                size: 44,
              ),
              const SizedBox(height: 8),
              Text(
                card.name.isEmpty ? 'Nome não informado' : card.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 230,
                height: 230,
                padding: const EdgeInsets.all(10),
                color: Colors.white,
                child: CustomPaint(painter: _QrPainter(payload)),
              ),
              const SizedBox(height: 12),
              const Text(
                'ESCANEIE EM CASO DE EMERGÊNCIA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () => _showEmergencyFullscreen(card, payload),
                icon: const Icon(Icons.fullscreen, color: Colors.black),
                label: const Text(
                  'Modo Socorrista / Tela Cheia 🚨',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _infoTile(
          Icons.warning_amber,
          'Alergias',
          card.allergies.isEmpty ? 'Não informadas' : card.allergies,
        ),
        _infoTile(
          Icons.medication_outlined,
          'Medicamentos',
          card.medications.isEmpty
              ? 'Não informados'
              : card.medications.join(', '),
        ),
        _infoTile(
          Icons.phone_in_talk_outlined,
          'Contato',
          '${card.contactName} — ${card.contactPhone}',
        ),
        if (card.note.isNotEmpty)
          _infoTile(Icons.notes_outlined, 'Observação', card.note),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Atualizado em ${DateFormat('dd/MM/yyyy HH:mm').format(card.updatedAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  void _showEmergencyFullscreen(EmergencyCard card, String payload) {
    showDialog(
      context: context,
      builder: (context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          elevation: 2,
          title: const Text(
            'FICHA MÉDICA DE EMERGÊNCIA',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  card.name.isEmpty ? 'PACIENTE IDOSO' : card.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Contato de Emergência: ${card.contactName} (${card.contactPhone})',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (card.allergies.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'ALERGIAS: ${card.allergies.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.onErrorContainer,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.outlineVariant, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow.withValues(alpha: 0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CustomPaint(painter: _QrPainter(payload)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Aponte a câmera de qualquer celular para ler a ficha completa.',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Fechar Ficha Médica',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(value),
      ),
    );
  }

  Widget _editForm() {
    final medications = <String>{
      ..._availableMedications,
      ..._selectedMedications,
    }.toList()..sort();
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            _nameController,
            'Nome completo',
            required: true,
            maxLength: 100,
          ),
          _field(
            _allergiesController,
            'Alergias importantes',
            maxLength: 500,
            maxLines: 3,
          ),
          const Text(
            'Medicamentos em uso',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          if (medications.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Cadastre lembretes de medicamentos para incluí-los aqui.',
              ),
            )
          else
            Wrap(
              spacing: 8,
              children: medications
                  .map(
                    (medicine) => FilterChip(
                      label: Text(medicine),
                      selected: _selectedMedications.contains(medicine),
                      onSelected: (selected) {
                        setState(() {
                          if (selected && _selectedMedications.length < 10) {
                            _selectedMedications.add(medicine);
                          } else if (!selected) {
                            _selectedMedications.remove(medicine);
                          }
                        });
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
          const SizedBox(height: 16),
          _field(
            _contactNameController,
            'Nome do contato de emergência',
            required: true,
            maxLength: 100,
          ),
          _field(
            _contactPhoneController,
            'Telefone do contato',
            required: true,
            maxLength: 30,
            keyboardType: TextInputType.phone,
          ),
          _field(
            _noteController,
            'Observação importante',
            maxLength: 500,
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Salvar cartão'),
          ),
          TextButton(
            onPressed: _saving
                ? null
                : () {
                    _fill(_card!);
                    setState(() => _editing = false);
                  },
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int maxLength = 100,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLength: maxLength,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                  ? 'Preencha este campo.'
                  : null
            : null,
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  final String payload;

  _QrPainter(this.payload);

  @override
  void paint(Canvas canvas, Size size) {
    final code = QrCode.fromData(
      data: payload,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final image = QrImage(code);
    final cell = size.shortestSide / image.moduleCount;
    final paint = Paint()..color = Colors.black;
    for (var row = 0; row < image.moduleCount; row++) {
      for (var column = 0; column < image.moduleCount; column++) {
        if (image.isDark(row, column)) {
          canvas.drawRect(
            Rect.fromLTWH(column * cell, row * cell, cell + 0.25, cell + 0.25),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) =>
      oldDelegate.payload != payload;
}
