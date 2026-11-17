import 'package:flutter/material.dart';

/// 全局配色与尺寸约定
///
/// 小程序用 750rpx 设计稿，Flutter 用 dp。换机基准：
/// 1rpx ≈ 0.5dp（375dp 设计宽），所以 32rpx → 16dp。
/// 代码中统一写 dp 数值，注释里保留原始 rpx 便于对照小程序源码。
class LColors {
  static const red = Color(0xFFFF2D2D);
  static const gold = Color(0xFFFFD700);
  static const bg = Color(0xFFF5F5F7);
  static const ink = Color(0xFF1C1C1E);
  static const gray = Color(0xFF8A8A8E);
  static const gray2 = Color(0xFFA1A1A6);
  static const gray3 = Color(0xFFC7C7CC);
  static const line = Color(0xFFF0F0F2);
  static const blue = Color(0xFF0A84FF);
  static const card = Colors.white;
  static const black = Color(0xFF000000);
}

/// 把 #RRGGBB 字符串转成 0xAARRGGBB 整数；非法值回退默认色。
int colorValueOf(String? hex, {int fallback = 0xFF000000}) {
  if (hex == null) return fallback;
  final s = hex.replaceFirst('#', '');
  if (s.length != 6) return fallback;
  final v = int.tryParse(s, radix: 16);
  if (v == null) return fallback;
  return 0xFF000000 | v;
}

/// 把 #RRGGBB 字符串转成 Flutter Color；非法值回退默认色。
Color hexColor(String? hex, {Color fallback = Colors.black}) {
  if (hex == null) return fallback;
  return Color(colorValueOf(hex, fallback: fallback.toARGB32()));
}

/// 与小程序一致的圆角/间距（已按 0.5 换算为 dp）
class LSize {
  static const double pagePad = 16; // 32rpx
  static const double radiusCard = 12; // 24rpx
  static const double radiusSmall = 8; // 16rpx
  static const double gap = 8; // 16rpx
}

/// 分类与模式共用的常量字符串
class LMode {
  static const String staticMode = 'static';
  static const String scrollH = 'scroll-h';
  static const String blink = 'blink';
}
