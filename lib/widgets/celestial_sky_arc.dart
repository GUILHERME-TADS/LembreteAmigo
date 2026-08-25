import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/lembrete_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../utils/period_helper.dart';

const List<String> _diasDaSemana = [
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado',
  'Domingo',
];

const List<String> _meses = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

/// Widget de Relógio & Calendário Acessível para Idosos com Orientação Temporal e Leitura por Voz.
class CelestialSkyArc extends StatefulWidget {
  final VoidCallback? onTapped;

  const CelestialSkyArc({super.key, this.onTapped});

  @override
  State<CelestialSkyArc> createState() => _CelestialSkyArcState();
}

class _CelestialSkyArcState extends State<CelestialSkyArc> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    TTSService.instance.parar(caller: this);
    super.dispose();
  }

  void _speakCurrentTimeAndPeriod() {
    HapticFeedback.mediumImpact();
    if (widget.onTapped != null) widget.onTapped!();

    final now = DateTime.now();
    final diaSemana = _diasDaSemana[now.weekday - 1];
    final mes = _meses[now.month - 1];
    final spokenTime = PeriodHelper.getSpokenTimeWithPreposition(
      now.hour,
      now.minute,
    );

    String periodDesc = '';
    if (now.hour >= 5 && now.hour < 12) {
      periodDesc = 'Estamos no período da manhã.';
    } else if (now.hour >= 12 && now.hour < 18) {
      periodDesc = 'Estamos no período da tarde.';
    } else {
      periodDesc = 'Estamos no período da noite.';
    }

    final reminders = LembreteService.instance.lembretes;
    String reminderSpeech = '';
    if (reminders.isNotEmpty) {
      final pending = reminders.where((l) => !l.concluido).length;
      reminderSpeech = pending > 0
          ? ' Você tem $pending lembretes pendentes para hoje.'
          : ' Todos os seus lembretes de hoje estão em dia!';
    }

    final speech =
        'Agora são $spokenTime. Hoje é $diaSemana, dia ${now.day} de $mes. $periodDesc$reminderSpeech';
    TTSService.instance.falar(speech, caller: this);
  }

  @override
  Widget build(BuildContext context) {
    final isHighContrast =
        Theme.of(context).colorScheme.primary == Colors.black;
    final now = _now;
    final diaSemana = _diasDaSemana[now.weekday - 1];
    final mes = _meses[now.month - 1];
    final periodLabel = PeriodHelper.getPeriodLabel(now.hour);
    final periodColor = PeriodHelper.getPeriodColor(now.hour);
    final periodIcon = PeriodHelper.getPeriodIcon(now.hour);
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Semantics(
      button: true,
      label:
          'Relógio e data. $diaSemana, dia ${now.day} de $mes, às $timeStr, período da $periodLabel. Toque duas vezes para ouvir as horas em voz alta.',
      child: GestureDetector(
        onTap: _speakCurrentTimeAndPeriod,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isHighContrast
                ? Colors.white
                : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isHighContrast
                  ? Colors.black
                  : AppColors.outlineVariant.withValues(alpha: 0.7),
              width: isHighContrast ? 3.0 : 1.5,
            ),
            boxShadow: isHighContrast
                ? null
                : [
                    BoxShadow(
                      color: AppColors.shadow.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Linha Superior: Data e Período do Dia
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          diaSemana,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isHighContrast
                                ? Colors.black
                                : AppColors.primary,
                          ),
                        ),
                        Text(
                          '${now.day} de $mes',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isHighContrast
                                ? Colors.black87
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isHighContrast
                          ? Colors.black
                          : periodColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(
                        color: isHighContrast
                            ? Colors.black
                            : periodColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          periodIcon,
                          size: 18,
                          color: isHighContrast ? Colors.white : periodColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          periodLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isHighContrast ? Colors.white : periodColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Centro: Horário Digital Gigante de Fácil Leitura
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.access_time_filled_rounded,
                    size: 38,
                    color: isHighContrast
                        ? Colors.black
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: isHighContrast
                          ? Colors.black
                          : AppColors.primary,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Botão de Áudio "Toque para ouvir as horas"
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isHighContrast
                      ? Colors.white
                      : AppColors.secondaryContainer.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(
                    color: isHighContrast
                        ? Colors.black
                        : AppColors.onSecondaryContainer.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.volume_up_rounded,
                      size: 18,
                      color: isHighContrast
                          ? Colors.black
                          : AppColors.onSecondaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Toque para ouvir as horas 🗣️',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isHighContrast
                            ? Colors.black
                            : AppColors.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
