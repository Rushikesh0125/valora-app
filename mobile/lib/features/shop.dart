import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/session_controller.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class ShopPage extends StatelessWidget {
  const ShopPage({
    super.key,
    required this.session,
    required this.onPanel,
    required this.onBack,
  });
  final SessionController session;
  final ValueChanged<Panel> onPanel;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    final s = session;
    if (!s.canUseQuote || !s.planReviewed) {
      return PageContent(
        children: [
          const Heading(
            'Review the draft first.',
            subtitle:
                'The grocery estimate needs to match your current meals and pantry.',
          ),
          FilledButton(onPressed: onBack, child: const Text('Back to plan')),
        ],
      );
    }
    return PageContent(
      pageKey: 'shop',
      children: [
        const Eyebrow('Example · No live quotes'),
        const Heading(
          'Your grocery options.',
          subtitle: 'Compare the full price, then review the exact basket.',
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Eyebrow('From your pantry'),
            TextButton(
              onPressed: () => onPanel(Panel.pantry),
              child: const Text('Manage'),
            ),
          ],
        ),
        Surface(
          child: Column(
            children: s.pantry
                .map((p) => SummaryRow(p.name, p.amount))
                .toList(),
          ),
        ),
        const Eyebrow('To buy · 5 items'),
        Surface(
          child: Column(
            children: s.basket
                .map((row) => SummaryRow(row.$1, row.$2))
                .toList(),
          ),
        ),
        const Eyebrow('Illustrative offers'),
        ...SessionController.grocers.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: InkWell(
              onTap: () => s.selectGrocer(entry.key),
              borderRadius: BorderRadius.circular(19),
              child: Surface(
                selected: s.selectedGrocer == entry.key,
                child: Row(
                  children: [
                    Icon(
                      s.selectedGrocer == entry.key
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: ValoraColors.forest,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.value.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.value.slot,
                            style: const TextStyle(
                              fontSize: 11,
                              color: ValoraColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      money(entry.value.total),
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: ValoraColors.forest,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const InfoNote(
          'Sample prices demonstrate the approval flow. The final basket includes all example fees.',
          amber: true,
        ),
        FilledButton(
          onPressed: () => onPanel(Panel.basket),
          child: const Text('Review exact basket →'),
        ),
      ],
    );
  }
}
