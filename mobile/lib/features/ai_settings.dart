import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/session_controller.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class AiSettingsPage extends StatelessWidget {
  const AiSettingsPage({super.key, required this.session});
  final SessionController session;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI & model settings')),
    body: ListenableBuilder(
      listenable: session,
      builder: (context, _) => PageContent(
        children: [
          const Heading(
            'Choose how Valora uses AI',
            subtitle: 'Enable cloud AI for personalized meal conversations.',
          ),
          if (session.backendApi == null)
            const InfoNote(
              'The Valora API is not connected. Set VALORA_API_URL and connect a signed-in session to use cloud AI settings or send AI requests.',
              amber: true,
            )
          else ...[
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Personal meal assistant',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'When enabled, cloud AI receives your messages, recent conversation and eligible recipes. Saved food restrictions filter meals on the server. Cuisine lookup and taste analysis receive only public cuisine signals—not your allergies, health details or raw chat. Saved health fields are not automatically shared; anything you type is sent. You can disable consent at any time.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: ValoraColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      session.aiService?.localOnly == true
                          ? 'Cloud AI is not used in this test'
                          : session.cloudAiConsent == true
                          ? 'Cloud AI is on'
                          : 'Cloud AI is off',
                    ),
                    value: session.aiService?.localOnly == true
                        ? false
                        : session.cloudAiConsent ?? false,
                    onChanged:
                        session.aiService?.localOnly == true ||
                            session.aiSettingsBusy ||
                            session.cloudAiConsent == null
                        ? null
                        : session.setCloudAiConsent,
                  ),
                ],
              ),
            ),
          ],
          if (session.aiService?.onDeviceEnabled == true) ...[
            const SizedBox(height: 12),
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Unlock AI on your device',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    session.modelInstalled
                        ? 'Private, on-device AI is ready. Your chat requests run locally on this device.'
                        : 'Get private AI chat that works on this device. Valora will download the Gemma model once; your AI prompts stay on your device.',
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: ValoraColors.muted,
                    ),
                  ),
                  if (!session.modelInstalled) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'One-time download · 2.59 GB · Wi-Fi recommended',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ValoraColors.forest,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (session.modelDownloadProgress >= 0) ...[
                    LinearProgressIndicator(
                      value: session.modelDownloadProgress / 100,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${session.modelDownloadProgress}% downloaded',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                  if (!session.modelInstalled)
                    FilledButton.icon(
                      onPressed: session.aiSettingsBusy
                          ? null
                          : session.installGemma,
                      icon: const Icon(Icons.download),
                      label: Text(
                        session.aiSettingsBusy ? 'Downloading…' : 'Unlock AI',
                      ),
                    ),
                  TextButton(
                    onPressed: () => _showGemmaLicense(context),
                    child: const Text('Gemma 4 license and model source'),
                  ),
                ],
              ),
            ),
          ] else
            const InfoNote(
              'No local model download is required. Saved-state questions still work without cloud AI.',
              amber: true,
            ),
          if (session.aiSettingsMessage.isNotEmpty)
            InfoNote(session.aiSettingsMessage),
          if (session.aiSettingsBusy && session.modelDownloadProgress < 0)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            ),
          const InfoNote(
            'Valora AI is for analytical food-planning support. It does not diagnose, prescribe treatment, calculate verified nutrition values, guarantee allergen safety, or place orders.',
          ),
        ],
      ),
    ),
  );

  Future<void> _showGemmaLicense(BuildContext context) async {
    final license = await rootBundle.loadString(
      'assets/licenses/GEMMA-4-APACHE-2.0.txt',
    );
    final notice = await rootBundle.loadString(
      'assets/licenses/GEMMA-4-NOTICE.txt',
    );
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gemma 4 E2B · Apache 2.0'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Text(
              '$notice\n$license',
              style: const TextStyle(fontSize: 11, height: 1.4),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
