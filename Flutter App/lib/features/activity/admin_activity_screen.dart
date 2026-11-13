import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/door_event.dart';
import '../../providers/activity_provider.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_banner.dart';
import 'rfid_activity_detail_sheet.dart';

class AdminActivityScreen extends StatefulWidget {
  const AdminActivityScreen({super.key});

  @override
  State<AdminActivityScreen> createState() => _AdminActivityScreenState();
}

class _AdminActivityScreenState extends State<AdminActivityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ActivityProvider>().loadEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<ActivityProvider>();
    final adminEvents = activity.adminEvents;

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Audit Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: activity.isLoading ? null : () => activity.loadEvents(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).cardColor,
            child: Row(
              children: [
                const Icon(Icons.security, size: 20, color: Colors.blueAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Administrative security logs: logins, password alterations, card enrollment & unauthorized attempts.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (activity.errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ErrorBanner(
                message: activity.errorMessage!,
                onRetry: () => activity.loadEvents(),
              ),
            ),
          Expanded(
            child: activity.isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => activity.loadEvents(),
                    child: adminEvents.isEmpty
                        ? LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                  child: EmptyStateView(
                                    icon: Icons.verified_user_outlined,
                                    title: 'No Administrative Activity',
                                    message: 'No admin logins or card modifications have been logged yet.',
                                    actionLabel: 'Refresh',
                                    onAction: () => activity.loadEvents(),
                                  ),
                                ),
                              );
                            },
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: adminEvents.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              return _buildAdminTile(context, adminEvents[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildAdminTile(BuildContext context, DoorEvent event) {
    final statusColor = event.statusColor;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(event.icon, color: statusColor, size: 22),
        ),
        title: Text(
          event.displayTitle,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            if (event.uid.isNotEmpty)
              Text(
                'Target UID: ${event.uid}',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            Text(
              'Result: ${event.result.toUpperCase()} • ${event.isCalendarTimeSynced ? DateFormatter.formatEpoch(event.timestamp) : "Uptime: ${DateFormatter.formatUptime(event.uptimeMs)}"}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => RfidActivityDetailSheet.show(context, event),
      ),
    );
  }
}
