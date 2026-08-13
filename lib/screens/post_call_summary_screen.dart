import 'package:flutter/material.dart';
import '../models/video_call.dart';
import '../services/session_role_service.dart';
import '../services/video_call_service.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_layout.dart';

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
      if (status == VideoCallStatus.declined) return 'Ligação recusada';
      if (status == VideoCallStatus.missed) return 'Ligação não atendida';
      return 'Foi bem rápida';
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
    final compact = context.isCompactHeight || context.isLandscape;
    final isHighContrast =
        Theme.of(context).brightness == Brightness.light &&
        Theme.of(context).colorScheme.primary == Colors.black;

    final bgColor = isHighContrast
        ? Colors.black
        : AppColors.surfaceContainerLowest;
    final textColor = isHighContrast ? Colors.white : AppColors.onSurface;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: ResponsiveScrollView(
          padding: const EdgeInsets.all(24),
          maxContentWidth: 720,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 32),

              // Header Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: status == VideoCallStatus.ended
                      ? AppColors.successContainer
                      : AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: status == VideoCallStatus.ended
                        ? AppColors.success
                        : AppColors.error,
                    width: 2,
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Icon(
                      status == VideoCallStatus.ended
                          ? Icons.check_circle
                          : Icons.phone_disabled,
                      color: status == VideoCallStatus.ended
                          ? AppColors.success
                          : AppColors.error,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      status == VideoCallStatus.ended
                          ? 'Ligação terminou'
                          : 'Ligação terminou',
                      style: TextStyle(
                        fontSize: isElderly ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color: status == VideoCallStatus.ended
                            ? AppColors.onSuccessContainer
                            : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Contact Avatar
              Container(
                width: compact ? 96 : (isElderly ? 140 : 110),
                height: compact ? 96 : (isElderly ? 140 : 110),
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
                  size: compact ? 44 : (isElderly ? 70 : 50),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      color: AppColors.primary,
                      size: isElderly ? 26 : 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tempo: $_formattedDuration',
                      style: TextStyle(
                        fontSize: isElderly ? 20 : 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Action Buttons
              Column(
                children: [
                  // Call Back Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _callBack(context, callType),
                      icon: Icon(
                        isVoice ? Icons.phone : Icons.videocam,
                        size: isElderly ? 30 : 24,
                      ),
                      label: Text(
                        isVoice
                            ? 'Ligar de novo (voz)'
                            : 'Ligar de novo (vídeo)',
                        style: TextStyle(
                          fontSize: isElderly ? 20 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
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
                    child: OutlinedButton.icon(
                      onPressed: () => _finish(context),
                      icon: Icon(Icons.home_rounded, size: isElderly ? 30 : 24),
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
    );
  }
}
