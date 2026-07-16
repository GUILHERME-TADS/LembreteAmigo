import 'package:get_it/get_it.dart';
import '../services/analytics_service.dart';
import '../services/remote_config_service.dart';

final getIt = GetIt.instance;

void configureDependencies() {
  getIt.registerLazySingleton<AnalyticsService>(() => AnalyticsService());
  getIt.registerLazySingleton<RemoteConfigService>(() => RemoteConfigService());
}
