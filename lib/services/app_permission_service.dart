import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

class AppPermissionItem {
  final String title;
  final String description;
  final Permission permission;
  final PermissionStatus status;

  const AppPermissionItem({
    required this.title,
    required this.description,
    required this.permission,
    required this.status,
  });

  bool get granted => status.isGranted || status.isLimited;
  bool get permanentlyDenied => status == PermissionStatus.permanentlyDenied;
}

class AppPermissionService {
  AppPermissionService._();
  static final AppPermissionService instance = AppPermissionService._();
  static const _gateCompletedKey = 'required_permissions_accepted_v1';

  Future<bool> isGateCompleted() async {
    if (kIsWeb) return true;
    final prefs = await SharedPreferences.getInstance();
    final wasCompleted = prefs.getBool(_gateCompletedKey) ?? false;
    if (!wasCompleted) return false;

    final stillGranted = await hasCurrentRequiredPermissions();
    if (!stillGranted) {
      await prefs.setBool(_gateCompletedKey, false);
    }
    return stillGranted;
  }

  Future<bool> hasCurrentRequiredPermissions() async {
    if (kIsWeb) return true;
    final currentStatuses = await statuses();
    return currentStatuses.isNotEmpty &&
        currentStatuses.every((item) => item.granted);
  }

  List<({String title, String description, Permission permission})>
  get _requiredPermissions {
    final items = <({String title, String description, Permission permission})>[
      (
        title: 'Notificações',
        description: 'Avisa quando chegar a hora de cada lembrete.',
        permission: Permission.notification,
      ),
      (
        title: 'Microfone',
        description: 'Permite responder e criar lembretes por voz.',
        permission: Permission.microphone,
      ),
      (
        title: 'Câmera',
        description: 'Permite confirmar medicamentos e identificar itens.',
        permission: Permission.camera,
      ),
      (
        title: 'Localização',
        description: 'Permite enviar a localização junto de um pedido de SOS.',
        permission: Permission.locationWhenInUse,
      ),
    ];
    if (Platform.isAndroid) {
      items.add((
        title: 'Alarmes exatos',
        description: 'Faz os lembretes tocarem no horário correto.',
        permission: Permission.scheduleExactAlarm,
      ));
      items.add((
        title: 'Bateria contínua',
        description:
            'Evita pausas na rádio e atrasos em lembretes com a tela apagada.',
        permission: Permission.ignoreBatteryOptimizations,
      ));
    }
    return items;
  }

  Future<List<AppPermissionItem>> statuses() async {
    final result = <AppPermissionItem>[];
    for (final item in _requiredPermissions) {
      result.add(
        AppPermissionItem(
          title: item.title,
          description: item.description,
          permission: item.permission,
          status: await item.permission.status,
        ),
      );
    }
    return result;
  }

  Future<List<AppPermissionItem>> requestAll() async {
    for (final item in _requiredPermissions) {
      if (!await item.permission.isGranted) await item.permission.request();
    }
    if (Platform.isAndroid) {
      await NotificationService.instance.requestAlarmPermissions();
    }
    return statuses();
  }

  Future<bool> completeGateIfGranted() async {
    final allGranted = await hasCurrentRequiredPermissions();
    if (allGranted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_gateCompletedKey, true);
    }
    return allGranted;
  }

  Future<bool> openSettings() => openAppSettings();
}
