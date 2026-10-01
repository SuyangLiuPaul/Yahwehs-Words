import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/pages/sermons_page.dart';
import 'package:yahwehs_words/providers/main_provider.dart';
import 'package:yahwehs_words/services/sermon_audio_service.dart';
import 'package:yahwehs_words/services/sermon_service.dart';
import 'package:yahwehs_words/utils/app_nav.dart';

class _Main extends ChangeNotifier implements MainProvider {
  @override
  Future<void> saveCurrentState() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final name = utf8.decode(message!.buffer
          .asUint8List(message.offsetInBytes, message.lengthInBytes));
      final file = File(name);
      return file.existsSync()
          ? ByteData.sublistView(file.readAsBytesSync())
          : null;
    });
    for (final name in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events'
    ]) {
      messenger.setMockMethodCallHandler(
          MethodChannel(name), (call) async => null);
    }
    messenger.allMessagesHandler = (channel, handler, message) {
      if (handler == null &&
          channel.startsWith('xyz.luan/audioplayers/events/')) {
        return Future<ByteData?>.value(
            const StandardMethodCodec().encodeSuccessEnvelope(null));
      }
      return handler != null
          ? handler(message)
          : messenger.delegate.send(channel, message);
    };
  });
  tearDownAll(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger.allMessagesHandler = null);
  tearDown(() => Get.reset());
  Future<void> mount(WidgetTester tester, String id) async {
    SharedPreferences.setMockInitialValues(
        {'sermons_last_read': id, 'sermons_list_scroll': 99999.0});
    await tester.runAsync(() async {
      await SermonService.instance.loadByTopic();
      await SermonService.instance.loadRefs();
      await SermonAudioService.instance.load();
    });
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppSettings>(create: (_) => AppSettings()),
          ChangeNotifierProvider<MainProvider>(create: (_) => _Main())
        ],
        child: GetMaterialApp(
            home: Scaffold(
                body: FilledButton(
                    onPressed: () => pushPage(const SermonsPage(),
                        routeName: '/sermons',
                        arguments: SermonResumeRequest(id)),
                    child: const Text('RESUME'))),
            getPages: [
              GetPage(
                  name: '/sermons',
                  page: () => SermonsPage(
                      resumeSermonId:
                          (Get.arguments as SermonResumeRequest).sermonId)),
              GetPage(
                  name: '/sermons/:id',
                  page: () => Scaffold(
                      appBar: AppBar(),
                      body: Text('DETAIL ${Get.parameters['id']}'))),
            ])));
    await tester.pump();
    await tester.tap(find.text('RESUME'));
    for (var n = 0; n < 20; n++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
      'resume opens detail once; Back returns to expanded current sermon',
      (tester) async {
    await mount(tester, '207');
    expect(find.text('DETAIL 207'), findsOneWidget);
    Get.back();
    for (var n = 0; n < 8; n++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(SermonsPage), findsOneWidget);
    expect(find.text('DETAIL 207'), findsNothing);
    final title = (await SermonService.instance.loadIndex())
        .firstWhere((s) => s.id == '207')
        .localizedTitle('zh-Hans');
    final tile = find.text(title);
    expect(tile, findsOneWidget);
    final rect = tester.getRect(tile);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThan(tester.view.physicalSize.height));
    expect(tester.takeException(), isNull);
    // Rebuilds and the highlight timer must not reopen the detail.
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('DETAIL 207'), findsNothing);
  });
  testWidgets(
      'obsolete saved sermon opens the list without a dead detail route',
      (tester) async {
    await mount(tester, 'deleted-id');
    expect(find.byType(SermonsPage), findsOneWidget);
    expect(find.text('DETAIL deleted-id'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });
}
