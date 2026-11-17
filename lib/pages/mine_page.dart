import 'package:flutter/material.dart';

import '../core/storage.dart';
import '../core/templates.dart';
import '../core/thumb.dart';
import '../models.dart';
import '../widgets/common.dart';
import '../theme.dart';
import 'about_page.dart';
import 'editor_page.dart';
import 'play_page.dart';
import 'setting_page.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key});

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  List<Preset> _list = [];
  List<Template> _favs = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    final templates = Storage.instance
        .getFavorites()
        .map(getTemplate)
        .whereType<Template>()
        .toList();
    setState(() {
      _list = Storage.instance.getRecentPresets();
      _favs = templates;
    });
  }

  Future<void> _open(Widget page) async {
    await pushPage(context, page);
    _refresh();
  }

  Future<void> _unfav(Template t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消收藏'),
        content: const Text('从收藏里移掉这块模板？灯牌本身不受影响。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('移掉')),
        ],
      ),
    );
    if (confirm == true) {
      await Storage.instance.toggleFavorite(t.id);
      _refresh();
    }
  }

  Future<void> _showActions(Preset item) async {
    final action = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('重命名'),
                onTap: () => Navigator.pop(ctx, 0)),
            ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('复制一份'),
                onTap: () => Navigator.pop(ctx, 1)),
            ListTile(
                leading: const Icon(Icons.delete_outline, color: LColors.red),
                title: const Text('删除',
                    style: TextStyle(color: LColors.red)),
                onTap: () => Navigator.pop(ctx, 2)),
          ],
        ),
      ),
    );
    if (action == 0) {
      _rename(item);
    } else if (action == 1) {
      _duplicate(item);
    } else if (action == 2) {
      _remove(item);
    }
  }

  Future<void> _rename(Preset item) async {
    final controller = TextEditingController(text: item.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '给这块牌起个名字'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定')),
        ],
      ),
    );
    final name = controller.text.trim();
    controller.dispose();
    if (ok != true || name.isEmpty) return;
    final saved = await Storage.instance.upsertPreset(item..name = name);
    if (!mounted) return;
    if (saved == null) toast(context, '存储空间不足');
    _refresh();
  }

  /// 复制：新牌置顶、名字加"副本"、清 lastUsedAt（否则立刻冒充最近使用）
  Future<void> _duplicate(Preset item) async {
    final copy = item.copy()
      ..id = ''
      ..lastUsedAt = 0
      ..usageCount = 0
      ..name = '${item.name.isEmpty ? '灯牌' : item.name} 副本';
    final saved = await Storage.instance.upsertPreset(copy);
    if (!mounted) return;
    if (saved == null) {
      toast(context, '存储空间不足');
      return;
    }
    _refresh();
    toast(context, '已复制');
  }

  Future<void> _remove(Preset item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除灯牌'),
        content: Text('确定删除「${item.name}」？删除后不可恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除', style: TextStyle(color: LColors.red))),
        ],
      ),
    );
    if (ok != true) return;
    await Storage.instance.removePreset(item.id);
    _refresh();
    if (!mounted) return;
    toast(context, '已删除');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: LSize.pagePad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            if (_favs.isNotEmpty) ...[
              const SectionTitle(title: '收藏的模板', trailing: '长按取消收藏'),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _favs.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final t = _favs[i];
                    final th = thumbOf(t.toPreset(),
                        boxW: 104, maxSize: 26); // 208rpx / 52rpx
                    return GestureDetector(
                      onTap: () => _open(EditorPage(args: {'template': t.id})),
                      onLongPress: () => _unfav(t),
                      child: SizedBox(
                        width: 120,
                        child: Column(
                          children: [
                            Container(
                              height: 70,
                              decoration: BoxDecoration(
                                color: hexColor(th.bg),
                                borderRadius: BorderRadius.circular(8),
                                border: th.light
                                    ? Border.all(
                                        color: Colors.black.withValues(alpha: 0.08))
                                    : null,
                              ),
                              clipBehavior: Clip.antiAlias,
                              alignment: Alignment.center,
                              child: Text(th.text,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.visible,
                                  style: TextStyle(
                                      color: hexColor(th.color),
                                      fontSize: th.size,
                                      fontWeight: FontWeight.w700,
                                      shadows: th.shadows)),
                            ),
                            const SizedBox(height: 5),
                            Text(t.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, color: LColors.gray)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            SectionTitle(
                title: '我的灯牌',
                trailing: '＋ 新建',
                onTap: () => _open(const EditorPage(args: {}))),
            if (_list.isEmpty)
              const EmptyHint(
                  line1: '还没有保存的灯牌', line2: '在编辑器点「亮牌」会自动保存')
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: List.generate(_list.length, (i) {
                    final p = _list[i];
                    return Column(
                      children: [
                        if (i > 0) const Divider(height: 1, color: LColors.line),
                        ListTile(
                          minVerticalPadding: 12,
                          leading: GestureDetector(
                            onTap: () => _open(PlayPage(args: {'id': p.id})),
                            child: LedThumb(
                                bg: p.bg.color,
                                color: p.style.color,
                                text: p.text,
                                width: 48,
                                height: 48,
                                fontSize: 9),
                          ),
                          title: Text(p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15, color: LColors.ink)),
                          subtitle: Text('用过 ${p.usageCount} 次',
                              style: const TextStyle(
                                  fontSize: 11, color: LColors.gray2)),
                          onTap: () => _open(PlayPage(args: {'id': p.id})),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    _open(EditorPage(args: {'id': p.id})),
                                child: const Text('编辑',
                                    style:
                                        TextStyle(fontSize: 13, color: LColors.blue)),
                              ),
                              IconButton(
                                onPressed: () => _showActions(p),
                                icon: const Icon(Icons.more_horiz,
                                    size: 20, color: LColors.gray2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            const SectionTitle(title: '设置'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    title: const Text('默认行为', style: TextStyle(fontSize: 15)),
                    trailing: const Icon(Icons.chevron_right,
                        color: LColors.gray3),
                    onTap: () => _open(const SettingPage()),
                  ),
                  const Divider(height: 1, color: LColors.line),
                  ListTile(
                    title: const Text('关于与隐私', style: TextStyle(fontSize: 15)),
                    trailing: const Icon(Icons.chevron_right,
                        color: LColors.gray3),
                    onTap: () => _open(const AboutPage()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text('所有内容只存在本机，不上传、不同步',
                  style: TextStyle(fontSize: 11, color: LColors.gray3)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
