import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/helpers.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/custom_button.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final session = auth.session;

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Security Profile'),
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Session Status Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.primary,
                        child: Icon(Icons.shield, size: 40, color: Colors.white),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Authenticated Administrator',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        auth.isAuthenticated ? 'Session Active (HTTP Bearer Auth)' : 'Session Expired',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: auth.isAuthenticated ? AppColors.success : AppColors.error,
                        ),
                      ),
                      const Divider(height: 28),
                      if (session != null) ...[
                        _buildSessionInfo(
                          'Session Token',
                          '${session.token.substring(0, 6)}••••${session.token.substring(session.token.length - 4)}',
                        ),
                        const SizedBox(height: 10),
                        _buildSessionInfo(
                          'Expires At',
                          DateFormatter.formatDateTime(session.expiresAt),
                        ),
                        const SizedBox(height: 10),
                        _buildSessionInfo(
                          'Remaining Time',
                          '${session.remainingSeconds ~/ 60} mins left',
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Log Out Button
              CustomButton(
                text: 'Log Out Admin Session',
                icon: Icons.logout,
                variant: ButtonVariant.danger,
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final confirmed = await ConfirmationDialog.show(
                    context,
                    title: 'Confirm Logout',
                    message: 'Are you sure you want to end your administrative session?',
                    confirmLabel: 'Log Out',
                    isDestructive: true,
                  );
                  if (!context.mounted) return;
                  if (confirmed) {
                    await auth.logout();
                    if (!context.mounted) return;
                    navigator.pop();
                    Helpers.showSnackBar(context, 'Admin session ended.');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionInfo(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
