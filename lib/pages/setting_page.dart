import 'package:flutter/material.dart';

import '../core/storage.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

const List<(String, String)> kOrientations = [
  ('auto', '自动'),
  ('portrait', '竖屏'),
  ('landscape', '横屏'),
];

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = Storage.instance.getSettings();
  }

  Future<void> _patch({
    String? orientation,
    bool? brightness,
    bool? lowPower,
  }) async {
    final next = await Storage.instance.patchSettings(
      defaultOrientation: orientation,
      autoMaxBrightness: brightness,
      lowPowerMode: lowPower,
    );
    if (mounted) setState(() => _settings = next);
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空本地数据'),
        content: const Text(
            '所有灯牌、设置、快捷短语都会被删除，且无法恢复。确定继续？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('清空', style: TextStyle(color: LColors.red))),
        ],
      ),
    );
    if (ok != true) return;
    await Storage.instance.clearAll();
    if (!mounted) return;
    setState(() => _settings = Storage.instance.getSettings());
    toast(context, '已清空');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('默认行为', style: TextStyle(fontSize: 17))),
      body: ListView(
        padding: const EdgeInsets.all(LSize.pagePad),
        children: [
          _Group(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('默认方向',
                    style: TextStyle(fontSize: 13, color: LColors.gray)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: kOrientations.map((o) {
                      final on = _settings.defaultOrientation == o.$1;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _patch(orientation: o.$1),
                          child: Container(
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: on ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: on
                                  ? [
                                      BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1))
                                    ]
                                  : null,
                            ),
                            child: Text(o.$2,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: on ? LColors.ink : LColors.gray2,
                                    fontWeight: on
                                        ? FontWeight.w600
                                        : FontWeight.normal)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          _Group(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('进入播放页自动拉满亮度',
                  style: TextStyle(fontSize: 15)),
              subtitle: const Text('退出时恢复原亮度',
                  style: TextStyle(fontSize: 11, color: LColors.gray2)),
              value: _settings.autoMaxBrightness,
              activeThumbColor: LColors.red,
              onChanged: (v) => _patch(brightness: v),
            ),
          ),
          _Group(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('省电模式', style: TextStyle(fontSize: 15)),
              subtitle: const Text('关闭发光、限制帧率，长时间举牌更耐用',
                  style: TextStyle(fontSize: 11, color: LColors.gray2)),
              value: _settings.lowPowerMode,
              activeThumbColor: LColors.red,
              onChanged: (v) => _patch(lowPower: v),
            ),
          ),
          _Group(
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: _clear,
                child: const Text('清空本地数据',
                    style: TextStyle(fontSize: 15, color: LColors.red)),
              ),
            ),
          ),
          const Center(
            child: Text('清空后所有灯牌都无法找回，请谨慎操作',
                style: TextStyle(fontSize: 11, color: LColors.gray3)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final Widget child;
  const _Group({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
