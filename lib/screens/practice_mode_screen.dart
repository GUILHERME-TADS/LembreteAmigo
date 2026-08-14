import 'package:flutter/material.dart';

import '../services/tts_service.dart';
import '../theme/app_theme.dart';

class PracticeModeScreen extends StatefulWidget {
  const PracticeModeScreen({super.key});

  @override
  State<PracticeModeScreen> createState() => _PracticeModeScreenState();
}

class _PracticeModeScreenState extends State<PracticeModeScreen> {
  int _step = 0;
  String? _feedback;

  static const _instructions = [
    'Este é um treino. Toque em Já tomei para praticar a confirmação.',
    'Muito bem. Agora toque em Adiar para praticar um novo aviso.',
    'Por último, toque em Pedir ajuda para aprender a chamar o cuidador.',
    'Treino concluído. Nenhum dado real foi alterado.',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
  }

  @override
  void dispose() {
    TTSService.instance.parar(caller: this);
    super.dispose();
  }

  Future<void> _speak() =>
      TTSService.instance.falar(_instructions[_step], caller: this);

  void _handle(int expectedStep, String feedback) {
    if (_step != expectedStep) {
      setState(() => _feedback = 'Siga a orientação destacada acima.');
      _speak();
      return;
    }
    setState(() {
      _step = (_step + 1).clamp(0, 3);
      _feedback = feedback;
    });
    _speak();
  }

  void _restart() {
    setState(() {
      _step = 0;
      _feedback = null;
    });
    _speak();
  }

  @override
  Widget build(BuildContext context) {
    final completed = _step == 3;
    return Scaffold(
      appBar: AppBar(title: const Text('Treinar o aplicativo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.infoContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.info, width: 2),
              ),
              child: Row(
                children: [
                  Icon(Icons.school, color: AppColors.info, size: 40),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'MODO DE TREINO\nNada será salvo ou enviado.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              liveRegion: true,
              label: _instructions[_step],
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Icon(
                        completed ? Icons.verified : Icons.touch_app,
                        color: completed
                            ? AppColors.success
                            : AppColors.primary,
                        size: 56,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        completed
                            ? 'Treino concluído!'
                            : 'Passo ${_step + 1} de 3',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _instructions[_step],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _speak,
                        icon: const Icon(Icons.volume_up),
                        label: const Text('Ouvir novamente'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.medication, size: 38),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Medicamento de treino',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text('08:00 • 1 comprimido'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 62,
                      child: FilledButton.icon(
                        onPressed: completed
                            ? null
                            : () => _handle(
                                0,
                                'Confirmação praticada com sucesso.',
                              ),
                        icon: const Icon(Icons.check_circle, size: 28),
                        label: const Text('Já tomei'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 62,
                      child: OutlinedButton.icon(
                        onPressed: completed
                            ? null
                            : () => _handle(
                                1,
                                'Adiamento praticado com sucesso.',
                              ),
                        icon: const Icon(Icons.snooze, size: 28),
                        label: const Text('Adiar'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 62,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: completed
                            ? null
                            : () => _handle(
                                2,
                                'Pedido de ajuda praticado com sucesso.',
                              ),
                        icon: const Icon(Icons.support_agent, size: 28),
                        label: const Text('Pedir ajuda'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_feedback != null) ...[
              const SizedBox(height: 12),
              Text(
                _feedback!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (completed)
              FilledButton.icon(
                onPressed: _restart,
                icon: const Icon(Icons.replay),
                label: const Text('Treinar novamente'),
              ),
          ],
        ),
      ),
    );
  }
}
