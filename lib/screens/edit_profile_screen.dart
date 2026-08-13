import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../theme/app_theme.dart';
import '../services/session_role_service.dart';
import '../services/elderly_profile_repository.dart';
import '../services/secure_cache_service.dart';
import '../services/tts_service.dart';
import '../services/offline_sync_service.dart';
import '../utils/firebase_helper.dart';
import '../widgets/index.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ambulancePhoneController =
      TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  int? _listeningStep;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _activeIdosoId;
  int _currentStep = 0;

  bool get _useFirebase => FirebaseHelper.isInitialized;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    TTSService.instance.parar(caller: this);
    _speech.stop();
    _nameController.dispose();
    _birthDateController.dispose();
    _phoneController.dispose();
    _ambulancePhoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String _formatSpokenDate(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 8) {
      return '${digits.substring(0, 2)}/${digits.substring(2, 4)}/${digits.substring(4, 8)}';
    }
    return input;
  }

  String _formatSpokenPhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7, 11)}';
    } else if (digits.length == 10) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6, 10)}';
    }
    return input;
  }

  Future<void> _ditarCampo(int step, TextEditingController controller) async {
    await TTSService.instance.parar(caller: this);

    if (_isListening && _listeningStep == step) {
      await _speech.stop();
      SystemSound.play(SystemSoundType.click);
      if (mounted) {
        setState(() {
          _isListening = false;
          _listeningStep = null;
        });
      }
      return;
    }

    try {
      final available = await _speech.initialize(
        onError: (error) {
          debugPrint('Erro no ditado: ${error.errorMsg}');
          if (mounted) {
            if (_isListening && _listeningStep == step) {
              SystemSound.play(SystemSoundType.click);
            }
            setState(() {
              _isListening = false;
              _listeningStep = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Não entendi bem. Tente falar novamente.'),
              ),
            );
          }
        },
        onStatus: (status) {
          final isDone =
              status == stt.SpeechToText.doneStatus ||
              status == stt.SpeechToText.notListeningStatus;
          if (isDone && mounted && _isListening && _listeningStep == step) {
            SystemSound.play(SystemSoundType.click);
            setState(() {
              _isListening = false;
              _listeningStep = null;
            });
          }
        },
      );

      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não consegui ouvir sua voz neste celular.'),
            ),
          );
          TTSService.instance.falar(
            'Não consegui ouvir sua voz neste celular.',
            caller: this,
          );
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        _isListening = true;
        _listeningStep = step;
      });

      SystemSound.play(SystemSoundType.click);

      _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(minutes: 5),
          listenMode: stt.ListenMode.dictation,
          localeId: 'pt_BR',
          cancelOnError: true,
          partialResults: true,
        ),
        onResult: (result) {
          if (!mounted) return;
          String text = result.recognizedWords;
          if (step == 1) {
            text = _formatSpokenDate(text);
          } else if (step == 2 || step == 3) {
            text = _formatSpokenPhone(text);
          }

          setState(() {
            controller.text = text;
            controller.selection = TextSelection.collapsed(
              offset: controller.text.length,
            );
          });

          if (result.finalResult) {
            if (_isListening && _listeningStep == step) {
              SystemSound.play(SystemSoundType.click);
            }
            setState(() {
              _isListening = false;
              _listeningStep = null;
            });
            if (controller.text.isNotEmpty) {
              TTSService.instance.falar(
                'Anotado: ${controller.text}',
                caller: this,
              );
            }
          }
        },
      );
    } catch (e) {
      debugPrint('Erro ao iniciar voz: $e');
      if (mounted) {
        setState(() {
          _isListening = false;
          _listeningStep = null;
        });
      }
    }
  }

  void _speakCurrentStep() {
    String text = '';
    switch (_currentStep) {
      case 0:
        text = 'Primeiro, por favor, digite o seu nome completo nesta caixa.';
        break;
      case 1:
        text = 'Agora, digite o dia, o mês e o ano em que você nasceu.';
        break;
      case 2:
        text = 'Digite o número do seu celular com o código da cidade.';
        break;
      case 3:
        text =
            'Se você tiver, digite o telefone da ambulância da sua cidade. Se não tiver, pode deixar em branco e avançar.';
        break;
      case 4:
        text =
            'Por fim, digite o seu endereço completo com a rua, o número e o bairro, e depois clique no botão salvar.';
        break;
    }
    TTSService.instance.falar(text, caller: this);
  }

  void _avancar() {
    TTSService.instance.parar(caller: this);
    _speech.stop();
    _isListening = false;
    _listeningStep = null;
    if (_currentStep == 0) {
      final nome = _nameController.text.trim();
      if (nome.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, digite seu nome completo.')),
        );
        TTSService.instance.falar(
          'Por favor, digite o seu nome completo.',
          caller: this,
        );
        return;
      }
    } else if (_currentStep == 1) {
      final dataNasc = _birthDateController.text.trim();
      final dateRegex = RegExp(r'^\d{2}/\d{2}/\d{4}$');
      if (dataNasc.isNotEmpty && !dateRegex.hasMatch(dataNasc)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Digite a data assim: dia, mês e ano.')),
        );
        TTSService.instance.falar(
          'Digite a data assim: dia, mês e ano.',
          caller: this,
        );
        return;
      }
    } else if (_currentStep == 2) {
      final telefone = _phoneController.text.trim();
      final phoneRegex = RegExp(r'^(\(?\d{2}\)?\s?)?\d{4,5}\-?\d{4}$');
      if (telefone.isNotEmpty && !phoneRegex.hasMatch(telefone)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Confira o número do telefone.')),
        );
        TTSService.instance.falar(
          'Confira o número do telefone.',
          caller: this,
        );
        return;
      }
    } else if (_currentStep == 3) {
      final ambulancePhone = _ambulancePhoneController.text.trim();
      final phoneRegex = RegExp(r'^(\(?\d{2}\)?\s?)?\d{4,5}\-?\d{4}$');
      if (ambulancePhone.isNotEmpty && !phoneRegex.hasMatch(ambulancePhone)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Confira o número da ambulância.')),
        );
        TTSService.instance.falar(
          'Confira o número da ambulância.',
          caller: this,
        );
        return;
      }
    }

    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
      });
      _speakCurrentStep();
    } else {
      _salvar();
    }
  }

  void _voltar() {
    TTSService.instance.parar(caller: this);
    _speech.stop();
    _isListening = false;
    _listeningStep = null;
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _speakCurrentStep();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _loadCurrentProfile() async {
    try {
      final idosoId = await _resolveEditableIdosoId();
      if (idosoId == null) {
        return;
      }

      final canUseRemoteProfile =
          !SessionRoleService.isElderly ||
          await SessionRoleService.canSyncElderlyPrivateData();
      String nome = '';
      String dataNasc = '';
      String telefone = '';
      String ambulancePhone = '';
      String endereco = '';

      // 1. Sempre carrega os dados locais como fallback/inicialização
      final jsonStr = await SecureCacheService.instance.readElderlyProfile();
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        nome = data['nome'] as String? ?? nome;
        dataNasc = data['dataNascimento'] as String? ?? dataNasc;
        telefone = data['telefone'] as String? ?? telefone;
        ambulancePhone =
            data['ambulancia_telefone'] as String? ?? ambulancePhone;
        endereco = data['endereco'] as String? ?? endereco;
      }

      // 2. Se o Firebase estiver ativo, tenta sincronizar e atualizar com o banco remoto
      if (_useFirebase &&
          canUseRemoteProfile &&
          !SessionRoleService.isLocalOnlyIdosoId(idosoId)) {
        try {
          final docPerfil = await FirebaseFirestore.instance
              .collection('idoso_perfil')
              .doc(idosoId)
              .get();
          final docIdoso = await FirebaseFirestore.instance
              .collection('idosos')
              .doc(idosoId)
              .get();

          if (docIdoso.exists && docIdoso.data() != null) {
            final data = docIdoso.data()!;
            nome = data['nome'] as String? ?? nome;
            dataNasc = data['dataNascimento'] as String? ?? dataNasc;
            telefone = data['telefone'] as String? ?? telefone;
            ambulancePhone =
                data['ambulancia_telefone'] as String? ?? ambulancePhone;
            endereco = data['endereco'] as String? ?? endereco;
          }

          if (docPerfil.exists && docPerfil.data() != null) {
            final data = docPerfil.data()!;
            nome = data['nome'] as String? ?? nome;
            dataNasc = data['dataNascimento'] as String? ?? dataNasc;
            telefone = data['telefone'] as String? ?? telefone;
            ambulancePhone =
                data['ambulancia_telefone'] as String? ?? ambulancePhone;
            endereco = data['endereco'] as String? ?? endereco;
          }
        } catch (firebaseError) {
          debugPrint(
            'Erro ao carregar perfil do Firebase (usando dados locais): $firebaseError',
          );
        }
      }

      if (mounted) {
        setState(() {
          _nameController.text = nome;
          _birthDateController.text = dataNasc;
          _phoneController.text = telefone;
          _ambulancePhoneController.text = ambulancePhone;
          _addressController.text = endereco;
          _isLoading = false;
        });
        _speakCurrentStep();
      }
    } catch (e) {
      debugPrint('Erro ao carregar perfil para edição: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String?> _resolveEditableIdosoId() async {
    await SessionRoleService.load();
    final idosoId = await SessionRoleService.getActiveIdosoId();

    if (SessionRoleService.isSupervisor) {
      final isConnected = await SessionRoleService.isSupervisorConnected();
      if (!isConnected || SessionRoleService.isLocalOnlyIdosoId(idosoId)) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Conecte um dispositivo de idoso antes de alterar os dados.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
          Navigator.pop(context);
        }
        return null;
      }
    }

    if (SessionRoleService.isLocalOnlyIdosoId(idosoId)) {
      final hasLocalProfile =
          await SecureCacheService.instance.readElderlyProfile() != null;
      if (SessionRoleService.isElderly && hasLocalProfile) {
        _activeIdosoId = idosoId;
        return idosoId;
      }

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não encontrei seus dados para editar.'),
            backgroundColor: AppColors.error,
          ),
        );
        Navigator.pop(context);
      }
      return null;
    }

    _activeIdosoId = idosoId;
    return idosoId;
  }

  Future<void> _salvar() async {
    final nome = _nameController.text.trim();
    final dataNasc = _birthDateController.text.trim();
    final telefone = _phoneController.text.trim();
    final ambulancePhone = _ambulancePhoneController.text.trim();
    final endereco = _addressController.text.trim();

    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, digite seu nome completo.')),
      );
      TTSService.instance.falar(
        'Por favor, digite seu nome completo.',
        caller: this,
      );
      return;
    }

    final phoneRegex = RegExp(r'^(\(?\d{2}\)?\s?)?\d{4,5}\-?\d{4}$');
    final dateRegex = RegExp(r'^\d{2}/\d{2}/\d{4}$');

    if (dataNasc.isNotEmpty && !dateRegex.hasMatch(dataNasc)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite a data assim: dia, mês e ano.')),
      );
      TTSService.instance.falar(
        'Digite a data assim: dia, mês e ano.',
        caller: this,
      );
      return;
    }

    if (telefone.isNotEmpty && !phoneRegex.hasMatch(telefone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confira o número do telefone.')),
      );
      TTSService.instance.falar('Confira o número do telefone.', caller: this);
      return;
    }

    if (ambulancePhone.isNotEmpty && !phoneRegex.hasMatch(ambulancePhone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confira o número da ambulância.')),
      );
      TTSService.instance.falar(
        'Confira o número da ambulância.',
        caller: this,
      );
      return;
    }

    TTSService.instance.falar(
      'Salvando seus dados, por favor aguarde...',
      caller: this,
    );
    setState(() => _isSaving = true);

    final idosoId = _activeIdosoId ?? await _resolveEditableIdosoId();
    if (idosoId == null) {
      if (mounted) setState(() => _isSaving = false);
      return;
    }
    final canUseRemoteProfile =
        !SessionRoleService.isElderly ||
        await SessionRoleService.canSyncElderlyPrivateData();

    final Map<String, dynamic> perfil = {};

    final jsonStr = await SecureCacheService.instance.readElderlyProfile();
    if (jsonStr != null) {
      try {
        final existing = jsonDecode(jsonStr) as Map<String, dynamic>;
        perfil.addAll(existing);
      } catch (_) {}
    }

    if (_useFirebase &&
        canUseRemoteProfile &&
        !SessionRoleService.isLocalOnlyIdosoId(idosoId)) {
      try {
        final docPerfil = await FirebaseFirestore.instance
            .collection('idoso_perfil')
            .doc(idosoId)
            .get();
        if (docPerfil.exists && docPerfil.data() != null) {
          perfil.addAll(docPerfil.data()!);
        }
      } catch (_) {}
    }

    final sanitizedPerfil = ElderlyProfileRepository.instance.sanitize(perfil);
    perfil
      ..clear()
      ..addAll(sanitizedPerfil);

    perfil['nome'] = nome;
    perfil['dataNascimento'] = dataNasc;
    perfil['telefone'] = telefone;
    perfil['ambulancia_telefone'] = ambulancePhone;
    perfil['endereco'] = endereco;
    if (!SessionRoleService.isSupervisor) {
      perfil.putIfAbsent('status', () => 'pending');
    }

    try {
      // Salva localmente primeiro
      await SecureCacheService.instance.writeElderlyProfile(jsonEncode(perfil));

      // Salva no Firebase de forma confiável
      if (_useFirebase &&
          canUseRemoteProfile &&
          !SessionRoleService.isLocalOnlyIdosoId(idosoId)) {
        try {
          final profileSynced = await OfflineSyncService.instance.setOrQueue(
            'idoso_perfil',
            idosoId,
            perfil,
          );
          final elderlySynced = await OfflineSyncService.instance.setOrQueue(
            'idosos',
            idosoId,
            perfil,
          );
          if ((!profileSynced || !elderlySynced) && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Dados salvos neste celular. O envio será feito automaticamente quando a internet voltar.',
                ),
                duration: Duration(seconds: 4),
              ),
            );
          }
        } catch (firebaseError) {
          debugPrint('Erro ao sincronizar perfil no Firebase: $firebaseError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Seus dados foram salvos neste celular. Quando a internet voltar, vou avisar o outro celular também.',
                ),
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      }

      TTSService.instance.parar(caller: this);
      TTSService.instance.falar(
        'Pronto. Seus dados foram salvos.',
        caller: this,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pronto. Seus dados foram salvos.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Erro ao salvar alterações do perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não consegui salvar seus dados. Tente de novo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(color: AppColors.surface),
      child: Row(
        children: [
          IconButton(
            onPressed: _voltar,
            icon: Icon(
              Icons.arrow_back,
              color: AppColors.primary,
              size: 36,
            ),
          ),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Meus Dados',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(
            width: 48,
          ), // Mantém o equilíbrio visual com o botão de voltar no lado oposto
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String stepTitle = '';
    Widget currentField = const SizedBox();

    switch (_currentStep) {
      case 0:
        stepTitle = 'Qual o seu nome completo?';
        currentField = SeniorInputField(
          key: const ValueKey('step_0'),
          label: 'Meu nome completo',
          placeholder: 'Meu nome',
          prefixIcon: Icons.person,
          controller: _nameController,
          keyboardType: TextInputType.name,
          onTapAudio: () => TTSService.instance.falar(
            'Digite o seu nome completo nesta caixa ou aperte no microfone para ditar.',
            caller: this,
          ),
          onTapMic: () => _ditarCampo(0, _nameController),
          isListening: _isListening && _listeningStep == 0,
        );
        break;
      case 1:
        stepTitle = 'Quando você nasceu?';
        currentField = SeniorInputField(
          key: const ValueKey('step_1'),
          label: 'Meu nascimento',
          placeholder: 'DD/MM/AAAA',
          prefixIcon: Icons.calendar_today,
          controller: _birthDateController,
          keyboardType: TextInputType.number,
          inputFormatters: [DateInputFormatter()],
          onTapAudio: () => TTSService.instance.falar(
            'Digite o dia, o mês e o ano em que você nasceu ou aperte no microfone para ditar.',
            caller: this,
          ),
          onTapMic: () => _ditarCampo(1, _birthDateController),
          isListening: _isListening && _listeningStep == 1,
        );
        break;
      case 2:
        stepTitle = 'Qual o seu telefone?';
        currentField = SeniorInputField(
          key: const ValueKey('step_2'),
          label: 'Meu telefone',
          placeholder: '(00) 00000-0000',
          prefixIcon: Icons.phone,
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [PhoneInputFormatter()],
          onTapAudio: () => TTSService.instance.falar(
            'Digite o número do seu telefone com DDD ou aperte no microfone para ditar.',
            caller: this,
          ),
          onTapMic: () => _ditarCampo(2, _phoneController),
          isListening: _isListening && _listeningStep == 2,
        );
        break;
      case 3:
        stepTitle = 'Telefone da Ambulância';
        currentField = SeniorInputField(
          key: const ValueKey('step_3'),
          label: 'Telefone da Ambulância',
          placeholder: 'Número local da ambulância',
          prefixIcon: Icons.local_hospital,
          controller: _ambulancePhoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [PhoneInputFormatter()],
          onTapAudio: () => TTSService.instance.falar(
            'Digite o telefone da ambulância da sua cidade ou aperte no microfone para ditar.',
            caller: this,
          ),
          onTapMic: () => _ditarCampo(3, _ambulancePhoneController),
          isListening: _isListening && _listeningStep == 3,
        );
        break;
      case 4:
        stepTitle = 'Qual o seu endereço?';
        currentField = SeniorInputField(
          key: const ValueKey('step_4'),
          label: 'Endereço',
          placeholder: 'Rua, número, bairro',
          prefixIcon: Icons.location_on,
          controller: _addressController,
          keyboardType: TextInputType.streetAddress,
          onTapAudio: () => TTSService.instance.falar(
            'Digite o nome da sua rua e o número da sua casa ou aperte no microfone para ditar.',
            caller: this,
          ),
          onTapMic: () => _ditarCampo(4, _addressController),
          isListening: _isListening && _listeningStep == 4,
        );
        break;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: const AlexFloatingHelpButton(
        textoExplicacao:
            'Olá! Aqui você muda seus dados, como nome, nascimento, telefone e endereço. Quando terminar, aperte o botão salvar no final.',
      ),
      body: SafeArea(
        child: Column(
          children: [
            const VolumeWarningBanner(),
            _buildTopBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final isActive = index == _currentStep;
                              final isCompleted = index < _currentStep;
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                width: 48,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.primary
                                      : (isCompleted
                                            ? AppColors.primary.withValues(
                                                alpha: 0.4,
                                              )
                                            : AppColors.outlineVariant),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            stepTitle,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.outlineVariant,
                                width: 1.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: currentField,
                          ),
                          const SizedBox(height: 48),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 64,
                                  child: OutlinedButton(
                                    onPressed: _voltar,
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: AppColors.outlineVariant,
                                        width: 2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      _currentStep == 0 ? 'CANCELAR' : 'VOLTAR',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: SizedBox(
                                  height: 64,
                                  child: ElevatedButton(
                                    onPressed: _isSaving ? null : _avancar,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _currentStep == 4
                                          ? AppColors.tertiaryFixedDim
                                          : AppColors.secondaryContainer,
                                      foregroundColor: _currentStep == 4
                                          ? AppColors.onTertiaryFixed
                                          : AppColors.onSecondaryFixed,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isSaving
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : Text(
                                            _currentStep == 4
                                                ? 'SALVAR'
                                                : 'AVANÇAR',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class DateInputFormatter extends TextInputFormatter {
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
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i == 2 || i == 4) {
        buffer.write('/');
      }
      if (i < 8) {
        buffer.write(clean[i]);
      }
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class PhoneInputFormatter extends TextInputFormatter {
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
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i == 0) {
        buffer.write('(');
      }
      if (i == 2) {
        buffer.write(') ');
      }
      if (i == 7 && clean.length > 10) {
        buffer.write('-');
      } else if (i == 6 && clean.length <= 10) {
        buffer.write('-');
      }
      if (i < 11) {
        buffer.write(clean[i]);
      }
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
