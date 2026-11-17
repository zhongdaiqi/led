import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/palette.dart';
import '../core/renderer.dart';
import '../core/storage.dart';
import '../core/templates.dart';
import '../core/texture.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/led_painter.dart';

class EditorPage extends StatefulWidget {
  final Map<String, dynamic> args;
  const EditorPage({super.key, required this.args});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> with TickerProviderStateMixin {
  final TextEditingController _textCtrl = TextEditingController();

  late LedStyle _baseStyle;
  String _color = '#FF2D2D';
  String _bgColor = '#000000';
  String _mode = 'static';
  double _glow = 16;
  double _speed = 90;
  String _editingId = '';

  LedStage? _stage;
  AnimState? _anim;
  FramePose _pose = const FramePose(null, 1);
  double? _stageW;
  Ticker? _ticker;

  @override
  void initState() {
    super.initState();
    _baseStyle = kDefaultStyle;
    final templateId = widget.args['template'] as String?;
    final id = widget.args['id'] as String?;
    if (templateId != null) {
      final t = getTemplate(templateId);
      if (t != null) {
        _baseStyle = t.style;
        _textCtrl.text = t.text;
        _color = t.style.color;
        _bgColor = t.bg.color;
        _mode = t.mode;
        _glow = t.style.glow;
        _speed = t.speed;
      }
    } else if (id != null) {
      final p = Storage.instance.getPreset(id);
      if (p != null) {
        _baseStyle = p.style;
        _textCtrl.text = p.text;
        _color = p.style.color;
        _bgColor = p.bg.color;
        _mode = p.mode;
        _glow = p.style.glow;
        _speed = p.speed;
        _editingId = p.id;
      }
    }
  }

  @override
  void dispose() {
    _stopLoop();
    _textCtrl.dispose();
    super.dispose();
  }

  Preset _toPreset() => Preset(
        text: _textCtrl.text.isEmpty ? '输入文字' : _textCtrl.text,
        mode: _mode,
        speed: _speed,
        style: _baseStyle.copyWith(color: _color, glow: _glow),
        bg: LedBg(color: _bgColor),
      );

  void _rebuildStage(double width) {
    final h = width * 9 / 16; // 预览严格 16:9，与横屏播放视口同比
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final preset = _toPreset();
    final prev = _stage?.texture;
    _stage = prepareStage(preset, width, h, dpr);
    prev?.dispose();
    _stageW = width;
    _anim = AnimState(
      mode: preset.mode,
      speed: preset.speed,
      offset: _stage!.scrollEnter,
      scrollEnter: _stage!.scrollEnter,
      scrollExit: _stage!.scrollExit,
    );
    if (preset.mode == 'static') {
      _pose = const FramePose(null, 1);
    } else {
      _startLoop();
    }
  }

  void _refresh({bool restartLoop = true}) {
    if (_stageW == null) return;
    if (restartLoop) _stopLoop();
    _rebuildStage(_stageW!);
    if (mounted) setState(() {});
  }

  void _startLoop() {
    _stopLoop();
    if (_mode == 'static' || _anim == null) return;
    _anim!.resetTiming();
    _ticker = createTicker((elapsed) {
      if (_anim == null) return;
      final pose = advance(_anim!, elapsed.inMicroseconds / 1000);
      if (mounted) setState(() => _pose = pose);
    });
    _ticker!.start();
  }

  void _stopLoop() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
  }

  void _setState(void Function() patch) {
    setState(patch);
    _refresh();
  }

  void _play() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      if (mounted) toast(context, '先输入文字');
      return;
    }

    // 亮牌是核心路径：先把牌渲染出来，持久化不参与前台等待。
    // 真机上 SharedPreferences 首次写入可能偶发挂起，await 它会让按钮「点了没反应」。
    final preset = Preset(
      id: _editingId,
      text: text,
      mode: _mode,
      style: _baseStyle.copyWith(color: _color, glow: _glow),
      bg: LedBg(color: _bgColor),
      speed: _speed,
    );
    if (preset.id.isEmpty) preset.id = Storage.genId();
    // 异步落盘，结果不影响跳转；播放页内存里已有这块牌，立即可用。
    Storage.instance.upsertPreset(preset).catchError((_) => null);

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/play', arguments: {'preset': preset});
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width - LSize.pagePad * 2;
    if (_stage == null || _stageW != width) {
      _rebuildStage(width);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑灯牌', style: TextStyle(fontSize: 17)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  LSize.pagePad, 12, LSize.pagePad, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 预览区：16:9，所见即所得
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: LedPainter(
                            stage: _stage,
                            offsetX: _pose.offsetX,
                            alpha: _pose.alpha,
                            mirror: false,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('这是横屏举起后的效果',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: LColors.gray)),
                  ),
                  const SizedBox(height: 14),
                  _Panel(
                    children: [
                      _Field(
                        label: '文字',
                        child: TextField(
                          controller: _textCtrl,
                          maxLength: 60,
                          maxLines: null,
                          onChanged: (_) => _refresh(),
                          decoration: const InputDecoration(
                            hintText: '输入要显示的内容，最多 60 字',
                            border: InputBorder.none,
                            isDense: true,
                            counterText: '',
                          ),
                          style: const TextStyle(fontSize: 16, color: LColors.ink),
                        ),
                      ),
                      _SwatchField(
                        label: '文字颜色',
                        colors: kTextColors,
                        selected: _color,
                        onPick: (hex) => _setState(() => _color = hex),
                      ),
                      _SwatchField(
                        label: '背景',
                        colors: kBgColors,
                        selected: _bgColor,
                        onPick: (hex) => _setState(() => _bgColor = hex),
                      ),
                      _SegmentField(
                        label: '显示方式',
                        modes: kModes,
                        selected: _mode,
                        onPick: (key) => _setState(() => _mode = key),
                      ),
                      if (_mode == 'scroll-h')
                        _SliderField(
                          label: '滚动速度 ${_speed.round()} · ${_speedText(_speed)}',
                          value: _speed,
                          min: 20,
                          max: 200,
                          step: 5,
                          onChanged: (v) {
                            setState(() {
                              _speed = v;
                              if (_anim != null) _anim!.speed = v;
                            });
                          },
                        ),
                      _SliderField(
                        label: '发光 ${_glow.round()}',
                        value: _glow,
                        min: 0,
                        max: 30,
                        step: 1,
                        onChanged: (v) => _setState(() => _glow = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(
                LSize.pagePad, 10, LSize.pagePad, 10),
            decoration: const BoxDecoration(
              color: Color(0xF5FFFFFF),
              border: Border(top: BorderSide(color: LColors.line)),
            ),
            child: SafeArea(
              top: false,
              child: PrimaryButton(label: '亮牌', onTap: _play),
            ),
          ),
        ],
      ),
    );
  }

  static String _speedText(double v) {
    if (v < 60) return '慢';
    if (v > 130) return '快';
    return '中';
  }
}

class _Panel extends StatelessWidget {
  final List<Widget> children;
  const _Panel({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: children),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: LColors.gray)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _SwatchField extends StatelessWidget {
  final String label;
  final List<Swatch> colors;
  final String selected;
  final ValueChanged<String> onPick;
  const _SwatchField({
    required this.label,
    required this.colors,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return _Field(
      label: label,
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        children: colors.map((s) {
          final on = selected.toUpperCase() == s.hex.toUpperCase();
          return GestureDetector(
            onTap: () => onPick(s.hex),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: hexColor(s.hex),
                shape: BoxShape.circle,
                border: Border.all(
                    color: on ? LColors.ink : Colors.transparent, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08), blurRadius: 1)
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SegmentField extends StatelessWidget {
  final String label;
  final List<Swatch> modes;
  final String selected;
  final ValueChanged<String> onPick;
  const _SegmentField({
    required this.label,
    required this.modes,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return _Field(
      label: label,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            color: const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: modes.map((m) {
            final on = selected == m.hex;
            return Expanded(
              child: GestureDetector(
                onTap: () => onPick(m.hex),
                child: Container(
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: on
                        ? [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1))]
                        : null,
                  ),
                  child: Text(m.name,
                      style: TextStyle(
                          fontSize: 14,
                          color: on ? LColors.ink : LColors.gray2,
                          fontWeight: on ? FontWeight.w600 : FontWeight.normal)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SliderField extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int step;
  final ValueChanged<double> onChanged;
  const _SliderField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Field(
      label: label,
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: ((max - min) / step).round(),
        activeColor: LColors.red,
        inactiveColor: LColors.gray3,
        onChanged: onChanged,
      ),
    );
  }
}
