import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../authentication/login_screen.dart';
import '../connection/connection_screen.dart';
import 'admin_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    final currentLoc = context.read<SettingsProvider>().doorLocation;
    _locationController = TextEditingController(text: currentLoc);
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final connection = context.watch<ConnectionProvider>();
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings & Configuration'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. ESP32 Wi-Fi & Time Sync Section
              _buildSectionHeader('ESP32 Hardware & Time Sync'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.wifi, color: AppColors.primary),
                        ),
                        title: const Text('Wi-Fi Target Base URL', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(connection.currentBaseUrl),
                        trailing: TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ConnectionScreen()),
                            );
                          },
                          child: const Text('Configure'),
                        ),
                      ),
                      const Divider(height: 20),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.access_time, color: AppColors.secondary),
                        ),
                        title: const Text('Clock Synchronization', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          connection.isTimeSynced
                              ? 'ESP32 synced with phone calendar clock'
                              : 'Unsynchronized (Events recorded with uptime only)',
                          style: TextStyle(
                            fontSize: 12,
                            color: connection.isTimeSynced ? AppColors.success : AppColors.warning,
                          ),
                        ),
                        trailing: ElevatedButton(
                          onPressed: connection.isConnected
                              ? () async {
                                  final success = await connection.syncTime();
                                  if (context.mounted) {
                                    Helpers.showSnackBar(
                                      context,
                                      success
                                          ? 'ESP32 calendar clock synchronized!'
                                          : 'Time sync failed.',
                                      isSuccess: success,
                                    );
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                          child: const Text('Sync Now'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 2. Gate Barrier Installation Location
              _buildSectionHeader('Barrier Installation Location'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomTextField(
                        controller: _locationController,
                        label: 'Gate Barrier Location Label',
                        hint: 'e.g., Main Gate, Parking Barrier A, Facility West',
                        prefixIcon: Icons.garage_outlined,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check, color: AppColors.primary),
                          onPressed: () {
                            settings.updateDoorLocation(_locationController.text);
                            Helpers.showSnackBar(context, 'Gate barrier location saved.');
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 20, color: AppColors.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'Phone GPS Geotag (Optional)',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ESP32 hardware does not have internal satellite GPS. You can record your mobile phone\'s current GPS coordinates at this gate installation point for maintenance reference.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (settings.phoneGpsLocation != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  settings.phoneGpsLocation!,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                onPressed: () => settings.clearPhoneGps(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      CustomButton(
                        text: settings.isLocating
                            ? 'Acquiring GPS...'
                            : 'Tag Phone GPS Location',
                        icon: Icons.my_location,
                        variant: ButtonVariant.outline,
                        isLoading: settings.isLocating,
                        onPressed: () async {
                          final ok = await settings.capturePhoneLocation();
                          if (context.mounted) {
                            if (ok) {
                              Helpers.showSnackBar(context, 'Gate location geotagged.', isSuccess: true);
                            } else {
                              Helpers.showSnackBar(
                                context,
                                settings.locationError ?? 'Failed to capture GPS.',
                                isError: true,
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 3. Application Preferences (Theme Mode)
              _buildSectionHeader('Preferences'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(settings.themeMode.name.toUpperCase()),
                  trailing: DropdownButton<ThemeMode>(
                    value: settings.themeMode,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark (OLED)')),
                      DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                      DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                    ],
                    onChanged: (mode) {
                      if (mode != null) settings.setThemeMode(mode);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 4. Admin Security
              _buildSectionHeader('Administrator Portal'),
              Card(
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.admin_panel_settings, color: AppColors.primary),
                  ),
                  title: Text(
                    auth.isAuthenticated ? 'Admin Security Profile' : 'Admin Login',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    auth.isAuthenticated
                        ? 'Session active • View security profile or log out'
                        : 'Authenticate to manage RFID cards, gate controls & audit logs',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (auth.isAuthenticated) {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                  },
                ),
              ),

              const SizedBox(height: 20),

              // 5. Firmware Architecture & Capabilities
              _buildSectionHeader('ESP32 Firmware Architecture & Notes'),
              Card(
                color: isDark ? const Color(0xFF131D2E) : const Color(0xFFF8FAFC),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFeatureSupportItem(
                        supported: true,
                        title: 'Direct SoftAP Wi-Fi Communication',
                        desc: 'Operates completely offline without external internet or router via ESP32 hotspot.',
                      ),
                      _buildFeatureSupportItem(
                        supported: true,
                        title: 'Servo Gate Barrier Remote Control',
                        desc: 'Open (90°) and Close (0°) barrier commands via POST /api/gate/open & /close.',
                      ),
                      _buildFeatureSupportItem(
                        supported: true,
                        title: '5-Second Safety Auto-Closure',
                        desc: 'Hardware auto-closes gate barrier after 5 seconds safety timeout.',
                      ),
                      _buildFeatureSupportItem(
                        supported: true,
                        title: 'RFID RC522 Card Enrollment & Access Control',
                        desc: 'ESP32 handles RC522 scanning, persistence in NVS, and verification.',
                      ),
                      _buildFeatureSupportItem(
                        supported: true,
                        title: 'Security Audit Ring Buffer',
                        desc: 'ESP32 stores up to 20 recent events in NVS; app caches history locally.',
                      ),
                      _buildFeatureSupportItem(
                        supported: true,
                        title: 'Keypad 4x4 & SSD1306 OLED UI',
                        desc: 'On-device physical keypad password entry and visual status display.',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFeatureSupportItem({
    required bool supported,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            supported ? Icons.check_circle_outline : Icons.info_outline,
            size: 18,
            color: supported ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: supported ? null : AppColors.warning,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
