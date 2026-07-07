import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../theme/app_theme.dart';
import '../models/achievement.dart';
import '../services/achievement_service.dart';
import '../services/tts_service.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with TickerProviderStateMixin {
  Achievement? _celebrating;
  late ConfettiController _confettiController;
  late AnimationController _spinController;
  late Animation<double> _spinAnimation;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _spinAnimation = CurvedAnimation(
      parent: _spinController,
      curve: Curves.easeOutBack,
    );

    final last =
        AchievementService.instance.lastUnlocked.value;
    if (last != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _celebrate(last);
      });
    }

    AchievementService.instance.lastUnlocked
        .addListener(_onNewAchievement);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _spinController.dispose();
    AchievementService.instance.lastUnlocked
        .removeListener(_onNewAchievement);
    super.dispose();
  }

  void _onNewAchievement() {
    final last =
        AchievementService.instance.lastUnlocked.value;
    if (last != null && mounted) {
      _celebrate(last);
    }
  }

  void _celebrate(Achievement ach) {
    setState(() => _celebrating = ach);
    _confettiController.play();
    _spinController.forward(from: 0);
    try {
      TTSService.instance.falar(
        'Você ganhou a medalha ${ach.titulo}! ${ach.descricao}',
      );
    } catch (_) {}
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _celebrating = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏅 Medalhas'),
        centerTitle: true,
      ),
      body: ValueListenableBuilder<List<Achievement>>(
        valueListenable:
            AchievementService.instance.achievements,
        builder: (context, achievements, _) {
          final unlocked =
              achievements.where((a) => a.desbloqueado).length;
          final total = achievements.length;

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHeader(unlocked, total),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _buildAchievementCard(
                                achievements[index]),
                        childCount: achievements.length,
                      ),
                    ),
                  ),
                ],
              ),
              if (_celebrating != null)
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality:
                        BlastDirectionality.explosive,
                    particleDrag: 0.05,
                    emissionFrequency: 0.05,
                    numberOfParticles: 40,
                    colors: [
                      Colors.amber,
                      Colors.green,
                      Colors.blue,
                      Colors.purple,
                      Colors.orange,
                    ],
                    shouldLoop: false,
                    maxBlastForce: 20,
                    minBlastForce: 5,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(int unlocked, int total) {
    final progress = total > 0 ? unlocked / total : 0.0;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '$unlocked / $total',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const Text(
            'Medalhas Desbloqueadas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(Achievement ach) {
    final desbloqueado = ach.desbloqueado;
    return AnimatedBuilder(
      animation: _spinAnimation,
      builder: (context, child) {
        final isThisOne =
            _celebrating?.id == ach.id && _spinController.isAnimating;
        return Transform(
          alignment: Alignment.center,
          transform: isThisOne
              ? (Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(6.283 * _spinAnimation.value))
              : Matrix4.identity(),
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: desbloqueado
              ? AppColors.surfaceContainerHighest
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: desbloqueado
                ? AppColors.primary
                : Colors.grey.shade300,
            width: desbloqueado ? 2 : 1,
          ),
          boxShadow: desbloqueado
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showAchievementDetails(ach),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    desbloqueado ? ach.icone : '🔒',
                    style: TextStyle(
                      fontSize: desbloqueado ? 48 : 40,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ach.titulo,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: desbloqueado
                          ? AppColors.onSurface
                          : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (!desbloqueado && ach.progressoMaximo > 1)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ach.progresso / ach.progressoMaximo,
                        minHeight: 4,
                        backgroundColor: Colors.grey.shade300,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(
                                AppColors.primary),
                      ),
                    ),
                  if (!desbloqueado && ach.progressoMaximo > 1)
                    const SizedBox(height: 4),
                  if (!desbloqueado && ach.progressoMaximo > 1)
                    Text(
                      '${ach.progresso.toInt()}/${ach.progressoMaximo.toInt()}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  if (desbloqueado)
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAchievementDetails(Achievement ach) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ach.desbloqueado ? ach.icone : '🔒',
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            Text(
              ach.titulo,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ach.descricao,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (ach.desbloqueado)
              Text(
                'Desbloqueado em:\n${ach.dataDesbloqueio!.day}/${ach.dataDesbloqueio!.month}/${ach.dataDesbloqueio!.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            if (!ach.desbloqueado && ach.progressoMaximo > 1)
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: ach.progresso / ach.progressoMaximo,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade300,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(
                              AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${ach.progresso.toInt()} / ${ach.progressoMaximo.toInt()}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
