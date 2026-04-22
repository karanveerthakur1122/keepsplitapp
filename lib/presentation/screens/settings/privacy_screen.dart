import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _lastUpdated = 'April 22, 2026';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark ? AppColors.darkGradient : AppColors.lightGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Haptics.tap();
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/settings');
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.arrow_back_rounded, size: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Privacy Policy',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    Text(
                      'Last updated: $_lastUpdated',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                    ),
                    const SizedBox(height: 20),
                    _section(context, '1. Introduction',
                        'Keepsplit ("we", "our", "the App") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your information when you use our application.'),
                    _section(context, '2. Information We Collect',
                        'We collect the following types of information:\n\n'
                            '\u2022 Account information: Email address and display name you provide during registration\n'
                            '\u2022 User content: Notes, expenses, and related data you create in the App\n'
                            '\u2022 Collaboration data: Information about shared notes and collaborator relationships\n'
                            '\u2022 Usage data: App interaction patterns to improve performance and user experience'),
                    _section(context, '3. How We Use Your Information',
                        'Your information is used to:\n\n'
                            '\u2022 Provide and maintain the App\'s functionality\n'
                            '\u2022 Enable real-time collaboration features\n'
                            '\u2022 Calculate expense splits, balances, and settlements\n'
                            '\u2022 Send you notifications about shared notes and collaborator activity\n'
                            '\u2022 Improve and optimize the App experience'),
                    _section(context, '4. Data Storage & Security',
                        'Your data is stored securely using Supabase cloud infrastructure with encryption at rest and in transit. We implement Row Level Security (RLS) policies to ensure you can only access data you own or have been granted permission to view. Local data is stored on your device using encrypted SQLite databases.'),
                    _section(context, '5. Data Sharing',
                        'We do not sell, trade, or rent your personal information to third parties. Your data is shared only in the following circumstances:\n\n'
                            '\u2022 With collaborators you explicitly invite to shared notes\n'
                            '\u2022 With service providers (Supabase) who help operate the App, under strict data processing agreements\n'
                            '\u2022 When required by law or to protect our legal rights'),
                    _section(context, '6. Shared Notes & Visibility',
                        'When you share a note with another user, they can see the note\'s content, expenses, and related data based on the permission level you assign (viewer or editor). Share tokens allow limited access to note content. You control who has access at all times.'),
                    _section(context, '7. Data Retention',
                        'We retain your data for as long as your account is active. When you delete a note, it is moved to trash and permanently deleted after the retention period. When you delete your account, all associated data is permanently removed from our servers.'),
                    _section(context, '8. Your Rights',
                        'You have the right to:\n\n'
                            '\u2022 Access your personal data stored in the App\n'
                            '\u2022 Update or correct your profile information\n'
                            '\u2022 Delete your notes and expense data\n'
                            '\u2022 Delete your account entirely\n'
                            '\u2022 Export your data upon request'),
                    _section(context, '9. Cookies & Local Storage',
                        'The App uses SharedPreferences and local storage on your device to store settings (theme, layout preference, tutorial status) and cached data for offline functionality. This data remains on your device and is cleared when you sign out.'),
                    _section(context, '10. Children\'s Privacy',
                        'Keepsplit is not intended for children under 13. We do not knowingly collect personal information from children. If you believe a child has provided us with personal information, please contact us.'),
                    _section(context, '11. Changes to This Policy',
                        'We may update this Privacy Policy from time to time. We will notify you of significant changes through the App. Continued use after changes constitutes acceptance of the updated policy.'),
                    _section(context, '12. Contact Us',
                        'If you have questions about this Privacy Policy or your data, please contact us through the App\'s support channels.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, String body) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }
}
