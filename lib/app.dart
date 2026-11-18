import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/storage.dart';
import 'pages/about_page.dart';
import 'pages/editor_page.dart';
import 'pages/home_page.dart';
import 'pages/mine_page.dart';
import 'pages/play_page.dart';
import 'pages/privacy_page.dart';
import 'pages/setting_page.dart';
import 'pages/talk_page.dart';
import 'pages/template_page.dart';
import 'theme.dart';

export 'core/bus.dart';

class LedApp extends StatefulWidget {
  const LedApp({super.key});

  @override
  State<LedApp> createState() => _LedAppState();
}

class _LedAppState extends State<LedApp> {
  /// main() 已 await Storage.init()，这里同步读即可。
  /// 版本低于当前协议（含从未同意的 0）都要先弹隐私政策。
  late bool _privacyAgreed;

  @override
  void initState() {
    super.initState();
    _privacyAgreed =
        Storage.instance.getSettings().privacyVersion >= kPrivacyPolicyVersion;
  }

  void _onPrivacyAccepted() {
    setState(() => _privacyAgreed = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '电子灯牌',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: LColors.red),
        scaffoldBackgroundColor: LColors.bg,
        fontFamily: 'sans-serif',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: LColors.ink,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
      ),
      home: _privacyAgreed
          ? const MainShell()
          : PrivacyGate(onAccepted: _onPrivacyAccepted),
      onGenerateRoute: _onGenerateRoute,
    );
  }

  static Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments is Map
        ? Map<String, dynamic>.from(settings.arguments as Map)
        : <String, dynamic>{};
    Widget page;
    switch (settings.name) {
      case '/play':
        page = PlayPage(args: args);
        break;
      case '/editor':
        page = EditorPage(args: args);
        break;
      case '/talk':
        page = const TalkPage();
        break;
      case '/setting':
        page = const SettingPage();
        break;
      case '/about':
        page = const AboutPage();
        break;
      default:
        return null;
    }
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}

/// 全局 Tab 索引，供子页面跳到「我的」等场景使用。
final ValueNotifier<int> kTabIndex = ValueNotifier<int>(0);

/// 3 个 Tab：举牌 / 模板 / 我的。
/// IndexedStack 保活，避免切 Tab 时重建画布。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _pages = const [HomePage(), TemplatePage(), MinePage()];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: kTabIndex,
      builder: (context, index, _) => Scaffold(
        body: IndexedStack(index: index, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => kTabIndex.value = i,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          indicatorColor: const Color(0xFFFFEBEB),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.front_hand_outlined), selectedIcon: Icon(Icons.front_hand), label: '举牌'),
            NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: '模板'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
          ],
        ),
      ),
    );
  }
}
