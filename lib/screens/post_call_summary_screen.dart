import 'package:flutter/material.dart';
import '../models/video_call.dart';
import '../services/session_role_service.dart';
import '../services/video_call_service.dart';
import '../theme/app_theme.dart';

class PostCallSummaryScreen extends StatelessWidget {
  final String callerName;
  final String callType; // 'video' or 'voice'
  final int durationSeconds;
  final VideoCallStatus status;

  const PostCallSummaryScreen({
    super.key,
    required this.callerName,
    required this.callType,
    required this.durationSeconds,
    this.status = VideoCallStatus.ended,
  });

  String get _formattedDuration {
    if (durationSeconds <= 0) {
      if (status == VideoCallStatus.declined) return 'Chamada recusada';
      if (status == VideoCallStatus.missed) return 'Chamada não atendida';
      return 'Duração rápida';
    }
    final min = durationSeconds ~/ 60;
    final sec = durationSeconds % 60;
    if (min == 0) return '$sec segundos';
    if (sec == 0) return '$min minuto${min > 1 ? 's' : ''}';
    return '$min min e $sec s';
  }

  Future<void> _callBack(BuildContext context, String type) async {
    final navigator = Navigator.of(context);
    navigator.pop(); // Pop post-call summary

    final idosoId = await SessionRoleService.getActiveIdosoId();
    final call = await VideoCallService.instance.initiateCall(
      idosoId: idosoId,
      callType: type,
      initiatedBy: SessionRoleService.isSupervisor ? 'supervisor' : 'idoso',
    );

    if (call != null) {
      await VideoCallService.instance.joinCall(
        call.roomName,
        callType: type,
        callId: call.callId,
        alreadyVerified: true,
      );
    }
  }

  void _finish(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    final fallbackRoute = SessionRoleService.isSupervisor
        ? '/supervisor-dashboard'
        : '/elderly-home';
    navigator.pushNamedAndRemoveUntil(fallbackRoute, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isElderly = SessionRoleService.isElderly;
    final isVoice = callType == 'voice';
    final isHighContrast = Theme.of(context).brightness == Brightness.light &&
        Theme.of(context).colorScheme.primary == Colors.black;

    final bgColor = isHighContrast ? Colors.black : AppColors.surfaceContainerLowest;
    final textColor = isHighContrast ? Colors.white : AppColors.onSurface;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Header Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: status == VideoCallStatus.ended
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: status == VideoCallStatus.ended
                          ? const Color(0xFF2E7D32)
                          : AppColors.error,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        status == VideoCallStatus.ended
                            ? Icons.check_circle
                            : Icons.phone_disabled,
                        color: status == VideoCallStatus.ended
                            ? const Color(0xFF2E7D32)
                            : AppColors.error,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status == VideoCallStatus.ended
                            ? 'Chamada Finalizada'
                            : 'Chamada Encerrada',
                        style: TextStyle(
                          fontSize: isElderly ? 18 : 16,
                          fontWeight: FontWeight.bold,
                          color: status == VideoCallStatus.ended
                              ? const Color(0xFF1B5E20)
                              : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Contact Avatar
                Container(
                  width: isElderly ? 140 : 110,
                  height: isElderly ? 140 : 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryContainer,
                    border: Border.all(color: AppColors.primary, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    isVoice ? Icons.person : Icons.videocam,
                    size: isElderly ? 70 : 50,
                    color: AppColors.primary,
                  ),
                ),

                const SizedBox(height: 24),

                // Name
                Text(
                  callerName.isNotEmpty ? callerName : 'Contato',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isElderly ? 32 : 24,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),

                const SizedBox(height: 8),

                // Duration Info
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: AppColors.primary,
                        size: isElderly ? 26 : 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Duração: $_formattedDuration',
                        style: TextStyle(
                          fontSize: isElderly ? 20 : 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Action Buttons
                Column(
                  children: [
                    // Call Back Button
                    SizedBox(
                      width: double.infinity,
                      height: isElderly ? 64 : 54,
                      child: ElevatedButton.icon(
                        onPressed: () => _callBack(context, callType),
                        icon: Icon(
                          isVoice ? Icons.phone : Icons.videocam,
                          size: isElderly ? 30 : 24,
                        ),
                        label: Text(
                          isVoice ? 'Ligar de Volta (Voz)' : 'Ligar de Volta (Vídeo)',
                          style: TextStyle(
                            fontSize: isElderly ? 20 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 3,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Back to Home Button
                    SizedBox(
                      width: double.infinity,
                      height: isElderly ? 64 : 54,
                      child: OutlinedButton.icon(
                        onPressed: () => _finish(context),
                        icon: Icon(
                          Icons.home_rounded,
                          size: isElderly ? 30 : 24,
                        ),
                        label: Text(
                          'Voltar para o Início',
                          style: TextStyle(
                            fontSize: isElderly ? 20 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor,
                          side: BorderSide(color: AppColors.outline, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
