import 'dart:math';
import 'package:flutter/material.dart';
import '../core/session_controller.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key, required this.session, required this.onLog});
  final SessionController session;
  final VoidCallback onLog;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = List.generate(7, (i) => DateUtilsLocal.offset(today, i - 6));
    final counts = dates
        .map(
          (d) => session.intake
              .where(
                (m) =>
                    m.at.year == d.year &&
                    m.at.month == d.month &&
                    m.at.day == d.day,
              )
              .length,
        )
        .toList();
    final total = counts.fold(0, (a, b) => a + b);
    final maxCount = max(1, counts.reduce(max));
    return PageContent(
      pageKey: 'insights',
      children: [
        const Eyebrow('Your rhythm'),
        const Heading(
          'Small steps,\na clearer picture.',
          subtitle: 'Based on meals you confirm. Orders do not count as eaten.',
        ),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reported meals · last 7 days',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 9),
              Text(
                '$total',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 35,
                  fontWeight: FontWeight.w800,
                  color: ValoraColors.forest,
                ),
              ),
              const Text(
                'meals confirmed by you',
                style: TextStyle(fontSize: 11, color: ValoraColors.muted),
              ),
              const SizedBox(height: 19),
              SizedBox(
                height: 90,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Semantics(
                          label: '${dateLabel(dates[i])}: ${counts[i]} meals',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  height: counts[i] == 0
                                      ? 8
                                      : 60 * counts[i] / maxCount,
                                  decoration: BoxDecoration(
                                    color: counts[i] == 0
                                        ? ValoraColors.mint
                                        : ValoraColors.forest,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  dateLabel(dates[i]).substring(0, 1),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: ValoraColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const InfoNote(
          'There is not enough verified intake data to calculate nutrient or macro trends yet.',
          title: 'Coverage before conclusions',
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(child: Eyebrow('Confirmed meal log')),
            TextButton.icon(
              onPressed: onLog,
              icon: const Icon(Icons.add, size: 17),
              label: const Text('Log a meal'),
            ),
          ],
        ),
        if (session.intake.isEmpty)
          const Surface(
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Column(
                children: [
                  Icon(
                    Icons.restaurant_menu_rounded,
                    color: ValoraColors.forest,
                    size: 32,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No meals logged yet',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Confirm a meal and portion to start your picture.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: ValoraColors.muted),
                  ),
                ],
              ),
            ),
          )
        else
          ...session.intake.map(
            (meal) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${meal.portion} · ${dateLabel(meal.at)} · confirmed by you',
                      style: const TextStyle(
                        fontSize: 11,
                        color: ValoraColors.muted,
                      ),
                    ),
                    if (meal.sourceName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'From pantry: ${meal.sourceName}${meal.remaining == null ? '' : ' · ${meal.remaining} left'}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: ValoraColors.forest,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
