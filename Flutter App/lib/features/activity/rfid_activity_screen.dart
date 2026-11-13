import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/door_event.dart';
import '../../providers/activity_provider.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_banner.dart';
import 'rfid_activity_detail_sheet.dart';

class RfidActivityScreen extends StatefulWidget {
  const RfidActivityScreen({super.key});

  @override
  State<RfidActivityScreen> createState() => _RfidActivityScreenState();
}

class _RfidActivityScreenState extends State<RfidActivityScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ActivityProvider>().loadEvents();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<ActivityProvider>();
    final events = activity.filteredEvents;

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Access & Activity Logs'),
        actions: [
          IconButton(
            icon: Icon(
              activity.sortNewestFirst ? Icons.arrow_downward : Icons.arrow_upward,
            ),
            tooltip: activity.sortNewestFirst ? 'Sort: Newest First' : 'Sort: Oldest First',
            onPressed: () => activity.toggleSortOrder(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Events',
            onPressed: activity.isLoading ? null : () => activity.loadEvents(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          _buildSearchAndFilters(activity),

          // Error Banner if present
          if (activity.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ErrorBanner(
                message: activity.errorMessage!,
                onRetry: () => activity.loadEvents(),
              ),
            ),

          // Events List
          Expanded(
            child: activity.isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => activity.loadEvents(),
                    child: events.isEmpty
                        ? LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                  child: EmptyStateView(
                                    icon: Icons.receipt_long,
                                    title: 'No Events Found',
                                    message: activity.searchQuery.isNotEmpty
                                        ? 'No activity matches your search filter "${activity.searchQuery}".'
                                        : 'No RFID or gate barrier events have been recorded yet.',
                                    actionLabel: activity.searchQuery.isNotEmpty ? 'Clear Filters' : 'Refresh',
                                    onAction: activity.searchQuery.isNotEmpty
                                        ? () {
                                            _searchController.clear();
                                            activity.resetFilters();
                                          }
                                        : () => activity.loadEvents(),
                                  ),
                                ),
                              );
                            },
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: events.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              return _buildEventTile(context, events[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSearchAndFilters(ActivityProvider activity) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        children: [
          // Search Box
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by UID, event type, or keyword...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        activity.setSearchQuery('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onChanged: (val) => activity.setSearchQuery(val),
          ),

          const SizedBox(height: 10),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'All Types',
                  selected: activity.typeFilter == 'all',
                  onSelected: () => activity.setTypeFilter('all'),
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  label: 'RFID Scans',
                  selected: activity.typeFilter == 'rfid_access',
                  onSelected: () => activity.setTypeFilter('rfid_access'),
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  label: 'Keypad Passwords',
                  selected: activity.typeFilter == 'password_attempt',
                  onSelected: () => activity.setTypeFilter('password_attempt'),
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  label: 'Gate Controls',
                  selected: activity.typeFilter == 'gate_control',
                  onSelected: () => activity.setTypeFilter('gate_control'),
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  label: 'Admin Only',
                  selected: activity.typeFilter == 'admin',
                  onSelected: () => activity.setTypeFilter('admin'),
                ),
                const SizedBox(width: 14),
                // Result filter chips
                _buildFilterChip(
                  label: 'Granted',
                  selected: activity.resultFilter == 'granted',
                  activeColor: AppColors.success,
                  onSelected: () => activity.setResultFilter(
                    activity.resultFilter == 'granted' ? 'all' : 'granted',
                  ),
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  label: 'Denied',
                  selected: activity.resultFilter == 'denied',
                  activeColor: AppColors.error,
                  onSelected: () => activity.setResultFilter(
                    activity.resultFilter == 'denied' ? 'all' : 'denied',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    Color? activeColor,
  }) {
    final color = activeColor ?? Theme.of(context).colorScheme.primary;

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
      ),
      selectedColor: color,
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildEventTile(BuildContext context, DoorEvent event) {
    final statusColor = event.statusColor;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => RfidActivityDetailSheet.show(context, event),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Badge
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(event.icon, color: statusColor, size: 22),
              ),
              const SizedBox(width: 14),
              // Body
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            event.displayTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            event.result.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (event.uid.isNotEmpty) ...[
                      Text(
                        'Card UID: ${event.uid}',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Row(
                      children: [
                        Icon(
                          event.isCalendarTimeSynced ? Icons.access_time : Icons.timer_outlined,
                          size: 13,
                          color: event.isCalendarTimeSynced
                              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                              : AppColors.warning,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.isCalendarTimeSynced
                                ? DateFormatter.formatEpoch(event.timestamp)
                                : 'Uptime: ${DateFormatter.formatUptime(event.uptimeMs)} (Clock Uncalibrated)',
                            style: TextStyle(
                              fontSize: 11,
                              color: event.isCalendarTimeSynced
                                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
                                  : AppColors.warning,
                              fontWeight: event.isCalendarTimeSynced
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
