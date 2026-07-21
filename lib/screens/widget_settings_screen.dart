import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/widget_service.dart';
import '../theme/app_theme.dart';

class WidgetSettingsScreen extends StatefulWidget {
  const WidgetSettingsScreen({super.key});

  @override
  State<WidgetSettingsScreen> createState() => _WidgetSettingsScreenState();
}

class _WidgetSettingsScreenState extends State<WidgetSettingsScreen> {
  late String _selectedTheme;
  late String _selectedFontSize;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedTheme = WidgetService.instance.themeNotifier.value;
    _selectedFontSize = WidgetService.instance.fontSizeNotifier.value;
  }

  Future<void> _saveAndApply() async {
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    await WidgetService.instance.setTheme(_selectedTheme);
    await WidgetService.instance.setFontSize(_selectedFontSize);

    if (!mounted) return;
    setState(() => _isSaving = false);
    HapticFeedback.heavyImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Widget atualizado na tela inicial do seu celular com sucesso!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 4),
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
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Pré-visualização do seu Widget:',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onBackground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildLivePreview(),
                    const SizedBox(height: 28),
                    Text(
                      '1. Escolha a cor do tema:',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onBackground,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildThemeOptions(),
                    const SizedBox(height: 28),
                    Text(
                      '2. Tamanho da letra no Widget:',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onBackground,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildFontSizeOptions(),
                    const SizedBox(height: 36),
                    _buildApplyButton(),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 30, color: AppColors.primary),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Personalizar Widget 📱',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreview() {
    final isHighContrast = _selectedTheme == 'high_contrast_yellow';
    final isDark = _selectedTheme == 'dark_mode';

    final bgColor = isHighContrast
        ? Colors.yellow
        : (isDark ? const Color(0xFF1E1E2E) : const Color(0xFF1565C0));

    final cardBgColor = isHighContrast
        ? Colors.white
        : (isDark ? const Color(0xFF2A2A3C) : Colors.white.withValues(alpha: 0.15));

    final mainTextColor = isHighContrast ? Colors.black : Colors.white;
    final subTextColor = isHighContrast ? Colors.black87 : Colors.white70;

    final baseSizeDelta = _selectedFontSize == 'grande'
        ? 2.0
        : (_selectedFontSize == 'extra_grande' ? 4.0 : 0.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isHighContrast ? Colors.black : (isDark ? const Color(0xFF3B3B54) : const Color(0xFF42A5F5)),
          width: isHighContrast ? 4 : 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Lembretes de Hoje',
                  style: TextStyle(
                    fontSize: 15 + baseSizeDelta,
                    fontWeight: FontWeight.bold,
                    color: mainTextColor,
                  ),
                ),
              ),
              Text(
                'Atualizado',
                style: TextStyle(fontSize: 11, color: subTextColor),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildPreviewRow(
            time: '08:00',
            icon: '💊',
            title: 'Tomar remédio da pressão',
            cardBgColor: cardBgColor,
            textColor: mainTextColor,
            isHighContrast: isHighContrast,
            baseSizeDelta: baseSizeDelta,
          ),
          const SizedBox(height: 8),
          _buildPreviewRow(
            time: '10:30',
            icon: '💧',
            title: 'Beber água com limão',
            cardBgColor: cardBgColor,
            textColor: mainTextColor,
            isHighContrast: isHighContrast,
            baseSizeDelta: baseSizeDelta,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isHighContrast ? Colors.black : const Color(0xFFFFCA28),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '🎙️ Falar',
                    style: TextStyle(
                      fontSize: 13 + (baseSizeDelta * 0.5),
                      fontWeight: FontWeight.bold,
                      color: isHighContrast ? Colors.yellow : Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isHighContrast ? Colors.black : const Color(0xFFFFCA28),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '🎶 Rádio',
                    style: TextStyle(
                      fontSize: 13 + (baseSizeDelta * 0.5),
                      fontWeight: FontWeight.bold,
                      color: isHighContrast ? Colors.yellow : Colors.black,
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

  Widget _buildPreviewRow({
    required String time,
    required String icon,
    required String title,
    required Color cardBgColor,
    required Color textColor,
    required bool isHighContrast,
    required double baseSizeDelta,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(14),
        border: isHighContrast ? Border.all(color: Colors.black, width: 2) : null,
      ),
      child: Row(
        children: [
          Text(
            time,
            style: TextStyle(
              fontSize: 15 + baseSizeDelta,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            icon,
            style: TextStyle(fontSize: 16 + baseSizeDelta),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15 + baseSizeDelta,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOptions() {
    return Column(
      children: [
        _buildThemeCard(
          id: 'classic_blue',
          title: 'Azul Clássico (Padrão)',
          subtitle: 'Visual limpo e elegante nas cores do Lembrete Amigo',
          colorPreview: const Color(0xFF1565C0),
        ),
        const SizedBox(height: 12),
        _buildThemeCard(
          id: 'high_contrast_yellow',
          title: 'Alto Contraste Amarelo',
          subtitle: 'Fundo amarelo vibrante e letras pretas para máxima facilidade de leitura',
          colorPreview: Colors.yellow,
        ),
        const SizedBox(height: 12),
        _buildThemeCard(
          id: 'dark_mode',
          title: 'Modo Noturno Escuro',
          subtitle: 'Cores escuras e relaxantes que não cansam a vista à noite',
          colorPreview: const Color(0xFF1E1E2E),
        ),
      ],
    );
  }

  Widget _buildThemeCard({
    required String id,
    required String title,
    required String subtitle,
    required Color colorPreview,
  }) {
    final isSelected = _selectedTheme == id;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedTheme = id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineVariant,
            width: isSelected ? 3 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorPreview,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black26, width: 2),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle, color: AppColors.primary, size: 28),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFontSizeOptions() {
    final options = [
      {'id': 'normal', 'label': 'Normal'},
      {'id': 'grande', 'label': 'Grande (+2)'},
      {'id': 'extra_grande', 'label': 'Extra Grande (+4)'},
    ];

    return Row(
      children: options.map((opt) {
        final id = opt['id']!;
        final label = opt['label']!;
        final isSelected = _selectedFontSize == id;

        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedFontSize = id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.outlineVariant,
                  width: isSelected ? 2.5 : 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : AppColors.onSurface,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildApplyButton() {
    return ElevatedButton(
      onPressed: _isSaving ? null : _saveAndApply,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 6,
      ),
      child: _isSaving
          ? const SizedBox(
              height: 28,
              width: 28,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.system_update_alt, size: 28),
                SizedBox(width: 12),
                Text(
                  '✅ Aplicar no Celular Agora',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ],
            ),
    );
  }
}
