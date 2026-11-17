import 'package:flutter/material.dart';

import '../core/storage.dart';
import '../core/templates.dart';
import '../core/thumb.dart';
import '../widgets/common.dart';
import '../theme.dart';
import 'editor_page.dart';

class TemplatePage extends StatefulWidget {
  const TemplatePage({super.key});

  @override
  State<TemplatePage> createState() => _TemplatePageState();
}

class _TemplatePageState extends State<TemplatePage> {
  String _active = '全部';
  final TextEditingController _search = TextEditingController();
  List<Template> _list = [];
  Set<String> _favs = {};

  @override
  void initState() {
    super.initState();
    _apply();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _apply() {
    final kw = _search.text.trim();
    final picked = searchTemplates(kw, kw.isEmpty ? _active : '全部');
    if (!mounted) return;
    setState(() {
      _list = picked;
      _favs = Storage.instance.getFavorites().toSet();
    });
  }

  Future<void> _openEditor(String id) async {
    await pushPage(context, EditorPage(args: {'template': id}));
    _apply();
  }

  Future<void> _toggleFav(Template t) async {
    final on = await Storage.instance.toggleFavorite(t.id);
    if (!mounted) return;
    setState(() {
      if (on) {
        _favs.add(t.id);
      } else {
        _favs.remove(t.id);
      }
    });
    if (context.mounted) toast(context, on ? '已收藏' : '已取消收藏');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: LSize.pagePad),
        child: Column(
          children: [
            const SizedBox(height: 8),
            // 搜索
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFECECF0)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Text('搜',
                      style: TextStyle(fontSize: 11, color: LColors.gray3)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) {
                        if (_active != '全部') {
                          setState(() => _active = '全部');
                        }
                        _apply();
                      },
                      decoration: const InputDecoration(
                        hintText: '搜场景，比如「机场」「表白」',
                        hintStyle:
                            TextStyle(fontSize: 13, color: LColors.gray3),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13, color: LColors.ink),
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                  if (_search.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _search.clear();
                        _apply();
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(Icons.close, size: 16, color: LColors.gray2),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 分类
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kCategories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final name = kCategories[i];
                  final on = name == _active;
                  return GestureDetector(
                    onTap: () {
                      _search.clear();
                      setState(() => _active = name);
                      _apply();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: on ? LColors.ink : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: on ? LColors.ink : const Color(0xFFECECF0)),
                      ),
                      child: Text(name,
                          style: TextStyle(
                              fontSize: 13,
                              color: on ? Colors.white : LColors.gray2)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            if (_list.isEmpty)
              Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Text('没有匹配的模板',
                            style: TextStyle(fontSize: 15, color: LColors.gray2)),
                        SizedBox(height: 6),
                        Text('换个词试试，比如「接机」「加油」「谢谢」',
                            style: TextStyle(fontSize: 12, color: LColors.gray2)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _search.clear();
                      setState(() => _active = '全部');
                      _apply();
                    },
                    child: const Text('看全部模板'),
                  ),
                ],
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 14,
                  childAspectRatio: 328 / 236,
                ),
                itemCount: _list.length,
                itemBuilder: (context, i) {
                  final t = _list[i];
                  final th = thumbOf(t.toPreset());
                  return _TemplateCard(
                    template: t,
                    thumb: th,
                    fav: _favs.contains(t.id),
                    onTap: () => _openEditor(t.id),
                    onFav: () => _toggleFav(t),
                  );
                },
              ),
            const SizedBox(height: 12),
            const Text('套用后文字可以改，样式已经调好',
                style: TextStyle(fontSize: 11, color: LColors.gray3)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final Template template;
  final ThumbStyle thumb;
  final bool fav;
  final VoidCallback onTap;
  final VoidCallback onFav;

  const _TemplateCard({
    required this.template,
    required this.thumb,
    required this.fav,
    required this.onTap,
    required this.onFav,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: hexColor(thumb.bg),
              borderRadius: BorderRadius.circular(10),
              border: thumb.light
                  ? Border.all(color: Colors.black.withValues(alpha: 0.08))
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 文字块用 Center + ClipRect，超长文本两侧一起裁 —— 跑马灯的关键表达
                Center(
                  child: Text(
                    thumb.text,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      color: hexColor(thumb.color),
                      fontSize: thumb.size,
                      fontWeight: FontWeight.w700,
                      shadows: thumb.shadows,
                    ),
                  ),
                ),
                if (thumb.badge.isNotEmpty)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      height: 16,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: thumb.light
                            ? Colors.black.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(thumb.badge,
                          style: TextStyle(
                              fontSize: 9,
                              color: thumb.light
                                  ? Colors.black.withValues(alpha: 0.55)
                                  : Colors.white.withValues(alpha: 0.9))),
                    ),
                  ),
                Positioned(
                  right: 4,
                  top: 3,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onFav,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(fav ? '♥' : '♡',
                          style: TextStyle(
                              fontSize: 16,
                              color: fav
                                  ? LColors.red
                                  : (thumb.light
                                      ? Colors.black.withValues(alpha: 0.25)
                                      : Colors.white.withValues(alpha: 0.42)))),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(template.name,
              style: const TextStyle(fontSize: 12, color: LColors.gray2)),
        ],
      ),
    );
  }
}
