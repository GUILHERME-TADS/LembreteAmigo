import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/session_role_service.dart';
import '../services/tts_service.dart';
import '../widgets/senior_button.dart';
import '../widgets/volume_warning_banner.dart';
import '../widgets/me_explica_button.dart';

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

  bool _isLoading = true;
  bool _isSaving = false;
  String? _activeIdosoId;

  bool get _useFirebase {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TTSService.instance.falar(
        'Tela de edição de perfil. Modifique os campos que desejar e clique em salvar.',
        caller: this,
      );
    });
  }

  @override
  void dispose() {
    TTSService.instance.parar(caller: this);
    _nameController.dispose();
    _birthDateController.dispose();
    _phoneController.dispose();
    _ambulancePhoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentProfile() async {
    try {
      final idosoId = await _resolveEditableIdosoId();
      if (idosoId == null) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      String nome = '';
      String dataNasc = '';
      String telefone = '';
      String ambulancePhone = '';
      String endereco = '';

      // 1. Sempre carrega os dados locais como fallback/inicialização
      final jsonStr = prefs.getString('idoso_perfil');
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
      if (_useFirebase) {
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
      if (!isConnected || idosoId == SessionRoleService.unpairedIdosoId) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
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

    if (idosoId.isEmpty || idosoId == SessionRoleService.unpairedIdosoId) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nenhum perfil de idoso encontrado para editar.'),
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
        const SnackBar(
          content: Text('Por favor, digite o nome completo do idoso.'),
        ),
      );
      TTSService.instance.falar(
        'Por favor, digite o nome completo do idoso.',
        caller: this,
      );
      return;
    }

    final phoneRegex = RegExp(r'^(\(?\d{2}\)?\s?)?\d{4,5}\-?\d{4}$');
    final dateRegex = RegExp(r'^\d{2}/\d{2}/\d{4}$');

    if (dataNasc.isNotEmpty && !dateRegex.hasMatch(dataNasc)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Use o formato DD/MM/AAAA para a data de nascimento.'),
        ),
      );
      TTSService.instance.falar(
        'A data de nascimento deve estar no formato dia, mês e ano.',
        caller: this,
      );
      return;
    }

    if (telefone.isNotEmpty && !phoneRegex.hasMatch(telefone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, digite um telefone válido.'),
        ),
      );
      TTSService.instance.falar(
        'Por favor, digite um telefone válido.',
        caller: this,
      );
      return;
    }

    if (ambulancePhone.isNotEmpty && !phoneRegex.hasMatch(ambulancePhone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, digite um telefone de ambulância válido.'),
        ),
      );
      TTSService.instance.falar(
        'Por favor, digite um telefone de ambulância válido.',
        caller: this,
      );
      return;
    }

    TTSService.instance.falar(
      'Salvando suas informações, por favor aguarde...',
      caller: this,
    );
    setState(() => _isSaving = true);

    final prefs = await SharedPreferences.getInstance();
    final idosoId = _activeIdosoId ?? await _resolveEditableIdosoId();
    if (idosoId == null) {
      if (mounted) setState(() => _isSaving = false);
      return;
    }

    final Map<String, dynamic> perfil = {};

    final jsonStr = prefs.getString('idoso_perfil');
    if (jsonStr != null) {
      try {
        final existing = jsonDecode(jsonStr) as Map<String, dynamic>;
        perfil.addAll(existing);
      } catch (_) {}
    }

    if (_useFirebase) {
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

    perfil['nome'] = nome;
    perfil['dataNascimento'] = dataNasc;
    perfil['telefone'] = telefone;
    perfil['ambulancia_telefone'] = ambulancePhone;
    perfil['endereco'] = endereco;
    perfil.remove('condicoes');
    if (!SessionRoleService.isSupervisor) {
      perfil.putIfAbsent('status', () => 'pending');
    }

    try {
      // Salva localmente primeiro
      await prefs.setString('idoso_perfil', jsonEncode(perfil));

      // Salva no Firebase de forma confiável
      if (_useFirebase) {
        try {
          await FirebaseFirestore.instance
              .collection('idoso_perfil')
              .doc(idosoId)
              .set(perfil, SetOptions(merge: true));
          await FirebaseFirestore.instance
              .collection('idosos')
              .doc(idosoId)
              .set(perfil, SetOptions(merge: true));
        } catch (firebaseError) {
          debugPrint('Erro ao sincronizar perfil no Firebase: $firebaseError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Dados salvos no aparelho, mas a sincronização com a nuvem falhou. Os dados serão enviados quando houver conexão.',
                ),
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      }

      TTSService.instance.parar(caller: this);
      TTSService.instance.falar('Perfil atualizado com sucesso!', caller: this);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado com sucesso!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Erro ao salvar alterações do perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              TTSService.instance.parar(caller: this);
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.primary,
              size: 36,
            ),
          ),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Editar Perfil',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 6),
              MeExplicaButton(
                textoExplicacao:
                    'Olá! Aqui você altera as suas informações, como seu nome completo, sua data de nascimento, seu telefone e seu endereço. Quando terminar, aperte o botão salvar perfil no final.',
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(width: 48), // Mantém o equilíbrio visual com o botão de voltar no lado oposto
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                          SeniorInputField(
                            label: 'Nome Completo',
                            placeholder: 'Nome do idoso',
                            prefixIcon: Icons.person,
                            controller: _nameController,
                            onTapAudio: () => TTSService.instance.falar(
                              'Digite o seu nome completo nesta caixa.',
                              caller: this,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SeniorInputField(
                            label: 'Data de Nascimento',
                            placeholder: 'DD/MM/AAAA',
                            prefixIcon: Icons.calendar_today,
                            controller: _birthDateController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [DateInputFormatter()],
                            onTapAudio: () => TTSService.instance.falar(
                              'Digite o dia, o mês e o ano em que você nasceu.',
                              caller: this,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SeniorInputField(
                            label: 'Telefone de Contato',
                            placeholder: '(11) 99999-9999',
                            prefixIcon: Icons.phone,
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [PhoneInputFormatter()],
                            onTapAudio: () => TTSService.instance.falar(
                              'Digite o número do seu celular com o D D D.',
                              caller: this,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SeniorInputField(
                            label: 'Telefone da Ambulância',
                            placeholder: 'Número local da ambulância',
                            prefixIcon: Icons.local_hospital,
                            controller: _ambulancePhoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [PhoneInputFormatter()],
                            onTapAudio: () => TTSService.instance.falar(
                              'Digite o telefone da ambulância da sua cidade. Se deixar vazio, a opção de ligar para ambulância não aparece no SOS.',
                              caller: this,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SeniorInputField(
                            label: 'Endereço',
                            placeholder: 'Rua, número, bairro',
                            prefixIcon: Icons.location_on,
                            controller: _addressController,
                            onTapAudio: () => TTSService.instance.falar(
                              'Digite o nome da sua rua e o número da sua casa.',
                              caller: this,
                            ),
                          ),
                          const SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity,
                            height: 64,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _salvar,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondaryContainer,
                                foregroundColor: AppColors.onSecondaryFixed,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              label: Text(
                                _isSaving ? 'SALVANDO...' : 'SALVAR PERFIL',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
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
