import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/exporter.dart';
import '../core/platform.dart';
import '../core/renderer.dart';
import '../core/share.dart';
import '../core/storage.dart';
import '../core/templates.dart';
import '../core/texture.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/led_painter.dart';

const double kMinBrightness = 0.3;
const int kStripLimit = 20;
const int kWarmShareDelay = 1200;

const Map<String, double> _blinkNormal = {
  'period': 900,
  'lit': 560,
  'dim': 0.06,
};
const Map<String, double> _blinkLowPower = {
  'period': 1200,
  'lit': 700,
  'dim': 0,
};
const int kLowPowerFps = 30;

class PlayPage extends StatefulWidget {
  final Map<String, dynamic> args;
  const PlayPage({super.key, required this.args});

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> with TickerProviderStateMixin {
  late Preset _preset;
  late bool _fromShare;
  bool _lowPower = false;

  LedStage? _stage;
  AnimState? _anim;
  FramePose _pose = const FramePose(null, 1);
  Ticker? _ticker;
  double? _stageW;
  double? _stageH;

  bool _controlsVisible = true;
  bool _locked = false;
  bool _mirror = false;
  bool _saving = false;
  Timer? _controlsTimer;
  Timer? _orientTimer;
  Timer? _shareTimer;
  Uint8List? _shareCardBytes;

  List<Preset> _strip = [];
  String? _currentId;

  double? _originBrightness;
  double? _brightness;
  int? _lastAppliedPct;
  int _brightnessPct = 100;
  double _sliderValue = 100;

  @override
  void initState() {
    super.initState();
    _fromShare = widget.args['src'] == 'share';
    final shared = _fromShare
        ? presetFromQuery(Map<String, String>.from(widget.args))
        : null;
    final direct = widget.args['preset'];
    if (shared != null) {
      _preset = shared;
    } else if (direct is Preset) {
      // 编辑页亮牌直接带对象过来：不等落盘、不受存储读写快慢影响。
      _preset = direct.copy();
    } else {
      final id = widget.args['id'] as String?;
      final found = id == null ? null : Storage.instance.getPreset(id);
      _preset = (found ?? fallbackPreset).copy();
    }
    _mirror = _preset.style.mirror;
    _currentId = _preset.id.isEmpty ? null : _preset.id;
    _lowPower = Storage.instance.getSettings().lowPowerMode;

    _strip = Storage.instance.getRecentPresets(kStripLimit);
    if (_preset.id.isNotEmpty && _preset.id != 'fallback') {
      Storage.instance.touchPreset(_preset.id);
      _strip = Storage.instance.getRecentPresets(kStripLimit);
    }

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _applyScreenSettings();
    _autoHideControls();
    _scheduleShareCard();

    // 横屏旋转在部分机型上有延迟，300ms 后按真实尺寸校验一次
    _orientTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _stopLoop();
    _stage?.texture?.dispose();
    _controlsTimer?.cancel();
    _orientTimer?.cancel();
    _shareTimer?.cancel();
    _restoreScreenSettings();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Preset _effectivePreset() {
    if (!_lowPower) return _preset;
    return _preset.copy()
      ..style = _preset.style.copyWith(glow: 0);
  }

  void _layout(double w, double h) {
    final prev = _stage?.texture;
    _stage = prepareStage(_effectivePreset(), w, h, MediaQuery.of(context).devicePixelRatio);
    prev?.dispose();
    _stageW = w;
    _stageH = h;

    final blink = _lowPower ? _blinkLowPower : _blinkNormal;
    _anim = AnimState(
      mode: _preset.mode,
      speed: _preset.speed,
      offset: _stage!.scrollEnter,
      scrollEnter: _stage!.scrollEnter,
      scrollExit: _stage!.scrollExit,
      fpsCap: _lowPower ? kLowPowerFps : null,
      blinkPeriod: blink['period']!,
      blinkLit: blink['lit']!,
      dimAlpha: blink['dim']!,
    );
    _pose = const FramePose(null, 1);

    // 舞台（含 AnimState）每次重建后都要按当前模式重新挂 Ticker。
    // 首次进页面、横竖屏切换、换牌、切省电都会走这里 —— 这是循环的唯一入口。
    // 原实现只在换牌/切省电处手动 _restartLoop()，首次亮牌进来 ticker 从未启动，
    // 于是滚动/闪烁牌在播放页完全静止。
    // 注意 _layout() 由 build() 调用：静态分支只能停循环，不能走 _startLoop()
    // 里的 setState，否则会抛「build 期间 setState」。
    if (_isAnimated()) {
      _startLoop();
    } else {
      _stopLoop();
    }
  }

  bool _isAnimated() =>
      _preset.mode == 'scroll-h' || _preset.mode == 'blink';

  void _startLoop() {
    if (_anim == null) return;
    if (!_isAnimated()) {
      _stopLoop();
      if (mounted) setState(() => _pose = const FramePose(null, 1));
      return; // 静态牌画一帧就停，GPU 占用 0
    }
    _stopLoop();
    _anim!.resetTiming();
    _ticker = createTicker((elapsed) {
      if (_anim == null) return;
      final ts = elapsed.inMicroseconds / 1000;
      if (!dueFrame(_anim!, ts)) return;
      final pose = advance(_anim!, ts);
      if (mounted) setState(() => _pose = pose);
    });
    _ticker!.start();
  }

  void _stopLoop() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
  }

  /* --------------------------- 屏幕 --------------------------- */

  Future<void> _applyScreenSettings() async {
    final bridge = PlatformBridge.instance;
    await bridge.setKeepScreenOn(true);
    final system = await bridge.getBrightness();
    _originBrightness ??= system;
    if (_brightness == null) {
      final autoMax = !_fromShare &&
          Storage.instance.getSettings().autoMaxBrightness;
      _brightness = autoMax
          ? 1
          : (system == null ? 1 : system.clamp(kMinBrightness, 1.0));
      _syncBrightUI((_brightness! * 100).round(), true);
      if (autoMax) {
        await bridge.setBrightness(_brightness!);
      }
    }
  }

  Future<void> _restoreScreenSettings() async {
    final bridge = PlatformBridge.instance;
    await bridge.setKeepScreenOn(false);
    if (_originBrightness != null) {
      await bridge.setBrightness(_originBrightness!);
      _originBrightness = null;
    }
  }

  void _syncBrightUI(int pct, bool syncSlider) {
    if (!mounted) return;
    setState(() {
      _brightnessPct = pct;
      if (syncSlider) _sliderValue = pct.toDouble();
    });
  }

  Future<void> _applyBrightness(double v, [bool syncSlider = true]) async {
    final value = v.clamp(kMinBrightness, 1.0);
    _brightness = value;
    final pct = (value * 100).round();
    _syncBrightUI(pct, syncSlider);
    _lastAppliedPct = pct;
    await PlatformBridge.instance.setBrightness(value);
  }

  /* --------------------------- 交互 --------------------------- */

  void _autoHideControls() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_locked) setState(() => _controlsVisible = false);
    });
  }

  void _holdControls() => _controlsTimer?.cancel();

  void _onTapStage() {
    if (_locked) return;
    final next = !_controlsVisible;
    setState(() => _controlsVisible = next);
    if (next) _autoHideControls();
  }

  void _onLongPress() {
    final locked = !_locked;
    setState(() {
      _locked = locked;
      _controlsVisible = !locked;
    });
    PlatformBridge.instance.vibrate(type: 'medium');
    if (!locked) _autoHideControls();
  }

  void _toggleMirror() {
    final mirror = !_mirror;
    setState(() => _mirror = mirror);
    // 镜像只是绘制变换，纹理不重建；静态牌没有循环， setState 已触发重画
    _autoHideControls();
  }

  Future<void> _toggleLowPower() async {
    final low = !_lowPower;
    _lowPower = low;
    await Storage.instance.patchSettings(lowPowerMode: low);
    if (!mounted) return;
    setState(() {});
    if (_stageW != null && _stageH != null) {
      _layout(_stageW!, _stageH!);
    }
    PlatformBridge.instance.vibrate();
    _autoHideControls();
  }

  Future<void> _switchPreset(String id) async {
    if (id.isEmpty || id == _currentId) return;
    final next = Storage.instance.getPreset(id);
    if (next == null) return;
    setState(() {
      _preset = next.copy();
      _currentId = id;
    });
    if (_stageW != null && _stageH != null) {
      _layout(_stageW!, _stageH!);
    }
    // 换牌不动亮度 / 镜像 / 锁定 / 常亮
    await Storage.instance.touchPreset(id);
    _strip = Storage.instance.getRecentPresets(kStripLimit);
    _scheduleShareCard();
    PlatformBridge.instance.vibrate();
    _autoHideControls();
  }

  /* --------------------------- 存图 / 分享 --------------------------- */

  /// 进页面 1.2s 后预热 5:4 卡片图：用户点「分享」时系统分享要立刻拿到图，
  /// 不能等一次 1000×800 的离屏绘制。换牌后必须重排，否则分享出去还是上一块牌。
  void _scheduleShareCard() {
    _shareTimer?.cancel();
    _shareCardBytes = null;
    _shareTimer = Timer(const Duration(milliseconds: kWarmShareDelay), () async {
      try {
        _shareCardBytes = await exportImage(_preset, 'card');
      } catch (_) {
        _shareCardBytes = null; // 真到分享时再实时生成，功能不中断
      }
    });
  }

  Future<void> _saveImage() async {
    if (_saving) return;
    setState(() => _saving = true);
    _holdControls();
    try {
      final bytes = await exportImage(_preset, 'poster');
      final ok = await PlatformBridge.instance.saveImage(bytes, name: '电子灯牌');
      if (!mounted) return;
      toast(context, ok ? '已存到相册' : '保存失败，请检查相册权限');
    } catch (_) {
      if (mounted) toast(context, '生成图片失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
      _autoHideControls();
    }
  }

  Future<void> _share() async {
    _holdControls();
    try {
      final bytes = _shareCardBytes ?? await exportImage(_preset, 'card');
      await PlatformBridge.instance.shareImage(bytes, titleOf(_preset));
    } catch (_) {
      if (mounted) toast(context, '分享图生成失败');
    }
    _autoHideControls();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;
    if (_stage == null || _stageW != w || _stageH != h) {
      _layout(w, h);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 全屏舞台：画布不占位，控件浮在上面
          Positioned.fill(
            child: GestureDetector(
              onTap: _onTapStage,
              onLongPress: _onLongPress,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: LedPainter(
                    stage: _stage,
                    offsetX: _pose.offsetX,
                    alpha: _pose.alpha,
                    mirror: _mirror,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          if (_controlsVisible && !_locked)
            Positioned.fill(
              child: IgnorePointer(
                child: const SizedBox.shrink(),
              ),
            ),
          if (_controlsVisible && !_locked) _topBar(),
          if (_controlsVisible && !_locked) _bottomBar(),
          if (_locked)
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: Text('已锁定 · 长按屏幕解锁',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12, color: Colors.white.withValues(alpha: 0.55))),
            ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 12,
      right: 12,
      child: Row(
        children: [
          _hudButton(Icons.arrow_back_ios_new, '返回', () => Navigator.of(context).pop()),
          const SizedBox(width: 6),
          _hudButton(Icons.download_outlined, _saving ? '生成中' : '存图', _saveImage),
          const SizedBox(width: 6),
          _hudButton(Icons.share_outlined, '分享', _share),
        ],
      ),
    );
  }

  Widget _hudButton(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.92)),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 13, color: Colors.white.withValues(alpha: 0.92))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 6,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Color(0xE6000000),
              Color(0xA8000000),
              Color(0x00000000),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_strip.isNotEmpty)
              SizedBox(
                height: 30,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _strip.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final p = _strip[i];
                    final on = p.id == _currentId;
                    return GestureDetector(
                      onTap: () => _switchPreset(p.id),
                      child: Container(
                        width: 70,
                        height: 29,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: hexColor(p.bg.color),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: on
                                  ? Colors.white.withValues(alpha: 0.92)
                                  : Colors.transparent,
                              width: 1),
                        ),
                        child: Text(
                          p.text.replaceAll('\n', ' '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: hexColor(p.style.color)),
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              SizedBox(
                height: 30,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('还没有保存的灯牌，去「我的」新建一张',
                      style: TextStyle(
                          fontSize: 11, color: Colors.white.withValues(alpha: 0.45))),
                ),
              ),
            const SizedBox(height: 5),
            Row(
              children: [
                _barButton('镜像', _mirror, _toggleMirror),
                const SizedBox(width: 6),
                _barButton('省电', _lowPower, _toggleLowPower),
                const SizedBox(width: 8),
                Text('亮度',
                    style: TextStyle(
                        fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
                Expanded(
                  child: Slider(
                    value: _sliderValue.clamp(30, 100),
                    min: 30,
                    max: 100,
                    divisions: 70,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white.withValues(alpha: 0.24),
                    onChanged: (v) {
                      _holdControls();
                      final pct = v.round();
                      _syncBrightUI(pct, false);
                      final gap = _lastAppliedPct == null
                          ? 999
                          : (pct - _lastAppliedPct!).abs();
                      if (gap < 3) return;
                      _applyBrightness(pct / 100, false);
                    },
                    onChangeEnd: (v) {
                      _applyBrightness(v / 100, true);
                      _autoHideControls();
                    },
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text('$_brightnessPct%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
                ),
                const SizedBox(width: 6),
                _barButton('锁定', false, _onLongPress),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _barButton(String label, bool on, VoidCallback onTap) {
    return Material(
      color: on ? Colors.white.withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: 29,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: on ? FontWeight.w600 : FontWeight.normal,
                  color: on ? const Color(0xFF111111) : Colors.white.withValues(alpha: 0.9))),
        ),
      ),
    );
  }
}
