import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Exibe o seletor de horário personalizado e otimizado para idosos.
/// Retorna o [TimeOfDay] selecionado ou null se cancelado.
Future<TimeOfDay?> showCustomTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) async {
  return await showDialog<TimeOfDay>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return CustomTimePickerDialog(initialTime: initialTime);
    },
  );
}

class CustomTimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;

  const CustomTimePickerDialog({super.key, required this.initialTime});

  @override
  State<CustomTimePickerDialog> createState() => _CustomTimePickerDialogState();
}

class _CustomTimePickerDialogState extends State<CustomTimePickerDialog> {
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
  }

  void _adjustHour(int delta) {
    setState(() {
      _hour = (_hour + delta + 24) % 24;
    });
  }

  void _adjustMinute(int delta) {
    setState(() {
      _minute = (_minute + delta + 60) % 60;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Título principal da tela
              Text(
                'AJUSTAR HORÁRIO',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Toque nos botões de + e - para alterar as horas e minutos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),

              // Relógio analógico e digital agrupados em um layout harmonioso
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Lado Esquerdo: Mostrador analógico desenhado
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          blurRadius: 16,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: ClockFacePainter(
                        hour: _hour,
                        minute: _minute,
                        primaryColor: AppColors.primary,
                        accentColor: AppColors.voiceFeedbackBlue,
                        outlineColor: AppColors.outlineVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Controles Digitais
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Coluna de Horas
                  _buildControlColumn(
                    value: _hour,
                    onIncrement: () => _adjustHour(1),
                    onDecrement: () => _adjustHour(-1),
                    label: 'HORA',
                  ),

                  // Dois pontos separadores piscando levemente
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        ':',
                        style: TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),

                  // Coluna de Minutos
                  _buildControlColumn(
                    value: _minute,
                    onIncrement: () => _adjustMinute(
                      5,
                    ), // Incrementa de 5 em 5 para maior facilidade
                    onDecrement: () =>
                        _adjustMinute(-5), // Decrementa de 5 em 5
                    label: 'MINUTO',
                    // Permitir ajuste fino se pressionar de forma simples ou secundária
                    onIncrementFine: () => _adjustMinute(1),
                    onDecrementFine: () => _adjustMinute(-1),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Legenda para ajuste fino
              Text(
                'Dica: Nos minutos, os botões grandes alteram de 5 em 5.\nToque nos números para digitar o horário exato.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 24),

              // Atalhos rápidos
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ATALHOS RÁPIDOS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildShortcutCard('Manhã', 8, 0),
                    const SizedBox(width: 8),
                    _buildShortcutCard('Almoço', 12, 0),
                    const SizedBox(width: 8),
                    _buildShortcutCard('Tarde', 15, 0),
                    const SizedBox(width: 8),
                    _buildShortcutCard('Noite', 20, 0),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Botões de Ação
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: AppColors.outlineVariant,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'CANCELAR',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                          TimeOfDay(hour: _hour, minute: _minute),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondaryContainer,
                        foregroundColor: AppColors.onSecondaryFixed,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'CONFIRMAR',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Método auxiliar para construir a coluna de controle (Botão +, Valor, Botão -)
  Widget _buildControlColumn({
    required int value,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
    required String label,
    VoidCallback? onIncrementFine,
    VoidCallback? onDecrementFine,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),

        // Botão Incrementar Principal (+)
        _buildRoundButton(
          icon: Icons.add,
          onTap: onIncrement,
          heroTag: 'inc_$label',
        ),

        const SizedBox(height: 12),

        GestureDetector(
          onTap: () async {
            // Abrir caixa de diálogo simples para entrada direta via teclado se o idoso preferir
            final res = await showDialog<int>(
              context: context,
              builder: (context) =>
                  _NumberInputDialog(label: label, initialValue: value),
            );
            if (res != null) {
              setState(() {
                if (label == 'HORA') {
                  _hour = res.clamp(0, 23);
                } else {
                  _minute = res.clamp(0, 59);
                }
              });
            }
          },
          child: Container(
            width: 90,
            height: 90,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineVariant, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),

                // Botões de ajuste fino discretos (+) e (-) na borda do card, se houver
                if (onIncrementFine != null && onDecrementFine != null) ...[
                  Positioned(
                    top: 2,
                    right: 2,
                    child: InkWell(
                      onTap: onIncrementFine,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: InkWell(
                      onTap: onDecrementFine,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.remove,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Botão Decrementar Principal (-)
        _buildRoundButton(
          icon: Icons.remove,
          onTap: onDecrement,
          heroTag: 'dec_$label',
        ),
      ],
    );
  }

  // Botão circular grande de ajuste (+ ou -)
  Widget _buildRoundButton({
    required IconData icon,
    required VoidCallback onTap,
    required String heroTag,
  }) {
    return SizedBox(
      width: 60,
      height: 60,
      child: FloatingActionButton(
        heroTag: heroTag,
        onPressed: onTap,
        backgroundColor: AppColors.surfaceContainerHigh,
        foregroundColor: AppColors.primary,
        elevation: 1,
        highlightElevation: 3,
        shape: const CircleBorder(),
        child: Icon(icon, size: 32),
      ),
    );
  }

  // Atalhos Rápidos
  Widget _buildShortcutCard(String title, int targetHour, int targetMinute) {
    final isSelected = _hour == targetHour && _minute == targetMinute;
    return GestureDetector(
      onTap: () {
        setState(() {
          _hour = targetHour;
          _minute = targetMinute;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineVariant,
            width: 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          children: [
            Text(
              '${targetHour.toString().padLeft(2, '0')}:${targetMinute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberInputDialog extends StatefulWidget {
  final String label;
  final int initialValue;

  const _NumberInputDialog({required this.label, required this.initialValue});

  @override
  State<_NumberInputDialog> createState() => _NumberInputDialogState();
}

class _NumberInputDialogState extends State<_NumberInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue.toString().padLeft(2, '0'),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Digite o valor de ${widget.label}'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        maxLength: 2,
        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
        decoration: const InputDecoration(counterText: ''),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCELAR'),
        ),
        TextButton(
          onPressed: () {
            final val = int.tryParse(_controller.text);
            Navigator.pop(context, val);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// CustomPainter para desenhar o relógio analógico bonito e decorativo.
class ClockFacePainter extends CustomPainter {
  final int hour;
  final int minute;
  final Color primaryColor;
  final Color accentColor;
  final Color outlineColor;

  ClockFacePainter({
    required this.hour,
    required this.minute,
    required this.primaryColor,
    required this.accentColor,
    required this.outlineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Linhas de guias de fundo ou marcas horárias (tick marks)
    final tickPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.2)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 12; i++) {
      final double angle = i * 30 * math.pi / 180;
      final start = Offset(
        center.dx + (radius * 0.8) * math.cos(angle),
        center.dy + (radius * 0.8) * math.sin(angle),
      );
      final end = Offset(
        center.dx + (radius * 0.9) * math.cos(angle),
        center.dy + (radius * 0.9) * math.sin(angle),
      );
      canvas.drawLine(start, end, tickPaint);
    }

    // 2. Desenhar números chaves (12, 3, 6, 9)
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final textStyle = TextStyle(
      color: primaryColor.withValues(alpha: 0.7),
      fontSize: 13,
      fontWeight: FontWeight.w800,
    );

    final Map<String, Offset> numbers = {
      '12': Offset(0, -0.62),
      '3': Offset(0.62, 0),
      '6': Offset(0, 0.62),
      '9': Offset(-0.62, 0),
    };

    numbers.forEach((numText, offsetMult) {
      textPainter.text = TextSpan(text: numText, style: textStyle);
      textPainter.layout();
      final x = center.dx + offsetMult.dx * radius - textPainter.width / 2;
      final y = center.dy + offsetMult.dy * radius - textPainter.height / 2;
      textPainter.paint(canvas, Offset(x, y));
    });

    // 3. ngulos dos ponteiros (corrigidos para o topo do relógio -90 graus)
    final double hourAngle =
        ((hour % 12) * 30 + (minute * 0.5)) * math.pi / 180 - math.pi / 2;
    final double minuteAngle = (minute * 6) * math.pi / 180 - math.pi / 2;

    // 4. Desenhar Ponteiro das Horas (mais curto e grosso)
    final hourHandLength = radius * 0.5;
    final hourHandPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(
        center.dx + hourHandLength * math.cos(hourAngle),
        center.dy + hourHandLength * math.sin(hourAngle),
      ),
      hourHandPaint,
    );

    // 5. Desenhar Ponteiro dos Minutos (mais longo e azul/destaque)
    final minuteHandLength = radius * 0.75;
    final minuteHandPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(
        center.dx + minuteHandLength * math.cos(minuteAngle),
        center.dy + minuteHandLength * math.sin(minuteAngle),
      ),
      minuteHandPaint,
    );

    // 6. Pino central do relógio
    final centerPinPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 7, centerPinPaint);

    final centerPinCorePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3, centerPinCorePaint);
  }

  @override
  bool shouldRepaint(covariant ClockFacePainter oldDelegate) {
    return oldDelegate.hour != hour || oldDelegate.minute != minute;
  }
}
