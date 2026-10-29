import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valora_mobile/app.dart';
import 'package:valora_mobile/core/ai_service.dart';
import 'package:valora_mobile/core/backend_api.dart';
import 'package:valora_mobile/core/session_controller.dart';
import 'package:valora_mobile/core/models.dart';

void main() {
  testWidgets(
    'chat prioritizes suggestions and keeps composer usable on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final font in {'Manrope': 'Manrope', 'DM Sans': 'DMSans'}.entries) {
        await (FontLoader(
          font.key,
        )..addFont(rootBundle.load('assets/fonts/${font.value}.ttf'))).load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final api = BackendApi(
        baseUrl: 'https://chat.test',
        accessToken: () async => 'test',
      );
      addTearDown(api.close);
      final session = SessionController()
        ..onboarded = true
        ..aiService = ValoraAiService(api);
      addTearDown(session.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: ValoraApp(session: session),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Suggest a quick lunch'), findsOneWidget);
      expect(find.byTooltip('Voice input'), findsNothing);
      expect(find.byTooltip('Send request').hitTestable(), findsOneWidget);
      expect(find.text('0/12000'), findsNothing);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_CHAT')) {
        final image = await tester.runAsync(
          () =>
              (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(),
        );
        final bytes = await tester.runAsync(
          () => image!.toByteData(format: ui.ImageByteFormat.png),
        );
        await tester.runAsync(() async {
          await File(
            'build/chat-redesign-home.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        });
        image!.dispose();
      }
      await tester.tap(find.text('My pantry'));
      await tester.pumpAndSettle();
      expect(find.text('What you have'), findsOneWidget);
      expect(tester.takeException(), isNull);
      session.clearChat();
      session.chat.addAll([
        const ChatEntry('Can you suggest a quick lunch?', true),
        const ChatEntry(
          '**Try a chickpea and cucumber bowl**\n\n- Ready in 10 minutes.',
          false,
          source: 'nebius',
          model: 'nvidia/nemotron-3-super-120b-a12b',
        ),
      ]);
      session.conversation = true;
      session.setShareFoodContext(true);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('chickpea and cucumber', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('**Try'), findsNothing);
      expect(find.text('Suggest a quick lunch'), findsNothing);
      if (const bool.fromEnvironment('CAPTURE_CHAT')) {
        final image = await tester.runAsync(
          () =>
              (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(),
        );
        final bytes = await tester.runAsync(
          () => image!.toByteData(format: ui.ImageByteFormat.png),
        );
        await tester.runAsync(() async {
          await File(
            'build/chat-redesign-conversation.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        });
        image!.dispose();
      }
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Send request').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
