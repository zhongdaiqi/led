import 'package:flutter/painting.dart';

import '../models.dart';

/// 模板缩略图样式推导 —— 不用 canvas 逐张渲染。
/// 理由：一屏十几张绘制目标与「静态牌停帧省电」冲突；静态帧表达不出滚动/闪烁；
/// 颜色发光从字段实时算，不会出现「图忘了一起改」。
///
/// 小程序的 rpx 在这里按 0.5 换成 dp：BOX_W 292rpx → 146dp。
class ThumbStyle {
  final String bg;
  final String color;
  final double size;
  final List<Shadow> shadows;
  final String text;
  final bool scroll;
  final String badge;
  final bool light;

  const ThumbStyle({
    required this.bg,
    required this.color,
    required this.size,
    required this.shadows,
    required this.text,
    required this.scroll,
    required this.badge,
    required this.light,
  });
}

const double kThumbBoxW = 146; // 292rpx
const double kThumbMaxSize = 36; // 72rpx
const double kThumbMinSize = 13; // 26rpx
const String kLoopGap = '　　';

bool isLightColor(String hex) {
  final s = hex.replaceFirst('#', '');
  if (s.length != 6) return false;
  final n = int.tryParse(s, radix: 16);
  if (n == null) return false;
  final r = (n >> 16) & 255;
  final g = (n >> 8) & 255;
  final b = n & 255;
  return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.75;
}

/// 两层发光：近处紧、远处散，比单层更接近灯珠光晕。
List<Shadow> glowShadows(double glow, Color color) {
  if (glow <= 0) return const [];
  final near = (glow * 0.3).round().clamp(1, 999).toDouble();
  final far = (glow * 0.7).round().clamp(2, 999).toDouble();
  return [
    Shadow(color: color, blurRadius: near * 0.5),
    Shadow(color: color, blurRadius: far * 0.5),
  ];
}

int _longestLine(String text) {
  var max = 0;
  for (final line in text.split('\n')) {
    if (line.length > max) max = line.length;
  }
  return max;
}

String loopText(String text) {
  if (text.isEmpty) return text;
  return text + kLoopGap + text;
}

ThumbStyle thumbOf(Preset tpl, {double? boxW, double? maxSize}) {
  final w = boxW ?? kThumbBoxW;
  final max = maxSize ?? kThumbMaxSize;
  final min = kThumbMinSize < max * 0.36 ? kThumbMinSize : (max * 0.36).round().toDouble();

  final colorHex = tpl.style.color.isEmpty ? '#FF2D2D' : tpl.style.color;
  final bgHex = tpl.bg.color.isEmpty ? '#000000' : tpl.bg.color;
  final isScroll = tpl.mode == 'scroll-h';
  final chars = _longestLine(tpl.text).clamp(1, 9999);

  final size = isScroll
      ? max
      : (w / chars).floor().toDouble().clamp(min, max);

  return ThumbStyle(
    bg: bgHex,
    color: colorHex,
    size: size,
    shadows: glowShadows(tpl.style.glow, _hex(colorHex)),
    text: isScroll ? loopText(tpl.text) : tpl.text,
    scroll: isScroll,
    badge: isScroll ? '滚动' : (tpl.mode == 'blink' ? '闪烁' : ''),
    light: isLightColor(bgHex),
  );
}

Color _hex(String hex) {
  final s = hex.replaceFirst('#', '');
  final v = int.tryParse(s, radix: 16);
  return v == null ? const Color(0xFFFF2D2D) : Color(0xFF000000 | v);
}
