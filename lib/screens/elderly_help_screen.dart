import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/family_contact.dart';
import '../services/emergency_contact_service.dart';
import '../services/session_role_service.dart';
import '../services/elderly_profile_repository.dart';
import '../services/tts_service.dart';
import '../services/video_call_service.dart';
import '../widgets/index.dart';

class ElderlyHelpScreen extends StatefulWidget {
  const ElderlyHelpScreen({super.key});

  @override
  State<ElderlyHelpScreen> createState() => _ElderlyHelpScreenState();
}

class _ElderlyHelpScreenState extends State<ElderlyHelpScreen> {
  String? _fotoPath;
  String _caregiverName = 'meu cuidador';
  String? _caregiverFoto;
  String? _caregiverPhone;
  List<FamilyContact> _familyContacts = [];
  String? _ambulancePhone;
  bool _isPaired = false;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    _loadProfilePhoto();
    _loadCaregiverInfo();
    _loadAmbulancePhone();
  }

  Future<void> _loadAmbulancePhone() async {
    final phone = await EmergencyContactService.instance.getAmbulancePhone();
    if (mounted) {
      setState(() => _ambulancePhone = phone);
    }
  }

  void _speakUnpairedWarning() {
    TTSService.instance.falar(
      'Esta opção precisa de um cuidador conectado. Por favor, peça para o seu cuidador conectar o celular dele ao seu.',
      caller: this,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Você precisa de um cuidador conectado para usar esta função.',
        ),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _loadCaregiverInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idosoId =
          prefs.getString('paired_idoso_id') ??
          SessionRoleService.unpairedIdosoId;

      final isPaired =
          await SessionRoleService.isElderlyConnectedToSupervisor();

      if (mounted) {
        setState(() {
          _isPaired = isPaired;
        });
      }
      final doc = await ElderlyProfileRepository.instance.getDocument(idosoId);

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final supervisorId = data['supervisorId'];

        if (supervisorId != null) {
          final supDoc = await FirebaseFirestore.instance
              .collection('supervisores')
              .doc(supervisorId)
              .get();
          if (supDoc.exists && supDoc.data() != null) {
            final supData = supDoc.data()!;
            final name = supData['nome'] as String? ?? '';
            final foto = supData['fotoPath'] as String?;
            final phone = supData['telefone'] as String? ?? supData['celular'] as String?;
            if (mounted) {
              setState(() {
                if (name.isNotEmpty) {
                  _caregiverName = name.split(' ').first;
                }
                _caregiverFoto = foto;
                _caregiverPhone = phone;
                _loadFamilyContacts(
                  primaryName: name.isNotEmpty ? name.split(' ').first : _caregiverName,
                  primaryFoto: foto,
                  primaryPhone: phone,
                );
              });
            }
          }
        }
      } else {
        _loadFamilyContacts(
          primaryName: _caregiverName,
          primaryFoto: _caregiverFoto,
          primaryPhone: _caregiverPhone,
        );
      }
    } catch (e) {
      debugPrint('Erro ao carregar cuidador: $e');
      _loadFamilyContacts(
        primaryName: _caregiverName,
        primaryFoto: _caregiverFoto,
        primaryPhone: _caregiverPhone,
      );
    }
  }

  void _loadFamilyContacts({
    required String primaryName,
    String? primaryFoto,
    String? primaryPhone,
  }) {
    // Only real additional contacts if configured in future
    final contacts = <FamilyContact>[];
    if (mounted) {
      setState(() {
        _familyContacts = contacts;
      });
    }
  }

  @override
  void dispose() {
    TTSService.instance.parar(caller: this);
    super.dispose();
  }

  Future<void> _ligarAjudante() async {
    CallingFeedbackDialog.show(
      context,
      contactName: _caregiverName,
      fotoUrl: _caregiverFoto,
      callTypeLabel: 'Ligação de Voz',
      onCallConfirmed: () => _initiateCall('voice'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: const AlexFloatingHelpButton(
        textoExplicacao:
            'Tela de contatos e ajuda. Aqui você pode ligar para o seu cuidador por voz ou vídeo, ouvir recados, ver chamadas ou ligar para a ambulância.',
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
                child: Column(
                  children: [
                    _buildCaregiverHeroCard(context),
                    const SizedBox(height: 18),
                    if (_familyContacts.isNotEmpty) ...[
                      _buildFamilyContactsSection(context),
                      const SizedBox(height: 18),
                    ],
                    _buildCommunicationSection(context),
                    const SizedBox(height: 22),
                    _buildEmergencySection(context),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const ElderlyBottomNav(
        selected: ElderlyNavDestination.help,
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(color: AppColors.surface),
      child: Row(
        children: [
          const SizedBox(width: 56),
          const Spacer(),
          Text(
            'Contatos e Ajuda',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              if (_isProcessingAction) return;
              setState(() => _isProcessingAction = true);
              try {
                TTSService.instance.parar(caller: this);
                await Navigator.pushNamed(context, '/elderly-profile');
                _loadProfilePhoto();
              } finally {
                if (mounted) setState(() => _isProcessingAction = false);
              }
            },
            child: ElderlyProfileAvatar(fotoPath: _fotoPath, size: 56),
          ),
        ],
      ),
    );
  }

  Widget _buildCaregiverHeroCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isPaired
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.outlineVariant,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Status Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _isPaired
                    ? AppColors.successContainer
                    : AppColors.warningContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isPaired
                      ? AppColors.success.withValues(alpha: 0.4)
                      : AppColors.warning.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isPaired
                        ? Icons.check_circle_rounded
                        : Icons.link_off_rounded,
                    size: 18,
                    color: _isPaired
                        ? AppColors.onSuccessContainer
                        : AppColors.onWarningContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isPaired
                        ? 'Cuidador Conectado'
                        : 'Sem cuidador conectado',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _isPaired
                          ? AppColors.onSuccessContainer
                          : AppColors.onWarningContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Foto e Nome do Cuidador
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: _caregiverFoto != null &&
                            _caregiverFoto!.isNotEmpty
                        ? ElderlyProfileAvatar(
                            fotoPath: _caregiverFoto,
                            size: 76,
                            borderWidth: 0,
                          )
                        : Icon(
                            Icons.person,
                            size: 46,
                            color: AppColors.onPrimaryContainer,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _caregiverName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.onSurface,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isPaired
                            ? 'Cuidador Principal'
                            : 'Peça ao cuidador para conectar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Botões de Ação (Voz e Vídeo)
            Row(
              children: [
                // Ligar por Voz
                Expanded(
                  child: SizedBox(
                    height: 64,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (!_isPaired) {
                          _speakUnpairedWarning();
                          return;
                        }
                        _ligarAjudante();
                      },
                      icon: const Icon(Icons.call, size: 26),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Ligar (Voz)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Chamada de Vídeo
                Expanded(
                  child: SizedBox(
                    height: 64,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (!_isPaired) {
                          _speakUnpairedWarning();
                          return;
                        }
                        _initiateCall('video');
                      },
                      icon: const Icon(Icons.videocam_rounded, size: 28),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Vídeo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunicationSection(BuildContext context) {
    return Row(
      children: [
        // Recados e Mensagens
        Expanded(
          child: Material(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                if (_isProcessingAction) return;
                if (!_isPaired) {
                  _speakUnpairedWarning();
                  return;
                }
                setState(() => _isProcessingAction = true);
                try {
                  await TTSService.instance.falar(
                    'Abrindo os recados do seu cuidador.',
                    caller: this,
                  );
                  if (context.mounted) {
                    await Navigator.pushNamed(context, '/messages');
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isProcessingAction = false);
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.35),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    MessageUnreadBadge(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.infoContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chat_bubble_rounded,
                          size: 28,
                          color: AppColors.info,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Recados',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ouvir mensagens',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Histórico de Ligações
        Expanded(
          child: Material(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                if (_isProcessingAction) return;
                setState(() => _isProcessingAction = true);
                try {
                  await TTSService.instance.falar(
                    'Abrindo o seu histórico de ligações.',
                    caller: this,
                  );
                  if (context.mounted) {
                    await Navigator.pushNamed(context, '/video-call-history');
                  }
                } finally {
                  if (mounted) setState(() => _isProcessingAction = false);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.outlineVariant,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    MissedCallsBadge(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.customContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.history_rounded,
                          size: 28,
                          color: AppColors.onCustomContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Histórico',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Quem ligou',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyContactsSection(BuildContext context) {
    if (_familyContacts.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outlineVariant, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.family_restroom_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Outros Contatos da Família',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _familyContacts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final contact = _familyContacts[index];
              return InkWell(
                onTap: () {
                  CallingFeedbackDialog.show(
                    context,
                    contactName: contact.nome,
                    fotoUrl: contact.fotoUrl,
                    callTypeLabel: contact.parentesco,
                    onCallConfirmed: () {
                      if (contact.telefone.isNotEmpty) {
                        _ligar(contact.telefone);
                      } else {
                        _initiateCall('voice');
                      }
                    },
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      ElderlyProfileAvatar(
                        fotoPath: contact.fotoUrl,
                        size: 48,
                        borderWidth: 1,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contact.nome,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              contact.parentesco,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.call,
                          color: AppColors.onPrimaryContainer,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencySection(BuildContext context) {
    final String? phone = _ambulancePhone?.trim();
    final bool hasPhone = phone != null && phone.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.error, width: 2.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emergency_rounded,
                color: AppColors.error,
                size: 26,
              ),
              const SizedBox(width: 8),
              Text(
                'Em Caso de Emergência',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton.icon(
              onPressed: hasPhone
                  ? () async {
                      await TTSService.instance.falar(
                        'Iniciando ligação para a ambulância.',
                        caller: this,
                      );
                      _ligar(phone);
                    }
                  : () async {
                      TTSService.instance.falar(
                        'O número da ambulância ainda não foi configurado. Por favor, cadastre o número.',
                        caller: this,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Configure o número da ambulância antes de ligar.',
                            ),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                      _abrirDialogoConfigurarAmbulancia();
                    },
              icon: Icon(
                hasPhone ? Icons.local_hospital_rounded : Icons.add_call,
                size: 28,
                color: Colors.white,
              ),
              label: Text(
                hasPhone
                    ? 'Ligar para Ambulância'
                    : 'Configurar Ambulância',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          if (hasPhone) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: _abrirDialogoConfigurarAmbulancia,
              icon: Icon(
                Icons.edit,
                size: 16,
                color: AppColors.error,
              ),
              label: Text(
                'Editar número da ambulância',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.error,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'Toque acima para cadastrar o telefone',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _abrirDialogoConfigurarAmbulancia() async {
    final controller = TextEditingController(text: _ambulancePhone ?? '');
    final stt.SpeechToText speech = stt.SpeechToText();
    bool isListening = false;

    // Anuncia imediatamente ao abrir
    TTSService.instance.falar(
      'Por favor, digite o número da ambulância local ou aperte no microfone para falar o número.',
      caller: this,
    );

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: AppColors.background,
              title: Text(
                'Número da Emergência',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Digite o número de emergência ou ambulância da sua região.',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SeniorInputField(
                    label: 'Ambulância / Emergência',
                    placeholder: 'Digite o telefone',
                    prefixIcon: Icons.local_hospital,
                    controller: controller,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [AmbulancePhoneInputFormatter()],
                    isListening: isListening,
                    onTapAudio: () {
                      TTSService.instance.falar(
                        'Digite o número da ambulância local ou aperte no microfone para ditar o número em voz alta.',
                        caller: this,
                      );
                    },
                    onTapMic: () async {
                      await TTSService.instance.parar(caller: this);
                      if (isListening) {
                        await speech.stop();
                        SystemSound.play(SystemSoundType.click);
                        setDialogState(() => isListening = false);
                        return;
                      }
                      try {
                        final available = await speech.initialize(
                          onError: (e) {
                            if (isListening) {
                              SystemSound.play(SystemSoundType.click);
                            }
                            setDialogState(() => isListening = false);
                          },
                          onStatus: (status) {
                            if (status == stt.SpeechToText.doneStatus ||
                                status == stt.SpeechToText.notListeningStatus) {
                              if (isListening) {
                                SystemSound.play(SystemSoundType.click);
                              }
                              setDialogState(() => isListening = false);
                            }
                          },
                        );
                        if (available) {
                          setDialogState(() => isListening = true);
                          SystemSound.play(SystemSoundType.click);
                          speech.listen(
                            listenOptions: stt.SpeechListenOptions(
                              listenMode: stt.ListenMode.dictation,
                              localeId: 'pt_BR',
                            ),
                            onResult: (result) {
                              String text = result.recognizedWords;
                              text = text.replaceAll(RegExp(r'\D'), '');
                              final formatter = AmbulancePhoneInputFormatter();
                              final formattedValue = formatter.formatEditUpdate(
                                TextEditingValue.empty,
                                TextEditingValue(text: text),
                              );
                              controller.value = formattedValue;
                              if (result.finalResult) {
                                if (isListening) {
                                  SystemSound.play(SystemSoundType.click);
                                }
                                setDialogState(() => isListening = false);
                                if (controller.text.isNotEmpty) {
                                  TTSService.instance.falar(
                                    'Anotado: ${controller.text}',
                                    caller: this,
                                  );
                                }
                              }
                            },
                          );
                        } else {
                          TTSService.instance.falar(
                            'Não consegui ouvir sua voz neste celular.',
                            caller: this,
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isListening = false);
                      }
                    },
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actions: [
                TextButton(
                  onPressed: () {
                    TTSService.instance.parar(caller: this);
                    if (isListening) speech.stop();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    TTSService.instance.parar(caller: this);
                    if (isListening) speech.stop();
                    final num = controller.text.trim();
                    if (num.isNotEmpty) {
                      await EmergencyContactService.instance.saveAmbulancePhone(
                        num,
                      );
                      if (mounted) {
                        setState(() {
                          _ambulancePhone = num;
                        });
                      }
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Salvar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _loadProfilePhoto() async {
    try {
      final localFoto = await ElderlyProfileRepository.instance
          .getCachedPhotoPath();
      if (mounted) {
        setState(() {
          _fotoPath = localFoto;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar foto no help: $e');
    }
  }

  void _ligar(String numero) async {
    if (_isProcessingAction) return;
    setState(() => _isProcessingAction = true);
    try {
      final Uri launchUri = Uri(scheme: 'tel', path: numero);
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não consegui abrir a ligação no celular.'),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _initiateCall(String callType) async {
    if (_isProcessingAction) return;
    setState(() => _isProcessingAction = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final idosoId = prefs.getString('paired_idoso_id');
      if (idosoId == null || idosoId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhum cuidador conectado.')),
          );
        }
        return;
      }
      final callStart = await VideoCallService.instance.initiateCall(
        idosoId: idosoId,
        initiatedBy: 'sos',
        callType: callType,
      );
      if (callStart != null && mounted) {
        await VideoCallService.instance.joinCall(
          callStart.roomName,
          callType: callType,
          callId: callStart.callId,
          alreadyVerified: true,
        );
      } else if (mounted) {
        final label = callType == 'voice' ? 'voz' : 'vídeo';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não consegui começar a ligação de $label.')),
        );
      }
    } catch (e) {
      if (mounted) {
        final label = callType == 'voice' ? 'voz' : 'vídeo';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não consegui começar a ligação de $label.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }
}

class AmbulancePhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.length < oldValue.text.length) {
      return newValue;
    }
    final clean = text.replaceAll(RegExp(r'\D'), '');

    // Se for um número de emergência curto (3 a 4 dígitos) não coloca parênteses
    if (clean.length <= 4) {
      return TextEditingValue(
        text: clean,
        selection: TextSelection.collapsed(offset: clean.length),
      );
    }

    // Formata no padrão de telefone/celular: (XX) XXXXX-XXXX
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i == 0) buffer.write('(');
      if (i == 2) buffer.write(') ');
      if (i == 7 && clean.length > 10) {
        buffer.write('-');
      } else if (i == 6 && clean.length <= 10) {
        buffer.write('-');
      }
      if (i < 11) buffer.write(clean[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
