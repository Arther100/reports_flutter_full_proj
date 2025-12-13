import 'package:get_it/get_it.dart';
import 'api/api_client.dart';
import 'api/power_data_service.dart';

final GetIt serviceLocator = GetIt.instance;

/// Initialize all services using dependency injection
void setupServiceLocator() {
  // API Client (Singleton)
  serviceLocator.registerLazySingleton<ApiClient>(() => ApiClient());

  // Power Data Service
  serviceLocator.registerLazySingleton<PowerDataService>(
    () => PowerDataService(apiClient: serviceLocator<ApiClient>()),
  );
}

/// Get service instance
T getService<T extends Object>() => serviceLocator<T>();
