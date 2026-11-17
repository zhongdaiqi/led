import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:led/app.dart';
import 'package:led/core/storage.dart';
import 'package:led/core/templates.dart';
import 'package:led/core/texture.dart';
import 'package:led/models.dart';
import 'package:led/pages/play_page.dart';
import 'package:led/pages/privacy_page.dart';
import 'package:led/widgets/led_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('内置模板数量与分类', () {
    expect(kTemplates.length, 20);
    expect(kCategories.length, 6);
    expect(searchTemplates('机场').map((t) => t.id), contains('tpl_airport'));
    expect(searchTemplates('表白').map((t) => t.id), contains('tpl_yingyuan'));
  });

  test('Storage 默认值', () {
    final s = Storage.instance.getSettings();
    expect(s.autoMaxBrightness, isTrue);
    expect(Storage.instance.getPhrases().length, 16);
  });

  test('纹理按逻辑坐标烘焙，不随高 dpr 放大（防止文字被裁）', () {
    // ui.Picture 是矢量指令、drawPicture 按逻辑坐标 1:1 重放，
    // 所以任何 dpr 下 scale 都必须为 1，否则文字会被放大到屏幕外。
    for (final dpr in [1.0, 2.0, 2.75, 3.0, 4.0]) {
      expect(pickScale(360, 200, dpr), 1.0,
          reason: 'dpr=$dpr 时不应放大纹理');
    }
    // 超大逻辑画布只缩小、不放大
    expect(pickScale(8192, 200, 3.0), closeTo(0.5, 0.001));
  });

  // 真机回归：「亮牌后滚动牌不滚、闪烁牌不闪」。
  // 之前 _startLoop() 只在换牌/切省电时经 _restartLoop() 被调用，
  // 首次进播放页 ticker 从未创建，动画完全静止。
  void mockBridge() {
    const channel = MethodChannel('com.zhongdaiqi.led/bridge');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getBrightness') return 1.0;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  }

  testWidgets('首次亮牌：滚动牌自动滚动', (tester) async {
    mockBridge();
    await tester.pumpWidget(MaterialApp(
      home: PlayPage(args: {
        'preset': Preset(text: 'ABCDEFGHIJ', mode: 'scroll-h', speed: 90),
      }),
    ));
    await tester.pump();

    // Slider 内部也有 CustomPaint，必须按 painter 类型精确定位舞台画布
    LedPainter painterAt() => tester.widget<CustomPaint>(find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is LedPainter,
        )).painter as LedPainter;
    final before = painterAt().offsetX;
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    expect(painterAt().offsetX, isNot(before),
        reason: '首次进入播放页，滚动牌 offsetX 应随时间变化');
  });

  testWidgets('首次亮牌：闪烁牌自动闪烁', (tester) async {
    mockBridge();
    await tester.pumpWidget(MaterialApp(
      home: PlayPage(args: {
        'preset': Preset(text: '闪烁测试', mode: 'blink'),
      }),
    ));
    await tester.pump();

    // Slider 内部也有 CustomPaint，必须按 painter 类型精确定位舞台画布
    LedPainter painterAt() => tester.widget<CustomPaint>(find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is LedPainter,
        )).painter as LedPainter;
    // 正常闪烁周期 900ms、亮 560ms：150ms 应为亮，700ms 应为暗
    await tester.pump(const Duration(milliseconds: 150));
    final litAlpha = painterAt().alpha;
    await tester.pump(const Duration(milliseconds: 550));
    expect(painterAt().alpha, isNot(litAlpha),
        reason: '首次进入播放页，闪烁牌 alpha 应随时间切换');
  });

  testWidgets('首次启动必须先同意隐私协议，同意后进入主界面', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await Storage.instance.init();

    await tester.pumpWidget(const LedApp());
    await tester.pump();

    expect(find.text('隐私政策'), findsWidgets);
    expect(find.byType(MainShell), findsNothing,
        reason: '未同意时不能进入主界面');

    await tester.tap(find.text('同意并继续'));
    await tester.pumpAndSettle();

    expect(find.byType(MainShell), findsOneWidget);
    expect(Storage.instance.getSettings().privacyVersion,
        kPrivacyPolicyVersion);

    // 已同意版本后再次启动，不应重复弹窗
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const LedApp());
    await tester.pump();
    expect(find.byType(PrivacyGate), findsNothing);
    expect(find.byType(MainShell), findsOneWidget);
  });
}
