import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../models/door_event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/admin_password_dialog.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/gate_barrier_visualizer.dart';
import '../../widgets/live_pulse_indicator.dart';
import '../activity/admin_activity_screen.dart';
import '../activity/rfid_activity_detail_sheet.dart';
import '../activity/rfid_activity_screen.dart';
import '../authentication/login_screen.dart';
import '../connection/connection_screen.dart';
import '../rfid/registered_cards_screen.dart';
import '../sensors/sensor_monitoring_screen.dart';
import '../settings/admin_profile_screen.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().startAutoRefresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final dashboard = context.read<DashboardProvider>();
    if (state == AppLifecycleState.resumed) {
      dashboard.startAutoRefresh();
    } else if (state == AppLifecycleState.paused) {
      dashboard.stopAutoRefresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<DashboardProvider>().stopAutoRefresh();
    super.dispose();
  }

  Future<void> _handleOpenGate(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      final authorized = await AdminPasswordDialog.verify(
        context,
        actionDescription: 'raise the gate barrier',
      );
      if (!authorized || !mounted) return;
    }

    final success = await context.read<DashboardProvider>().openGateBarrier();
    if (mounted) {
      if (success) {
        Helpers.showSnackBar(context, 'Gate barrier opened (90° raised).', isSuccess: true);
      } else {
        final err = context.read<DashboardProvider>().errorMessage;
        Helpers.showSnackBar(context, err ?? 'Failed to open gate barrier.', isError: true);
      }
    }
  }

  Future<void> _handleCloseGate(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      final authorized = await AdminPasswordDialog.verify(
        context,
        actionDescription: 'lower and secure the gate barrier',
      );
      if (!authorized || !mounted) return;
    }

    final success = await context.read<DashboardProvider>().closeGateBarrier();
    if (mounted) {
      if (success) {
        Helpers.showSnackBar(context, 'Gate barrier lowered and secured.', isSuccess: true);
      } else {
        final err = context.read<DashboardProvider>().errorMessage;
        Helpers.showSnackBar(context, err ?? 'Failed to close gate barrier.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final auth = context.watch<AuthProvider>();
    final connection = context.watch<ConnectionProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final status = dashboard.status;
    final isGateOpen = dashboard.isGateOpen;
    final servoAngle = dashboard.sensorData?.servoAngle ?? (isGateOpen ? 90 : 0);

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              LivePulseIndicator(
                color: connection.isConnected ? AppColors.success : AppColors.error,
                size: 10,
                animate: true,
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Smart Gate Barrier',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          actions: [
            // Wi-Fi hotspot connection status button
            IconButton(
              icon: Icon(
                connection.isConnected ? Icons.wifi : Icons.wifi_off,
                color: connection.isConnected ? AppColors.success : AppColors.error,
              ),
              tooltip: connection.isConnected ? 'Connected to ESP32 Hotspot' : 'Disconnected',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConnectionScreen()),
                );
              },
            ),

            // Admin Authentication status
            if (auth.isAuthenticated) ...[
              IconButton(
                icon: const Icon(Icons.admin_panel_settings, color: AppColors.primaryLight),
                tooltip: 'Admin Authenticated',
                onPressed: () => _showAdminQuickMenu(context, auth),
              ),
            ] else ...[
              IconButton(
                icon: const Icon(Icons.login),
                tooltip: 'Admin Login',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),
            ],

            // Settings
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await dashboard.fetchDashboardData();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Interactive 3D Vector Gate Barrier Visualizer (Category 1)
                GateBarrierVisualizer(
                  isOpen: isGateOpen,
                  servoAngle: servoAngle,
                  autoCloseRemaining: dashboard.autoCloseRemaining,
                  isControlling: dashboard.isControllingGate,
                ),

                const SizedBox(height: 14),

                // 2. Tactile One-Tap Remote Barrier Controls (Category 1)
                _buildActionButtons(context, isGateOpen, dashboard),

                const SizedBox(height: 14),

                // 3. Hardware & Telemetry Strip (Category 1)
                _buildTelemetryStrip(status, connection, servoAngle, isDark),

                const SizedBox(height: 14),

                // 4. RFID Card Management Quick Panel (Category 2)
                _buildRfidManagementCard(context, dashboard, auth, isDark),

                const SizedBox(height: 14),

                // 5. Activity & Security Audit Feed (Category 3)
                _buildSecurityFeedCard(context, dashboard, auth, isDark),

                const SizedBox(height: 14),

                // 6. System Shortcuts Grid (Category 1 to 4)
                _buildShortcutsGrid(context, auth),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Category 1: One-Tap Open & Close Controls with Haptic-Ready Buttons
  Widget _buildActionButtons(
    BuildContext context,
    bool isGateOpen,
    DashboardProvider dashboard,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  isGateOpen ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                  size: 20,
                  color: isGateOpen ? AppColors.success : AppColors.locked,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isGateOpen ? 'Lane Clear • Passing Active' : 'Barrier Secured • Lane Blocked',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isGateOpen ? AppColors.success : AppColors.locked,
                    ),
                  ),
                ),
                if (dashboard.isControllingGate)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                // Open Gate Button
                Expanded(
                  child: CustomButton(
                    text: 'Open Barrier',
                    icon: Icons.arrow_upward_rounded,
                    variant: ButtonVariant.success,
                    isLoading: dashboard.isControllingGate && !isGateOpen,
                    onPressed: isGateOpen ? null : () => _handleOpenGate(context),
                  ),
                ),
                const SizedBox(width: 12),
                // Close Gate Button
                Expanded(
                  child: CustomButton(
                    text: 'Close Barrier',
                    icon: Icons.arrow_downward_rounded,
                    variant: ButtonVariant.danger,
                    isLoading: dashboard.isControllingGate && isGateOpen,
                    onPressed: !isGateOpen ? null : () => _handleCloseGate(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Category 1: Telemetry & Hardware Metadata Strip
  Widget _buildTelemetryStrip(
    dynamic status,
    ConnectionProvider connection,
    int servoAngle,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTelemetryItem(
            icon: Icons.rotate_right_rounded,
            label: 'Servo Angle',
            value: '$servoAngle°',
            valueColor: AppColors.primary,
          ),
          _buildTelemetryDivider(),
          _buildTelemetryItem(
            icon: Icons.wifi,
            label: 'Hotspot',
            value: status?.ssid ?? 'ESP32_AP',
            valueColor: connection.isConnected ? AppColors.success : AppColors.error,
          ),
          _buildTelemetryDivider(),
          _buildTelemetryItem(
            icon: Icons.devices_rounded,
            label: 'Stations',
            value: '${status?.connectedClients ?? 0} connected',
            valueColor: AppColors.secondary,
          ),
          _buildTelemetryDivider(),
          _buildTelemetryItem(
            icon: Icons.timer_outlined,
            label: 'Uptime',
            value: status?.formattedUptime ?? '--',
            valueColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: valueColor),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryDivider() {
    return Container(
      height: 28,
      width: 1,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  /// Category 2: RFID Access Card Management Quick Card
  Widget _buildRfidManagementCard(
    BuildContext context,
    DashboardProvider dashboard,
    AuthProvider auth,
    bool isDark,
  ) {
    final count = dashboard.cardCount;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.nfc_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'RFID Card Authorization',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        auth.isAuthenticated ? '$count registered cards active' : 'Admin auth required to view',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _handleOpenRegisteredCards(context, auth),
                  child: const Text('View All'),
                ),
              ],
            ),
            const Divider(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.list_alt_rounded, size: 18),
                label: const Text('View Authorized RFID Cards'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _handleOpenRegisteredCards(context, auth),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Category 3: Activity & Security Audit Feed
  Widget _buildSecurityFeedCard(
    BuildContext context,
    DashboardProvider dashboard,
    AuthProvider auth,
    bool isDark,
  ) {
    final lastEvent = dashboard.lastEvent;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.history_rounded, color: AppColors.secondary, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Access & Security Logs',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () => _handleOpenActivityHistory(context, auth),
                  child: const Text('View All'),
                ),
              ],
            ),
            const Divider(height: 18),
            if (lastEvent != null) ...[
              GestureDetector(
                onTap: () => RfidActivityDetailSheet.show(context, lastEvent),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: lastEvent.statusColor.withValues(alpha: 0.12),
                        ),
                        child: Icon(lastEvent.icon, size: 16, color: lastEvent.statusColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lastEvent.displayTitle,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              lastEvent.displayTime,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No recent security events recorded.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// System Quick Actions Grid (Category 1 to 4)
  Widget _buildShortcutsGrid(BuildContext context, AuthProvider auth) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(
              child: _buildGridButton(
                icon: Icons.speed_rounded,
                label: 'Telemetry & Servo',
                color: AppColors.primary,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SensorMonitoringScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildGridButton(
                icon: Icons.shield_outlined,
                label: 'Admin Audit',
                color: AppColors.secondary,
                onTap: () => _handleOpenAdminAudit(context, auth),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildGridButton(
                icon: Icons.settings_suggest_outlined,
                label: 'Settings',
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGridButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Navigation & Admin Handlers ----------------

  Future<void> _handleOpenRegisteredCards(BuildContext context, AuthProvider auth) async {
    final authorized = await AdminPasswordDialog.verify(
      context,
      actionDescription: 'access the RFID card management screen',
    );
    if (!authorized || !context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisteredCardsScreen()),
    );
  }

  Future<void> _handleOpenActivityHistory(BuildContext context, AuthProvider auth) async {
    if (!auth.isAuthenticated) {
      final authorized = await AdminPasswordDialog.verify(
        context,
        actionDescription: 'view RFID access security logs',
      );
      if (!authorized || !context.mounted) return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RfidActivityScreen()),
    );
  }

  Future<void> _handleOpenAdminAudit(BuildContext context, AuthProvider auth) async {
    final authorized = await AdminPasswordDialog.verify(
      context,
      actionDescription: 'view administrative audit and security logs',
    );
    if (!authorized || !context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminActivityScreen()),
    );
  }

  void _showAdminQuickMenu(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppColors.primary,
                      radius: 18,
                      child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Administrator Authenticated',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Session active • Bearer token verified',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: const Text('Admin Security Profile'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.error),
                  title: const Text('Log Out Admin Session', style: TextStyle(color: AppColors.error)),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final confirmed = await ConfirmationDialog.show(
                      context,
                      title: 'Confirm Logout',
                      message: 'Are you sure you want to end your administrative session?',
                      confirmLabel: 'Log Out',
                      isDestructive: true,
                    );
                    if (confirmed) {
                      await auth.logout();
                      if (context.mounted) {
                        Helpers.showSnackBar(context, 'Logged out successfully');
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
