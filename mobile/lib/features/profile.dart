import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/session_controller.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'ai_settings.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.session, required this.onPanel});
  final SessionController session;
  final ValueChanged<Panel> onPanel;
  @override
  Widget build(BuildContext context) {
    final p = session.profile;
    return PageContent(
      pageKey: 'profile',
      children: [
        const Eyebrow('You, in your own words'),
        const Heading(
          'Your profile.',
          subtitle: 'Review what Valora knows. Correct anything, any time.',
        ),
        if (session.backendApi != null) ...[
          const Eyebrow('Account'),
          Surface(
            child: ActionRow(
              session.signedIn
                  ? Icons.verified_user_outlined
                  : Icons.login_rounded,
              session.signedIn
                  ? 'Google account connected'
                  : 'Continue with Google',
              session.signedIn
                  ? 'Account connected · tap to sign out'
                  : 'Sign in to connect your Valora account',
              () async {
                try {
                  if (session.signedIn) {
                    await session.signOut();
                  } else {
                    await session.signInWithGoogle();
                  }
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Google sign-in is not ready yet. Check your connection and try again.',
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
        Surface(
          child: Row(
            children: [
              Container(
                width: 53,
                height: 53,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ValoraColors.mint,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 29,
                  color: ValoraColors.forest,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your personal space',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${p.pattern} · ${p.resolved(p.cuisines, p.otherCuisine)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: ValoraColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Eyebrow('Food & routine'),
        Surface(
          child: Column(
            children: [
              ActionRow(
                Icons.shield_outlined,
                'Food rules',
                'Allergies, exclusions and health context',
                () => onPanel(Panel.rules),
              ),
              const Divider(height: 1),
              ActionRow(
                Icons.tune_outlined,
                'Planning preferences',
                '${money(p.budget)}/week · up to ${p.cookingMinutes} min',
                () => onPanel(Panel.practical),
              ),
              const Divider(height: 1),
              ActionRow(
                Icons.kitchen_outlined,
                'Pantry & leftovers',
                '${session.pantry.length} estimated items at home',
                () => onPanel(Panel.pantry),
              ),
            ],
          ),
        ),
        const Eyebrow('Your information'),
        Surface(
          child: Column(
            children: [
              ActionRow(
                Icons.memory_outlined,
                'Memory & saved facts',
                '${session.facts.length} details · review, pause or remove',
                () => onPanel(Panel.memory),
              ),
              const Divider(height: 1),
              ActionRow(
                Icons.description_outlined,
                'Reports & photos',
                'Review facts before saving them',
                () => onPanel(Panel.reports),
              ),
              const Divider(height: 1),
              ActionRow(
                Icons.lock_outline_rounded,
                'Privacy & control',
                'Your information, your decisions',
                () => onPanel(Panel.privacy),
              ),
            ],
          ),
        ),
        const Eyebrow('App preferences'),
        Surface(
          child: ActionRow(
            Icons.auto_awesome_outlined,
            'AI & model settings',
            session.backendApi == null
                ? 'Connect the Valora API to enable AI'
                : 'Personal meal assistant · cloud consent',
            () async {
              if (session.backendApi != null) await session.refreshAiSettings();
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AiSettingsPage(session: session),
                ),
              );
            },
          ),
        ),
        const Eyebrow('App preferences'),
        Surface(
          child: Column(
            children: [
              ActionRow(
                Icons.notifications_none_rounded,
                'Notifications',
                '${p.planningTime} plans · ${session.frequency.toLowerCase()}',
                () => onPanel(Panel.settings),
              ),
              const Divider(height: 1),
              ActionRow(
                Icons.credit_card_outlined,
                'Payment methods',
                'No payment method connected',
                () => onPanel(Panel.payments),
              ),
            ],
          ),
        ),
        InfoNote(
          session.backendApi == null
              ? 'This preview keeps your details for this session.'
              : 'Your profile, preferences and saved facts sync with your account. Pantry and meal plans are still kept for this session.',
        ),
      ],
    );
  }
}
