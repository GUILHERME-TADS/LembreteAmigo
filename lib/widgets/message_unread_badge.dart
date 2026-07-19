import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_message.dart';
import '../services/message_service.dart';

class MessageUnreadBadge extends StatefulWidget {
  final Widget child;

  const MessageUnreadBadge({
    super.key,
    required this.child,
  });

  @override
  State<MessageUnreadBadge> createState() => _MessageUnreadBadgeState();
}

class _MessageUnreadBadgeState extends State<MessageUnreadBadge> {
  @override
  void initState() {
    super.initState();
    unawaited(
      MessageService.instance.load().catchError((Object error) {
        debugPrint('Erro ao carregar contador de recados: $error');
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<AppMessage>>(
      valueListenable: MessageService.instance.notifier,
      builder: (context, messages, child) {
        final count = MessageService.instance.unreadIncomingCount;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child!,
            if (count > 0)
              Positioned(
                right: -9,
                top: -9,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    shape: count < 10 ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: count < 10 ? null : BorderRadius.circular(11),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: widget.child,
    );
  }
}
