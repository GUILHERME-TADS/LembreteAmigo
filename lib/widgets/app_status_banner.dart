import 'package:flutter/material.dart';

import '../services/app_status_service.dart';
import '../theme/app_theme.dart';

class AppStatusBanner extends StatelessWidget {
  final Widget child;

  const AppStatusBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<AppStatusMessage>>(
      valueListenable: AppStatusService.instance.messages,
      builder: (context, messages, _) {
        final message = messages.isEmpty ? null : messages.first;
        return Stack(
          children: [
            child,
            if (message != null)
              Positioned(
                left: 12,
                right: 12,
                top: MediaQuery.of(context).padding.top + 8,
                child: Material(
                  color: Colors.transparent,
                  child: _StatusCard(message: message),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  final AppStatusMessage message;

  const _StatusCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final isCritical = message.severity == AppStatusSeverity.critical;
    final color = isCritical ? AppColors.error : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCritical ? Icons.error_outline : Icons.info_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message.message,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => AppStatusService.instance.clear(message.id),
          ),
        ],
      ),
    );
  }
}
