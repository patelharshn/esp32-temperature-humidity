import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/helpers.dart';
import '../../models/sensor_data.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/sensor_provider.dart';
import '../../widgets/admin_password_dialog.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/gate_barrier_visualizer.dart';
import '../../widgets/live_pulse_indicator.dart';

class SensorMonitoringScreen extends StatefulWidget {
  const SensorMonitoringScreen({super.key});

  @override
  State<SensorMonitoringScreen> createState() => _SensorMonitoringScreenState();
}

class _SensorMonitoringScreenState extends State<SensorMonitoringScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SensorProvider>().startPolling();
    });
  }

  @override
  void dispose() {
    context.read<SensorProvider>().stopPolling();
    super.dispose();
  }

  Future<void> _handleEmergencyOpen(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      final authorized = await AdminPasswordDialog.verify(
        context,
        actionDescription: 'raise the gate barrier',
      );
      if (!authorized || !mounted) return;
    }

    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Open Gate Barrier?',
      message: 'This will actuate the servo to 90 degrees and open the vehicle lane.',
      confirmLabel: 'Open Barrier',
      isDestructive: false,
      icon: Icons.lock_open_rounded,
    );

    if (confirmed && mounted) {
      final success = await context.read<DashboardProvider>().openGateBarrier();
      if (mounted) {
        if (success) {
          Helpers.showSnackBar(context, 'Gate barrier opened successfully.', isSuccess: true);
        } else {
          final err = context.read<DashboardProvider>().errorMessage;
          Helpers.showSnackBar(context, err ?? 'Failed to open gate barrier.', isError: true);
        }
      }
    }
  }

  Future<void> _handleEmergencyClose(BuildContext context) async {
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
        Helpers.showSnackBar(context, 'Gate barrier secured and closed.', isSuccess: true);
      } else {
        final err = context.read<DashboardProvider>().errorMessage;
        Helpers.showSnackBar(context, err ?? 'Failed to close gate barrier.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sensor = context.watch<SensorProvider>();
    final dashboard = context.watch<DashboardProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final reading = sensor.latestReading;
    final isGateOpen = reading?.isOpen ?? dashboard.isGateOpen;
    final servoAngle = reading?.servoAngle ?? (isGateOpen ? 90 : 0);
    final history = sensor.history;

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              LivePulseIndicator(
                color: isGateOpen ? AppColors.success : AppColors.locked,
                size: 9,
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Barrier Telemetry & Servo',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Telemetry',
              onPressed: sensor.isLoading ? null : () => sensor.fetchLatestReading(),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => sensor.fetchLatestReading(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (sensor.errorMessage != null) ...[
                  ErrorBanner(
                    message: sensor.errorMessage!,
                    onRetry: () => sensor.fetchLatestReading(),
                  ),
                  const SizedBox(height: 12),
                ],

                // 1. Live Animated Visualizer
                GateBarrierVisualizer(
                  isOpen: isGateOpen,
                  servoAngle: servoAngle,
                  autoCloseRemaining: dashboard.autoCloseRemaining,
                  isControlling: dashboard.isControllingGate,
                ),

                const SizedBox(height: 16),

                // 2. Telemetry Stat Cards Grid
                _buildTelemetryGrid(reading, dashboard, isDark),

                const SizedBox(height: 16),

                // 3. Quick Remote Actuation Controls
                _buildQuickControls(context, isGateOpen, dashboard),

                const SizedBox(height: 18),

                // 4. Servo Angle History Graph
                _buildHistoryChart(history, isDark),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryGrid(
    SensorData? reading,
    DashboardProvider dashboard,
    bool isDark,
  ) {
    final status = dashboard.status;
    final isGateOpen = reading?.isOpen ?? dashboard.isGateOpen;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            // Angle Card
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'SERVO ANGLE',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        const Icon(Icons.rotate_right, size: 18, color: AppColors.primary),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${reading?.servoAngle ?? (isGateOpen ? 90 : 0)}°',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: isGateOpen ? AppColors.success : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isGateOpen ? 'Boom Raised (90°)' : 'Boom Horizontal (0°)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Uptime Card
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'SYSTEM UPTIME',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        const Icon(Icons.timer_outlined, size: 18, color: AppColors.secondary),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        status?.formattedUptime ?? '--',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ESP32 Pin: GPIO 32',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickControls(
    BuildContext context,
    bool isGateOpen,
    DashboardProvider dashboard,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Remote Servo Actuation',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
                Expanded(
                  child: CustomButton(
                    text: 'Open (Raise 90°)',
                    icon: Icons.arrow_upward_rounded,
                    variant: ButtonVariant.success,
                    isLoading: dashboard.isControllingGate && !isGateOpen,
                    onPressed: isGateOpen ? null : () => _handleEmergencyOpen(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    text: 'Close (Lower 0°)',
                    icon: Icons.arrow_downward_rounded,
                    variant: ButtonVariant.danger,
                    isLoading: dashboard.isControllingGate && isGateOpen,
                    onPressed: !isGateOpen ? null : () => _handleEmergencyClose(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryChart(List<SensorData> history, bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Servo Motion Timeline',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${history.length} logs',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Real-time angle recordings (0° Closed vs 90° Open)',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 170,
              child: history.isEmpty
                  ? Center(
                      child: Text(
                        'Awaiting telemetry from ESP32...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: 100,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 45,
                          getDrawingHorizontalLine: (val) => FlLine(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                            strokeWidth: 1,
                            dashArray: [4, 4],
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 34,
                              interval: 45,
                              getTitlesWidget: (val, _) {
                                return Text(
                                  '${val.toInt()}°',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (int i = 0; i < history.length; i++)
                                FlSpot(i.toDouble(), history[i].servoAngle.toDouble()),
                            ],
                            isCurved: false,
                            color: AppColors.primary,
                            barWidth: 2.5,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.primary.withValues(alpha: 0.12),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
