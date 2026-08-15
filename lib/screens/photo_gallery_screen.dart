import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../theme/app_theme.dart';
import '../widgets/supervisor_bottom_nav.dart';

class PhotoGalleryScreen extends StatelessWidget {
  const PhotoGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const SupervisorBottomNav(
        selected: SupervisorNavDestination.history,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: ValueListenableBuilder<List<Lembrete>>(
                valueListenable: LembreteService.instance.notifier,
                builder: (context, lembretes, _) {
                  final comFoto =
                      lembretes
                          .where(
                            (l) =>
                                l.concluidoComFoto &&
                                l.medicamentoFotoPath != null &&
                                l.medicamentoFotoPath!.isNotEmpty,
                          )
                          .toList()
                        ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));

                  if (comFoto.isEmpty) {
                    return _buildEmptyState();
                  }

                  final Map<String, List<Lembrete>> byDate = {};
                  for (final l in comFoto) {
                    final key =
                        '${l.criadoEm.day.toString().padLeft(2, '0')}/${l.criadoEm.month.toString().padLeft(2, '0')}/${l.criadoEm.year}';
                    byDate.putIfAbsent(key, () => []).add(l);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: byDate.length,
                    itemBuilder: (context, index) {
                      final dateKey = byDate.keys.elementAt(index);
                      final items = byDate[dateKey]!;
                      return _buildDateGroup(context, dateKey, items);
                    },
                  );
                },
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: AppColors.surface),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: AppColors.primary,
              size: 36,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Icon(Icons.photo_library, color: AppColors.primary, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Galeria de Fotos',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_camera_outlined,
            size: 80,
            color: AppColors.outlineVariant,
          ),
          const SizedBox(height: 20),
          Text(
            'Nenhuma foto ainda',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'As fotos de confirmacao de\nlembretes aparecerao aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildDateGroup(
    BuildContext context,
    String dateKey,
    List<Lembrete> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color: AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                dateKey,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  '${items.length} foto${items.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimaryFixed,
                  ),
                ),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 240,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.0,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => _buildPhotoCell(context, items[i]),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPhotoCell(BuildContext context, Lembrete lembrete) {
    final path = lembrete.medicamentoFotoPath!;
    final bool isLocalFile =
        !kIsWeb && !path.startsWith('http') && !path.startsWith('avatar_');

    return GestureDetector(
      onTap: () => _showFullScreenPhoto(context, lembrete),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            isLocalFile && File(path).existsSync()
                ? Image.file(File(path), fit: BoxFit.cover)
                : path.startsWith('http')
                ? Image.network(
                    path,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _photoPlaceholder(),
                  )
                : _photoPlaceholder(),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Text(
                  lembrete.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: AppColors.surfaceContainerHigh,
      child: Icon(
        Icons.broken_image_outlined,
        color: AppColors.outline,
        size: 40,
      ),
    );
  }

  void _showFullScreenPhoto(BuildContext context, Lembrete lembrete) {
    final path = lembrete.medicamentoFotoPath!;
    final bool isLocalFile =
        !path.startsWith('http') && !path.startsWith('avatar_');

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: isLocalFile && File(path).existsSync()
                    ? Image.file(File(path), fit: BoxFit.contain)
                    : path.startsWith('http')
                    ? Image.network(path, fit: BoxFit.contain)
                    : _photoPlaceholder(),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      lembrete.titulo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lembrete.criadoEm.day.toString().padLeft(2, '0')}/${lembrete.criadoEm.month.toString().padLeft(2, '0')}/${lembrete.criadoEm.year}  ${lembrete.horarioFormatado}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
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
