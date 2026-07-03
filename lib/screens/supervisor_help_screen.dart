import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/supervisor_bottom_nav.dart';

class SupervisorHelpScreen extends StatelessWidget {
  const SupervisorHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const SupervisorBottomNav(selected: SupervisorNavDestination.help),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    const Text(
                      'Central de Ajuda',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tire dúvidas sobre o painel do supervisor.',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400, height: 1.6, color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    _helpCard(
                      icon: Icons.medication,
                      title: 'Gerenciar Lembretes',
                      description: 'Crie, edite ou remova lembretes de medicação, hidratação e atividades para o idoso.',
                    ),
                    const SizedBox(height: 12),
                    _helpCard(
                      icon: Icons.history,
                      title: 'Histórico e Relatórios',
                      description: 'Acompanhe o cumprimento da rotina diária e visualize relatórios mensais de atividades.',
                    ),
                    const SizedBox(height: 12),
                    _helpCard(
                      icon: Icons.favorite,
                      title: 'Monitoramento de Saúde',
                      description: 'Veja dados de saúde como batimentos cardíacos e nível de bateria do dispositivo.',
                    ),
                    const SizedBox(height: 12),
                    _helpCard(
                      icon: Icons.warning_amber,
                      title: 'Alertas de Emergência',
                      description: 'Receba notificações imediatas caso o idoso precise de ajuda ou um lembrete seja ignorado.',
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.support_agent, color: AppColors.primary, size: 32),
                              SizedBox(width: 12),
                              Text(
                                'Suporte Técnico',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Precisa de ajuda adicional? Entre em contato com nossa equipe de suporte pelo e-mail suporte@lembreteamigo.com ou telefone (11) 99999-8888.',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, color: AppColors.onSurfaceVariant),
                          ),
                        ],
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

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.primary, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.health_and_safety, size: 32, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Cuidador', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              border: Border.fromBorderSide(BorderSide(color: AppColors.primaryContainer, width: 2)),
            ),
            child: const Icon(Icons.person, color: AppColors.primaryContainer),
          ),
        ],
      ),
    );
  }

  Widget _helpCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
