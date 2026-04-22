import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
                      'Terms & Conditions',
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
                    _section(context, '1. Acceptance of Terms',
                        'By downloading, installing, or using Keepsplit ("the App"), you agree to be bound by these Terms and Conditions. If you do not agree, do not use the App.'),
                    _section(context, '2. Description of Service',
                        'Keepsplit is a collaborative note-taking and bill-splitting application that allows users to create notes, track shared expenses, calculate balances, and determine settlements among participants.'),
                    _section(context, '3. User Accounts',
                        'You must create an account to use Keepsplit. You are responsible for maintaining the confidentiality of your login credentials and for all activities that occur under your account. You agree to provide accurate and complete information during registration.'),
                    _section(context, '4. Acceptable Use',
                        'You agree not to:\n\n'
                            '\u2022 Use the App for any unlawful purpose\n'
                            '\u2022 Attempt to gain unauthorized access to other accounts or systems\n'
                            '\u2022 Interfere with or disrupt the App\'s functionality\n'
                            '\u2022 Upload malicious content or spam\n'
                            '\u2022 Use the App to harass, abuse, or harm others'),
                    _section(context, '5. User Content',
                        'You retain ownership of content you create in the App. By using Keepsplit, you grant us a limited license to store, process, and display your content solely for the purpose of providing the service. We do not claim ownership of your notes, expenses, or other data.'),
                    _section(context, '6. Shared Notes & Collaboration',
                        'When you share a note with other users, they can view and edit the note based on the permissions you assign. You are responsible for managing collaborator access. We are not liable for actions taken by collaborators on shared notes.'),
                    _section(context, '7. Financial Calculations',
                        'Keepsplit provides expense splitting and settlement calculations for convenience only. These calculations are not financial advice. We are not responsible for any financial disputes arising from the use of these features. Always verify amounts independently.'),
                    _section(context, '8. Availability & Modifications',
                        'We strive to keep the App available at all times but do not guarantee uninterrupted access. We reserve the right to modify, suspend, or discontinue any part of the service at any time with or without notice.'),
                    _section(context, '9. Termination',
                        'We may suspend or terminate your account if you violate these terms. You may delete your account at any time. Upon termination, your data may be permanently deleted in accordance with our Privacy Policy.'),
                    _section(context, '10. Limitation of Liability',
                        'Keepsplit is provided "as is" without warranties of any kind. To the maximum extent permitted by law, we shall not be liable for any indirect, incidental, special, or consequential damages arising from your use of the App.'),
                    _section(context, '11. Changes to Terms',
                        'We may update these Terms from time to time. Continued use of the App after changes constitutes acceptance of the new Terms. We will notify users of significant changes through the App.'),
                    _section(context, '12. Contact',
                        'If you have questions about these Terms, please contact us through the App\'s support channels.'),
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
