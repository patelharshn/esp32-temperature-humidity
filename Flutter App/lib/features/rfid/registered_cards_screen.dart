import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/rfid_card.dart';
import '../../providers/rfid_provider.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_banner.dart';

class RegisteredCardsScreen extends StatefulWidget {
  const RegisteredCardsScreen({super.key});

  @override
  State<RegisteredCardsScreen> createState() => _RegisteredCardsScreenState();
}

class _RegisteredCardsScreenState extends State<RegisteredCardsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RfidProvider>().loadCards();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rfidProvider = context.watch<RfidProvider>();
    final cards = rfidProvider.cards;

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Authorized RFID Cards'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Cards',
              onPressed: rfidProvider.isLoading ? null : () => rfidProvider.loadCards(),
            ),
          ],
        ),
        body: Column(
          children: [
            if (rfidProvider.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ErrorBanner(
                  message: rfidProvider.errorMessage!,
                  onRetry: () => rfidProvider.loadCards(),
                ),
              ),
            Expanded(
              child: rfidProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => rfidProvider.loadCards(),
                      child: cards.isEmpty
                          ? LayoutBuilder(
                              builder: (context, constraints) {
                                return SingleChildScrollView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                    child: EmptyStateView(
                                      icon: Icons.credit_card_off,
                                      title: 'No Registered Cards',
                                      message:
                                          'No RFID cards or keyfobs are currently authorized in ESP32 memory. Enroll cards using the physical ESP32 keypad menu.',
                                      actionLabel: 'Refresh',
                                      onAction: () => rfidProvider.loadCards(),
                                    ),
                                  ),
                                );
                              },
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: cards.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final card = cards[index];
                                return _buildCardTile(context, card);
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardTile(BuildContext context, RfidCard card) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.credit_card, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          card.displayName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'AUTHORIZED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.successDark,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'UID: ${card.formattedUid}',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
