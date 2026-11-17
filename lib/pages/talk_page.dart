import 'package:flutter/material.dart';

import '../core/storage.dart';
import '../core/texture.dart';
import '../models.dart';
import '../widgets/led_painter.dart';

/// 对话牌：输入即上屏，没有「发送」动作。
/// 文字正向显示，页面不存在镜像开关（PRD §1.6.1：屏幕不透光，
/// 面对面看的就是同一份像素，翻一次反而让对方读反字）。
class TalkPage extends StatefulWidget {
  const TalkPage({super.key});

  @override
  State<TalkPage> createState() => _TalkPageState();
}

class _TalkPageState extends State<TalkPage> {
  final TextEditingController _ctrl = TextEditingController();
  final List<String> _phrases = Storage.instance.getPhrases();
  LedStage? _stage;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_rebuild);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_rebuild);
    _ctrl.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final usableH = size.height * 0.6;
    final text = _ctrl.text.isEmpty ? '说吧，打字给对方看' : _ctrl.text;

    final preset = Preset(
      text: text,
      mode: 'static',
      style: const LedStyle(color: '#FFFFFF', glow: 8, lineHeight: 1.2),
      bg: const LedBg(color: '#000000'),
    );
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final prev = _stage?.texture;
    _stage = prepareStage(preset, w, usableH, dpr);
    prev?.dispose();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: usableH,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: LedPainter(
                    stage: _stage, offsetX: null, alpha: 1, mirror: false),
                size: Size.infinite,
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: Material(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text('‹ 返回',
                      style: TextStyle(
                          fontSize: 12, color: Colors.white.withValues(alpha: 0.86))),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(context).padding.bottom + 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xDB000000)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _phrases.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final phrase = _phrases[i];
                        return GestureDetector(
                          onTap: () => _ctrl.text = phrase,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 13),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(phrase,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.9))),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _ctrl,
                    style: const TextStyle(fontSize: 15, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '打字给对方看',
                      hintStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
