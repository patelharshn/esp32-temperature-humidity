import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'providers/activity_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/connection_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/rfid_provider.dart';
import 'providers/sensor_provider.dart';
import 'providers/settings_provider.dart';
import 'repositories/auth_repository.dart';
import 'repositories/device_repository.dart';
import 'repositories/rfid_repository.dart';
import 'services/api_service.dart';
import 'services/location_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // Initialize persistent storage
  final prefs = await SharedPreferences.getInstance();
  final storageService = StorageService(prefs);

  // Initialize network & core services
  final initialBaseUrl = storageService.getBaseUrl();
  final apiClient = ApiClient(baseUrl: initialBaseUrl);
  final apiService = ApiService(apiClient);
  final locationService = LocationService();

  // Initialize repositories
  final deviceRepository = DeviceRepository(apiService, storageService);
  final authRepository = AuthRepository(apiService, storageService);
  final rfidRepository = RfidRepository(apiService, storageService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(storageService, locationService),
        ),
        ChangeNotifierProvider(
          create: (_) => ConnectionProvider(apiClient, deviceRepository, storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authRepository, apiClient),
        ),
        ChangeNotifierProvider(
          create: (context) => DashboardProvider(
            deviceRepository,
            rfidRepository,
            context.read<AuthProvider>(),
            context.read<ConnectionProvider>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => RfidProvider(rfidRepository, deviceRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => SensorProvider(deviceRepository, storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => ActivityProvider(rfidRepository),
        ),
      ],
      child: const Esp32DoorLockApp(),
    ),
  );
}

class Esp32DoorLockApp extends StatelessWidget {
  const Esp32DoorLockApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
      title: 'ESP32 Smart Gate Barrier',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      home: const SplashScreen(),
    );
  }
}
