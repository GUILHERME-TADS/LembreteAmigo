import 'package:flutter/material.dart';
import '../services/video_call_service.dart';

class MissedCallsBadge extends StatelessWidget {
  final Widget child;

  const MissedCallsBadge({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: VideoCallService.instance.watchMissedCallsCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (count > 0)
              Positioned(
                right: -8,
                top: -8,
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
    );
  }
}
