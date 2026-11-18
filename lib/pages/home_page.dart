import 'package:flutter/material.dart';

import '../app.dart';
import '../core/storage.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'editor_page.dart';
import 'play_page.dart';
import 'talk_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Preset> _recents = [];

  @override
  void initState() {
    super.initState();
    _refresh();
    kLibraryChanged.addListener(_refresh);
  }

  @override
  void dispose() {
    kLibraryChanged.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _recents = Storage.instance.getRecentPresets(8));
  }

  /// 从编辑/播放页返回时刷新（小程序的 onShow）
  Future<void> _open(Widget page) async {
    await pushPage(context, page);
    _refresh();
  }

  void _play([String? id]) {
    _open(PlayPage(args: id == null ? const {} : {'id': id}));
  }

  @override
  Widget build(BuildContext context) {
    final hasRecents = _recents.isNotEmpty;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: LSize.pagePad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Text('电子灯牌',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: LColors.ink,
                    letterSpacing: 1)),
            const SizedBox(height: 5),
            const Text('把手机变成一块灯牌',
                style: TextStyle(fontSize: 13, color: LColors.gray)),
            const SizedBox(height: 24),

            // 主按钮：现场场景唯一重点
            Material(
              borderRadius: BorderRadius.circular(16),
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _play(hasRecents ? _recents.first.id : null),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 116,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                        colors: [Color(0xFFFF2D2D), Color(0xFFFF5A3C)]),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFFF2D2D).withValues(alpha: 0.28),
                          blurRadius: 16,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('立即亮牌',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3)),
                      const SizedBox(height: 7),
                      Text(
                        hasRecents ? '用最近一块 · ${_recents.first.name}' : '从默认样式开始',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SectionTitle(
              title: '我的灯牌',
              trailing: '全部 ›',
              onTap: () => kTabIndex.value = 2,
            ),

            if (hasRecents)
              SizedBox(
                height: 116,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recents.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    if (i == _recents.length) {
                      return GestureDetector(
                        onTap: () => _open(const EditorPage(args: {})),
                        child: Column(
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: LColors.gray3,
                                    style: BorderStyle.solid),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(Icons.add,
                                  size: 28, color: LColors.gray2),
                            ),
                            const SizedBox(height: 6),
                            const Text('新建',
                                style:
                                    TextStyle(fontSize: 12, color: LColors.gray2)),
                          ],
                        ),
                      );
                    }
                    final p = _recents[i];
                    return GestureDetector(
                      onTap: () => _play(p.id),
                      child: Column(
                        children: [
                          LedThumb(
                            bg: p.bg.color,
                            color: p.style.color,
                            text: p.name,
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 90,
                            child: Text(p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 12, color: LColors.gray2)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              )
            else
              const EmptyHint(
                  line1: '还没有灯牌', line2: '点「立即亮牌」直接开始，会自动记住'),

            const SizedBox(height: 24),

            // 对话牌入口：整宽卡片，文案用处境而不是功能名
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => _open(const TalkPage()),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Text('💬', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('不方便说话？用对话牌',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: LColors.ink)),
                            SizedBox(height: 3),
                            Text('打字给对方看，面对面的大字',
                                style:
                                    TextStyle(fontSize: 12, color: LColors.gray)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: LColors.gray3),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Center(
              child: Text('全离线可用 · 不上传任何内容',
                  style: TextStyle(fontSize: 11, color: LColors.gray3)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
