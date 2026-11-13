import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../providers/rfid_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/live_pulse_indicator.dart';

class RegisterCardSheet extends StatefulWidget {
  const RegisterCardSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const RegisterCardSheet(),
    );
  }

  @override
  State<RegisterCardSheet> createState() => _RegisterCardSheetState();
}

class _RegisterCardSheetState extends State<RegisterCardSheet> {
  final _nicknameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RfidProvider>().startRegistration();
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rfidProvider = context.watch<RfidProvider>();
    final step = rfidProvider.registrationStep;

    return PopScope(
      canPop: step == RfidRegistrationStep.success ||
          step == RfidRegistrationStep.alreadyRegistered ||
          step == RfidRegistrationStep.timeout ||
          step == RfidRegistrationStep.error ||
          step == RfidRegistrationStep.idle,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Visual Icon / Status Indicator
              _buildStepVisual(step),

              const SizedBox(height: 20),

              // Title & Description based on step
              _buildStepContent(step, rfidProvider),

              const SizedBox(height: 24),

              // Action buttons based on step
              _buildStepActions(step, rfidProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepVisual(RfidRegistrationStep step) {
    switch (step) {
      case RfidRegistrationStep.initiating:
        return const SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(strokeWidth: 3),
        );
      case RfidRegistrationStep.waitingForTap:
      case RfidRegistrationStep.cardDetected:
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Stack(
            alignment: Alignment.center,
            children: [
              LivePulseIndicator(color: AppColors.secondary, size: 24),
              Icon(Icons.contactless, color: AppColors.primary, size: 44),
            ],
          ),
        );
      case RfidRegistrationStep.success:
        return Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle, color: AppColors.success, size: 48),
        );
      case RfidRegistrationStep.alreadyRegistered:
        return Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 48),
        );
      case RfidRegistrationStep.timeout:
      case RfidRegistrationStep.error:
        return Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.error_outline, color: AppColors.error, size: 48),
        );
      case RfidRegistrationStep.idle:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStepContent(RfidRegistrationStep step, RfidProvider provider) {
    switch (step) {
      case RfidRegistrationStep.initiating:
        return const Column(
          children: [
            Text(
              'Preparing ESP32...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text(
              'Sending registration command to RC522 reader module.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        );
      case RfidRegistrationStep.waitingForTap:
        return Column(
          children: [
            const Text(
              'Present RFID Card to ESP32',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Please tap the RFID card or keyfob against the RC522 reader on the gate barrier hardware.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sensors, size: 16, color: AppColors.secondary),
                  SizedBox(width: 8),
                  Text(
                    'Listening for card scan on ESP32...',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        );
      case RfidRegistrationStep.success:
        return Column(
          children: [
            const Text(
              'Card Registered Successfully!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.success),
            ),
            const SizedBox(height: 8),
            Text(
              'RFID Card UID: ${provider.newlyRegisteredUid ?? "Recorded"}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: 'Give this card a friendly label (optional)',
                hintText: 'e.g., Alice Keyfob, Spare Tag',
                prefixIcon: Icon(Icons.label_outline, size: 20),
              ),
            ),
          ],
        );
      case RfidRegistrationStep.alreadyRegistered:
        return Column(
          children: [
            const Text(
              'Card Already Registered!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.warning),
            ),
            const SizedBox(height: 8),
            Text(
              'This RFID card is already authorized in ESP32 memory and active on the gate barrier.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
            if (provider.newlyRegisteredUid != null && provider.newlyRegisteredUid!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warningBg.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'Card UID: ${provider.newlyRegisteredUid}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ],
        );
      case RfidRegistrationStep.timeout:
      case RfidRegistrationStep.error:
        return Column(
          children: [
            Text(
              step == RfidRegistrationStep.timeout ? 'Registration Timed Out' : 'Registration Failed',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.error),
            ),
            const SizedBox(height: 8),
            Text(
              provider.registrationError ?? 'An unexpected error occurred while communicating with the ESP32.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        );
      case RfidRegistrationStep.idle:
      case RfidRegistrationStep.cardDetected:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStepActions(RfidRegistrationStep step, RfidProvider provider) {
    switch (step) {
      case RfidRegistrationStep.initiating:
      case RfidRegistrationStep.waitingForTap:
      case RfidRegistrationStep.cardDetected:
        return CustomButton(
          text: 'Cancel Registration',
          variant: ButtonVariant.outline,
          onPressed: () {
            provider.cancelRegistration();
            Navigator.of(context).pop();
          },
        );
      case RfidRegistrationStep.success:
        return CustomButton(
          text: 'Save & Finish',
          variant: ButtonVariant.primary,
          onPressed: () async {
            if (_nicknameController.text.trim().isNotEmpty && provider.newlyRegisteredUid != null) {
              await provider.updateCardLabel(
                provider.newlyRegisteredUid!,
                _nicknameController.text.trim(),
              );
            }
            provider.resetRegistration();
            if (mounted) {
              Navigator.of(context).pop();
              Helpers.showSnackBar(context, 'RFID card added to authorized list', isSuccess: true);
            }
          },
        );
      case RfidRegistrationStep.alreadyRegistered:
        return Row(
          children: [
            Expanded(
              child: CustomButton(
                text: 'Try Another',
                icon: Icons.refresh,
                variant: ButtonVariant.outline,
                onPressed: () => provider.startRegistration(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomButton(
                text: 'Done',
                icon: Icons.check,
                variant: ButtonVariant.primary,
                onPressed: () {
                  provider.resetRegistration();
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        );
      case RfidRegistrationStep.timeout:
      case RfidRegistrationStep.error:
        return Row(
          children: [
            Expanded(
              child: CustomButton(
                text: 'Dismiss',
                variant: ButtonVariant.outline,
                onPressed: () {
                  provider.resetRegistration();
                  Navigator.of(context).pop();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomButton(
                text: 'Try Again',
                variant: ButtonVariant.primary,
                onPressed: () => provider.startRegistration(),
              ),
            ),
          ],
        );
      case RfidRegistrationStep.idle:
        return const SizedBox.shrink();
    }
  }
}
