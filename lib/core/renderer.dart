import 'package:flutter/painting.dart';

import '../models.dart';

/// LED 渲染引擎（对应小程序 utils/renderer.js）
///
/// 1. 字号自适应是核心：文字必须撑满屏幕
/// 2. 发光不逐帧算：走 texture.dart 的预烘焙纹理
/// 3. 动画状态独立成 AnimState，编辑页与播放页共用，节奏不会两处各写一套

/// 构造字体串。'sans-serif' 在 Flutter 里直接用系统默认字体。
TextStyle textStyleOf(double size, LedStyle style) {
  final family = (style.fontFamily.isEmpty || style.fontFamily == 'sans-serif')
      ? null
      : style.fontFamily;
  return TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: FontWeight.w900,
    height: style.lineHeight,
    letterSpacing: style.letterSpacing,
  );
}

TextPainter _painter(String text, TextStyle style) {
  return TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: null,
  )..layout();
}

double measureLine(String line, double size, [LedStyle? style]) {
  if (line.isEmpty) return 0;
  final p = _painter(line, textStyleOf(size, style ?? const LedStyle()));
  final w = p.width;
  p.dispose();
  return w;
}

double maxLineWidth(List<String> lines, double size, [LedStyle? style]) {
  var maxW = 0.0;
  for (final l in lines) {
    final w = measureLine(l, size, style);
    if (w > maxW) maxW = w;
  }
  return maxW;
}

/// 二分搜索最大可用字号。
/// maxW 传 double.infinity 表示不限宽（跑马灯）；
/// sizeCap 是字号硬上限（"一屏至少 2.5 个字"），不能塞进 maxW。
double fitFontSize(
  List<String> lines,
  double maxW,
  double maxH,
  double lineHeight, {
  double? sizeCap,
  LedStyle? style,
}) {
  var lo = 8.0;
  var hi = 1600.0;
  if (sizeCap != null && sizeCap > 0) {
    hi = hi < sizeCap ? hi : sizeCap;
  }
  if (hi < lo) return lo;
  var best = lo;
  final st = (style ?? const LedStyle()).copyWith(lineHeight: lineHeight);

  for (var i = 0; i < 18; i++) {
    final mid = (lo + hi) / 2;
    var fits = true;
    for (final line in lines) {
      if (measureLine(line, mid, st) > maxW) {
        fits = false;
        break;
      }
    }
    if (fits && lines.length * mid * lineHeight > maxH) fits = false;

    if (fits) {
      best = mid;
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return best < lo ? lo : best.floor().toDouble();
}

/// 按最大宽度自动折行。中文逐字测量，英文单词也可能被拆断 —— 灯牌场景可接受。
List<String> wrapLines(String text, double maxW, double size, [LedStyle? style]) {
  final styleWithLh = (style ?? const LedStyle()).copyWith(lineHeight: 1.15);
  final out = <String>[];
  for (final paragraph in text.split('\n')) {
    if (paragraph.isEmpty) {
      out.add('');
      continue;
    }
    var line = '';
    for (var i = 0; i < paragraph.length; i++) {
      final test = line + paragraph[i];
      if (line.isNotEmpty && measureLine(test, size, styleWithLh) > maxW) {
        out.add(line);
        line = paragraph[i];
      } else {
        line = test;
      }
    }
    if (line.isNotEmpty) out.add(line);
  }
  return out.isEmpty ? [''] : out;
}

/// 动画状态。时间戳用 double 毫秒；null 表示"还没开始"，
/// 与小程序一致：首帧 ts 真有可能是 0，不能用假值判断。
class AnimState {
  String mode;
  double speed;
  double offset;
  double scrollEnter;
  double scrollExit;
  double? startTs;
  double? lastTs;
  double? lastPaintTs;
  int? fpsCap;
  double blinkPeriod;
  double blinkLit;
  double dimAlpha;

  AnimState({
    required this.mode,
    required this.speed,
    required this.offset,
    required this.scrollEnter,
    required this.scrollExit,
    this.startTs,
    this.lastTs,
    this.lastPaintTs,
    this.fpsCap,
    this.blinkPeriod = 900,
    this.blinkLit = 560,
    this.dimAlpha = 0.06,
  });

  void resetTiming() {
    startTs = null;
    lastTs = null;
    lastPaintTs = null;
  }
}

class FramePose {
  final double? offsetX;
  final double alpha;
  const FramePose(this.offsetX, this.alpha);
}

/// 省电模式限帧。被跳过的帧完全不推进动画 —— 位移留到下次按真实时间补，
/// 所以 30fps 和 60fps 下跑马灯速度一致。
bool dueFrame(AnimState state, double ts) {
  final cap = state.fpsCap;
  if (cap == null || cap <= 0) return true;
  if (state.lastPaintTs == null) {
    state.lastPaintTs = ts;
    return true;
  }
  if (ts - state.lastPaintTs! < 1000 / cap - 1) return false;
  state.lastPaintTs = ts;
  return true;
}

/// 推进一帧动画，返回本帧的 offsetX / alpha。
FramePose advance(AnimState state, double ts) {
  state.startTs ??= ts;
  final elapsed = ts - state.startTs!;

  final hasPrev = state.lastTs != null;
  final dt = hasPrev ? (ts - state.lastTs!).clamp(0.0, 64.0) : 16.0;
  state.lastTs = ts;

  if (state.mode == 'scroll-h') {
    state.offset -= (state.speed * dt) / 1000;
    // 赋新值而不是 += 周期：浮点误差累积会让起点漂到屏幕左侧
    if (state.offset <= state.scrollExit) state.offset = state.scrollEnter;
    return FramePose(state.offset, 1);
  }

  if (state.mode == 'blink') {
    final period = state.blinkPeriod > 0 ? state.blinkPeriod : 900;
    final lit = state.blinkLit;
    return FramePose(null, elapsed % period < lit ? 1 : state.dimAlpha);
  }

  return FramePose(null, 1);
}

/// 滚动一圈所需位移：文字宽度 + 0.6 屏宽间隔。
double scrollCycleWidth(List<String> lines, double size, double screenWidth,
    [LedStyle? style]) {
  return maxLineWidth(lines, size, style) + screenWidth * 0.6;
}
