import 'package:flutter/material.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/door_event.dart';

class RfidActivityDetailSheet extends StatelessWidget {
  final DoorEvent event;

  const RfidActivityDetailSheet({super.key, required this.event});

  static void show(BuildContext context, DoorEvent event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => RfidActivityDetailSheet(event: event),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = event.statusColor;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Title & Status Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(event.icon, color: statusColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.displayTitle,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          event.result.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 28),

            // Detail items
            _buildDetailRow('Event ID', '#${event.id} (Sequence)'),
            _buildDetailRow('Event Type', event.type),
            if (event.uid.isNotEmpty) _buildDetailRow('Card UID', event.uid),
            _buildDetailRow('Access Result', event.result.toUpperCase()),

            const Divider(height: 24),

            // Timing Details
            _buildDetailRow(
              'Calendar Timestamp',
              event.isCalendarTimeSynced
                  ? DateFormatter.formatEpoch(event.timestamp)
                  : 'Unavailable (Phone was not synced at event time)',
            ),
            _buildDetailRow(
              'Time Calibration',
              event.isCalendarTimeSynced ? 'Phone Synchronized' : 'ESP32 Uptime Only (Uncalibrated)',
            ),
            _buildDetailRow(
              'ESP32 Uptime',
              DateFormatter.formatUptime(event.uptimeMs),
            ),

            const SizedBox(height: 20),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
