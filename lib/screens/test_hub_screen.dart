import 'package:flutter/material.dart';

import '../services/test_hub_service.dart';
import '../theme/app_theme.dart';

class TestHubScreen extends StatefulWidget {
  const TestHubScreen({super.key});

  @override
  State<TestHubScreen> createState() => _TestHubScreenState();
}

class _TestHubScreenState extends State<TestHubScreen> {
  bool _isLoading = false;
  String? _statusMessage;
  bool _isSuccess = true;

  @override
  Widget build(BuildContext context) {
    final hasMock = TestHubService.instance.hasMockData();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Central de Testes & Simulações',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
          children: [
            _buildIntroBanner(),
            const SizedBox(height: 20),

            if (_statusMessage != null) ...[
              _buildFeedbackBanner(),
              const SizedBox(height: 20),
            ],

            _buildSectionHeader(
              icon: Icons.notifications_active_rounded,
              title: '1. SIMULAÇÃO DE DISPAROS EM TEMPO REAL',
              subtitle: 'Dispare eventos imediatos para validar áudio, vibração e interface.',
            ),
            const SizedBox(height: 12),
            _buildTriggerCards(),

            const SizedBox(height: 28),
            _buildSectionHeader(
              icon: Icons.health_and_safety_rounded,
              title: '2. DIAGNÓSTICO DE HARDWARE & SISTEMA',
              subtitle: 'Valide os componentes físicos e canais de comunicação do celular.',
            ),
            const SizedBox(height: 12),
            _buildHardwareCards(),

            const SizedBox(height: 28),
            _buildSectionHeader(
              icon: Icons.dataset_rounded,
              title: '3. SANDBOX DE DADOS DE DEMONSTRAÇÃO',
              subtitle: 'Popule dados fictícios para testar relatórios mensais e gráficos.',
            ),
            const SizedBox(height: 12),
            _buildSandboxCard(hasMock),

            const SizedBox(height: 28),
            _buildSectionHeader(
              icon: Icons.school_rounded,
              title: '4. PRÁTICA & TREINAMENTO',
              subtitle: 'Treine o idoso com simulações guiadas passo a passo.',
            ),
            const SizedBox(height: 12),
            _buildPracticeModeCard(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.science_rounded,
              color: AppColors.onPrimary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ambiente de Testes do LembreteAmigo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Use esta central para comprovar que o aparelho tocará no momento certo e que todos os fluxos de segurança estão 100% operacionais.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isSuccess
            ? AppColors.successContainer
            : AppColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isSuccess
              ? AppColors.success
              : AppColors.error,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
            color: _isSuccess ? AppColors.onSuccessContainer : AppColors.onErrorContainer,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusMessage!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _isSuccess ? AppColors.onSuccessContainer : AppColors.onErrorContainer,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _statusMessage = null),
            color: AppColors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildTriggerCards() {
    return Column(
      children: [
        _buildActionTile(
          icon: Icons.alarm_add_rounded,
          iconColor: AppColors.primary,
          title: 'Disparar Alarme Imediato',
          description: 'Abre a tela de alarme com som, vibração e TTS de voz como se o horário tivesse chegado.',
          buttonText: 'Testar Alarme',
          onTap: () async {
            _showFeedback('Alarme de teste disparado!');
            await TestHubService.instance.simulateAlarmNow(requirePhoto: false);
          },
        ),
        const SizedBox(height: 10),
        _buildActionTile(
          icon: Icons.camera_alt_rounded,
          iconColor: AppColors.tertiary,
          title: 'Alarme com Foto Obrigatória',
          description: 'Simula medicamento com comprovação por foto para validar a câmera e o enquadramento.',
          buttonText: 'Testar com Foto',
          onTap: () async {
            _showFeedback('Alarme com foto disparado!');
            await TestHubService.instance.simulateAlarmNow(requirePhoto: true);
          },
        ),
        const SizedBox(height: 10),
        _buildActionTile(
          icon: Icons.emergency_rounded,
          iconColor: AppColors.error,
          title: 'Simular Pedido de Socorro (SOS)',
          description: 'Simula o acionamento do botão "Preciso de Ajuda" do idoso e exibe o alerta de emergência.',
          buttonText: 'Simular SOS',
          onTap: () async {
            _showFeedback('Alerta de emergência simulado!');
            await TestHubService.instance.simulateEmergencySOS();
          },
        ),
        const SizedBox(height: 10),
        _buildActionTile(
          icon: Icons.video_call_rounded,
          iconColor: AppColors.medicationsColor,
          title: 'Simular Chamada de Vídeo Recebida',
          description: 'Abre a tela de toque de chamada recebida com botões gigantes de atender e recusar.',
          buttonText: 'Simular Chamada',
          onTap: () async {
            _showFeedback('Chamada de vídeo recebida simulada!');
            await TestHubService.instance.simulateIncomingVideoCall();
          },
        ),
      ],
    );
  }

  Widget _buildHardwareCards() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMiniTestButton(
                  icon: Icons.volume_up_rounded,
                  label: 'Ouvir Voz TTS',
                  color: AppColors.primary,
                  onTap: () async {
                    _showFeedback('Reproduzindo áudio do sintetizador de voz...');
                    await TestHubService.instance.testAudioVoice();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniTestButton(
                  icon: Icons.vibration_rounded,
                  label: 'Testar Vibração',
                  color: AppColors.warning,
                  onTap: () async {
                    _showFeedback('Vibração testada (Padrão Alerta).');
                    await TestHubService.instance.testVibration('emergencia');
                  },
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.checklist_rtl_rounded, color: AppColors.primary),
              ),
              title: const Text(
                'Diagnóstico Completo do Aparelho',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: const Text(
                'Verifique permissões de segundo plano, som, alarme exato e bateria.',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () => Navigator.pushNamed(context, '/device-readiness'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSandboxCard(bool hasMock) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasMock ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                color: hasMock ? AppColors.success : AppColors.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasMock
                      ? 'Dados de Demonstração Ativos'
                      : 'Nenhum dado simulado ativo',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: hasMock ? AppColors.onSuccessContainer : AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Gere 7 dias de doses tomadas, atrasadas e fotos para testar relatórios mensais, gráficos de adesão e notificações sem ter que esperar dias acumulando dados reais.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          setState(() => _isLoading = true);
                          try {
                            final count = await TestHubService.instance
                                .generateMockAdherenceData();
                            _showFeedback(
                              'Sucesso! $count eventos de 7 dias foram gerados.',
                              isSuccess: true,
                            );
                          } catch (e) {
                            _showFeedback('Erro ao gerar dados: $e', isSuccess: false);
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },
                  icon: _isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : const Icon(Icons.auto_graph_rounded, size: 18),
                  label: const Text('Gerar 7 Dias'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (hasMock)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            setState(() => _isLoading = true);
                            try {
                              final count = await TestHubService.instance
                                  .clearMockData();
                              _showFeedback(
                                'Dados de teste limpos ($count itens removidos).',
                                isSuccess: true,
                              );
                            } catch (e) {
                              _showFeedback('Erro ao limpar: $e', isSuccess: false);
                            } finally {
                              if (mounted) setState(() => _isLoading = false);
                            }
                          },
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Limpar Testes'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeModeCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warningContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.school_rounded, color: AppColors.onWarningContainer, size: 24),
          ),
          title: const Text(
            'Modo Treino para Idoso',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: const Text(
            'Permite ao idoso praticar confirmar remédio, tirar foto, adiar e usar comandos de voz com orientação falada.',
            style: TextStyle(fontSize: 13),
          ),
          trailing: Icon(Icons.play_circle_fill_rounded, size: 32, color: AppColors.success),
          onTap: () => Navigator.pushNamed(context, '/practice-mode'),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: iconColor,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTestButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFeedback(String message, {bool isSuccess = true}) {
    setState(() {
      _statusMessage = message;
      _isSuccess = isSuccess;
    });
  }
}
