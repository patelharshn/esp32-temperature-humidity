import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/api_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../providers/connection_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/live_pulse_indicator.dart';
import '../dashboard/dashboard_screen.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  late final TextEditingController _ipController;
  bool _showAdvancedSettings = false;

  @override
  void initState() {
    super.initState();
    final currentUrl = context.read<ConnectionProvider>().currentBaseUrl;
    _ipController = TextEditingController(text: currentUrl);
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ESP32 Hotspot Connection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Check Connection',
            onPressed: connection.isConnecting ? null : () => connection.checkConnection(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            _buildStatusCard(connection),

            const SizedBox(height: 20),

            // Step-by-Step Wi-Fi Instructions
            _buildInstructionsCard(isDark),

            const SizedBox(height: 20),

            // Advanced IP Configuration toggle
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Custom ESP32 IP Configuration',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Default: ${ApiConfig.defaultBaseUrl}',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              trailing: IconButton(
                icon: Icon(
                  _showAdvancedSettings ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                ),
                onPressed: () {
                  setState(() {
                    _showAdvancedSettings = !_showAdvancedSettings;
                  });
                },
              ),
            ),

            if (_showAdvancedSettings) ...[
              const SizedBox(height: 10),
              CustomTextField(
                controller: _ipController,
                label: 'ESP32 Base URL',
                hint: 'http://192.168.4.1',
                prefixIcon: Icons.lan,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check, color: AppColors.primary),
                  tooltip: 'Save IP',
                  onPressed: () {
                    connection.updateIpAddress(_ipController.text);
                    Helpers.showSnackBar(context, 'IP address updated to ${_ipController.text}');
                  },
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.restore, size: 16),
                    label: const Text('Reset to 192.168.4.1'),
                    onPressed: () {
                      _ipController.text = ApiConfig.defaultBaseUrl;
                      connection.resetToDefault();
                      Helpers.showSnackBar(context, 'Reset to default ESP32 IP');
                    },
                  ),
                ],
              ),
            ],

            if (connection.errorMessage != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(
                message: connection.errorMessage!,
                onRetry: () => connection.checkConnection(),
              ),
            ],

            const SizedBox(height: 28),

            // Actions
            CustomButton(
              text: connection.isConnecting ? 'Testing Connection...' : 'Test & Connect to ESP32',
              icon: Icons.wifi_find,
              isLoading: connection.isConnecting,
              onPressed: () async {
                final navigator = Navigator.of(context);
                final success = await connection.checkConnection();
                if (!context.mounted) return;
                if (success) {
                  Helpers.showSnackBar(context, 'Connected successfully to ESP32!', isSuccess: true);
                  navigator.pushReplacement(
                    MaterialPageRoute(builder: (_) => const DashboardScreen()),
                  );
                }
              },
            ),

            if (connection.isConnected) ...[
              const SizedBox(height: 12),
              CustomButton(
                text: 'Proceed to Dashboard',
                icon: Icons.dashboard,
                variant: ButtonVariant.secondary,
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const DashboardScreen()),
                  );
                },
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildStatusCard(ConnectionProvider connection) {
    Color statusColor;
    String statusTitle;
    String statusSubtitle;
    IconData statusIcon;

    switch (connection.status) {
      case ConnectionStateStatus.connected:
        statusColor = AppColors.success;
        statusTitle = 'Connected to ESP32';
        statusSubtitle = 'API Health: Online • Latency: ${connection.latencyMs ?? 0} ms';
        statusIcon = Icons.check_circle_outline;
        break;
      case ConnectionStateStatus.connecting:
        statusColor = AppColors.warning;
        statusTitle = 'Checking Connection...';
        statusSubtitle = 'Probing ${connection.currentBaseUrl}/api/status';
        statusIcon = Icons.sync;
        break;
      case ConnectionStateStatus.error:
        statusColor = AppColors.error;
        statusTitle = 'ESP32 Disconnected';
        statusSubtitle = 'Unable to reach door lock API at ${connection.currentBaseUrl}';
        statusIcon = Icons.error_outline;
        break;
      case ConnectionStateStatus.disconnected:
        statusColor = AppColors.darkTextMuted;
        statusTitle = 'Not Connected';
        statusSubtitle = 'Please follow the Wi-Fi instructions below to connect';
        statusIcon = Icons.wifi_off;
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                LivePulseIndicator(
                  color: statusColor,
                  size: 14,
                  animate: connection.isConnecting || connection.isConnected,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusSubtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(statusIcon, color: statusColor, size: 28),
              ],
            ),
            if (connection.isConnected && connection.lastStatus != null) ...[
              const Divider(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat('Device', connection.lastStatus!.device),
                  _buildMiniStat('Gate Barrier', connection.lastStatus!.locked ? 'CLOSED' : 'OPEN'),
                  _buildMiniStat('Time Sync', connection.lastStatus!.timeSynced ? 'Synced' : 'Pending'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionsCard(bool isDark) {
    return Card(
      color: isDark ? const Color(0xFF131D2E) : const Color(0xFFF0F7FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.wifi_tethering, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Wi-Fi Hotspot Setup Guide',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInstructionStep(
              number: '1',
              title: 'Open Phone Wi-Fi Settings',
              description: 'Go to your smartphone\'s Wi-Fi settings menu.',
            ),
            const SizedBox(height: 12),
            _buildInstructionStep(
              number: '2',
              title: 'Connect to Gate Barrier Hotspot',
              description: 'Select the network and enter credentials:\n• SSID: ${ApiConfig.defaultSsid}\n• Password: ${ApiConfig.defaultApPassword}',
            ),
            const SizedBox(height: 12),
            _buildInstructionStep(
              number: '3',
              title: 'Keep Local Connection Active',
              description: 'If prompted "No internet access - stay connected?", select YES. Tip: Temporarily disable Mobile Data if phone routes requests away.',
            ),
            const SizedBox(height: 12),
            _buildInstructionStep(
              number: '4',
              title: 'Return and Tap Test Connection',
              description: 'Once connected to the hotspot, tap "Test & Connect to ESP32" below.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep({
    required String number,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: AppColors.primary,
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
